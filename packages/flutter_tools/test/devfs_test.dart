// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/devfs.dart';
import 'package:flutter_tools/src/vmservice.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as rpc;
import 'package:mockito/mockito.dart';

import 'src/common.dart';
import 'src/context.dart';
import 'src/mocks.dart';

void main() {
  FileSystem fs;
  String filePath;

  setUp(() {
    fs = MemoryFileSystem();
    filePath = fs.path.join('lib', 'foo.txt');
  });

  group('DevFSContent', () {
    test('bytes', () {
      final DevFSByteContent content = DevFSByteContent(<int>[4, 5, 6]);
      expect(content.bytes, orderedEquals(<int>[4, 5, 6]));
      expect(content.isModified, isTrue);
      expect(content.isModified, isFalse);
      content.bytes = <int>[7, 8, 9, 2];
      expect(content.bytes, orderedEquals(<int>[7, 8, 9, 2]));
      expect(content.isModified, isTrue);
      expect(content.isModified, isFalse);
    });

    test('string', () {
      final DevFSStringContent content = DevFSStringContent('some string');
      expect(content.string, 'some string');
      expect(content.bytes, orderedEquals(utf8.encode('some string')));
      expect(content.isModified, isTrue);
      expect(content.isModified, isFalse);
      content.string = 'another string';
      expect(content.string, 'another string');
      expect(content.bytes, orderedEquals(utf8.encode('another string')));
      expect(content.isModified, isTrue);
      expect(content.isModified, isFalse);
      content.bytes = utf8.encode('foo bar');
      expect(content.string, 'foo bar');
      expect(content.bytes, orderedEquals(utf8.encode('foo bar')));
      expect(content.isModified, isTrue);
      expect(content.isModified, isFalse);
    });

    testUsingContext('file', () async {
      final File file = fs.file(filePath);
      final DevFSFileContent content = DevFSFileContent(file);
      expect(content.isModified, isFalse);
      expect(content.isModified, isFalse);

      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(<int>[1, 2, 3], flush: true);

      final DateTime fiveSecondsAgo = DateTime.now().subtract(const Duration(seconds:5));
      expect(content.isModifiedAfter(fiveSecondsAgo), isTrue);
      expect(content.isModifiedAfter(fiveSecondsAgo), isTrue);
      expect(content.isModifiedAfter(null), isTrue);

      file.writeAsBytesSync(<int>[2, 3, 4], flush: true);
      expect(content.isModified, isTrue);
      expect(content.isModified, isFalse);
      expect(content.contentsAsBytes(), <int>[2, 3, 4]);
      updateFileModificationTime(file.path, fiveSecondsAgo, 0);
      expect(content.isModified, isFalse);
      expect(content.isModified, isFalse);

      file.deleteSync();
      expect(content.isModified, isTrue);
      expect(content.isModified, isFalse);
      expect(content.isModified, isFalse);
    }, overrides: <Type, Generator>{
      FileSystem: () => fs,
    });
  });

  group('devfs remote', () {
    DevFS devFS;
    MockResidentCompiler residentCompiler;
    MockDevFSOperations mockDevFSOperations;
    int created;
    int destroyed;
    List<String> writtenFiles;
    bool exists;

    setUp(() async {
      mockDevFSOperations = MockDevFSOperations();
      devFS = DevFS.operations(mockDevFSOperations, 'test', fs.currentDirectory);
      residentCompiler = MockResidentCompiler();
      created = 0;
      destroyed = 0;
      exists = false;
      writtenFiles = <String>[];
      when(mockDevFSOperations.create('test')).thenAnswer((Invocation invocation) async {
        if (exists) {
          throw rpc.RpcException(1001, 'already exists');
        }
        exists = true;
        created += 1;
        return Uri.parse(InternetAddress.loopbackIPv4.toString());
      });
      when(mockDevFSOperations.destroy('test')).thenAnswer((Invocation invocation) async {
        exists = false;
        destroyed += 1;
      });
      when(mockDevFSOperations.write(any)).thenAnswer((Invocation invocation) async {
        final Map<Uri, DevFSContent> entries = invocation.positionalArguments.first;
        writtenFiles.addAll(entries.keys.map((Uri uri) => uri.toFilePath()));
      });
    });

    testUsingContext('create dev file system', () async {
      // simulate workspace
      final File file = fs.file(filePath);
      await file.parent.create(recursive: true);
      file.writeAsBytesSync(<int>[1, 2, 3]);

      // simulate package
      await _createPackage(fs, 'somepkg', 'somefile.txt');
      await devFS.create();

      expect(created, 1);
      expect(devFS.assetPathsToEvict, isEmpty);

      final UpdateFSReport report = await devFS.update(
        mainPath: 'lib/foo.txt',
        generator: residentCompiler,
        pathToReload: 'lib/foo.txt.dill',
        trackWidgetCreation: false,
        invalidatedFiles: <Uri>[],
      );

      expect(writtenFiles, <String>['lib/foo.txt.dill']);
      expect(devFS.assetPathsToEvict, isEmpty);
      expect(report.syncedBytes, 22);
      expect(report.success, true);
    }, overrides: <Type, Generator>{
      FileSystem: () => fs,
    });

    testUsingContext('delete dev file system', () async {
      await devFS.destroy();
      expect(destroyed, 1);
      expect(devFS.assetPathsToEvict, isEmpty);
    }, overrides: <Type, Generator>{
      FileSystem: () => fs,
    });

    testUsingContext('cleanup preexisting file system', () async {
      // simulate workspace
      final File file = fs.file(filePath);
      await file.parent.create(recursive: true);
      file.writeAsBytesSync(<int>[1, 2, 3]);

      // simulate package
      await _createPackage(fs, 'somepkg', 'somefile.txt');

      await devFS.create();
      expect(created, 1);
      expect(devFS.assetPathsToEvict, isEmpty);

      // Try to create again.
      await devFS.create();
      expect(created, 2);
      expect(destroyed, 1);
      expect(devFS.assetPathsToEvict, isEmpty);

      // Really destroy.
      await devFS.destroy();
      expect(destroyed, 2);
      expect(devFS.assetPathsToEvict, isEmpty);
    }, overrides: <Type, Generator>{
      FileSystem: () => fs,
    });
  });
}

class MockVMService extends Mock implements VMService {}

class MockDevFSOperations extends Mock implements DevFSOperations {}

final Map <String, Uri> _packages = <String, Uri>{};


Future<void> _createPackage(FileSystem fs, String pkgName, String pkgFileName, { bool doubleSlash = false }) async {
  String pkgFilePath = fs.path.join(pkgName, 'lib', pkgFileName);
  if (doubleSlash) {
    // Force two separators into the path.
    pkgFilePath = fs.path.join(pkgName, 'lib', pkgFileName);
  }
  final File pkgFile = fs.file(pkgFilePath);
  await pkgFile.parent.create(recursive: true);
  pkgFile.writeAsBytesSync(<int>[11, 12, 13]);
  _packages[pkgName] = fs.path.toUri(pkgFile.parent.path);
  final StringBuffer sb = StringBuffer();
  _packages.forEach((String pkgName, Uri pkgUri) {
    sb.writeln('$pkgName:$pkgUri');
  });
  fs.file('.packages').writeAsStringSync(sb.toString());
}
