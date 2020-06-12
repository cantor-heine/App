

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/dart/language_version.dart';
import 'package:package_config/package_config.dart';

import '../../src/common.dart';

void main() {
  testWithoutContext('detects language version in comment', () {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final File file = fileSystem.file('example.dart')
      ..writeAsStringSync('''
// Some license

// @dart = 2.9
''');

    expect(determineLanguageVersion(file, null), '// @dart = 2.9');
  });

  testWithoutContext('detects technically invalid language version', () {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final File file = fileSystem.file('example.dart')
      ..writeAsStringSync('''
// Some license

// @dart
''');

    expect(determineLanguageVersion(file, null), '// @dart');
  });

  testWithoutContext('detects language version with tons of whitespace', () {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final File file = fileSystem.file('example.dart')
      ..writeAsStringSync('''
// Some license

//        @dart       = 23
''');

    expect(determineLanguageVersion(file, null), '//        @dart       = 23');
  });

  testWithoutContext('does not detect language version in dartdoc', () {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final File file = fileSystem.file('example.dart')
      ..writeAsStringSync('''
// Some license

/// @dart = 2.9
''');

    expect(determineLanguageVersion(file, null), null);
  });


  testWithoutContext('does not detect language version after import', () {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final File file = fileSystem.file('example.dart')
      ..writeAsStringSync('''
// Some license

import 'dart:ui' as ui;

// @dart = 2.9
''');

    expect(determineLanguageVersion(file, null), null);
  });

  testWithoutContext('looks up language version from package if not found in file', () {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final File file = fileSystem.file('example.dart')
      ..writeAsStringSync('''
// Some license
''');
    final Package package = Package(
      'foo',
      Uri.parse('file://foo/'),
      languageVersion: LanguageVersion(2, 7),
    );

    expect(determineLanguageVersion(file, package), '// @dart = 2.7');
  });
}
