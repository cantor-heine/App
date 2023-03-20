// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/android/migrations/top_level_gradle_build_file_migration.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/project_migrator.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:test/fake.dart';

import '../../src/common.dart';
import '../../src/context.dart';

void main() {
  group('Android migration', () {
    group('migrate the Gradle "clean" task to lazy declaration', () {
      late MemoryFileSystem memoryFileSystem;
      late BufferLogger bufferLogger;
      late FakeAndroidProject project;
      late File topLevelGradleBuildFile;

      setUp(() {
        memoryFileSystem = MemoryFileSystem.test();
        bufferLogger = BufferLogger.test();
        project = FakeAndroidProject(memoryFileSystem.currentDirectory.childDirectory('android')..createSync());
        topLevelGradleBuildFile = project.hostAppGradleRoot.childFile('build.gradle');
      });

      testUsingContext('skipped if files are missing', () {
        final TopLevelGradleBuildFileMigration androidProjectMigration = TopLevelGradleBuildFileMigration(
          project,
          bufferLogger,
        );
        androidProjectMigration.migrate();
        expect(topLevelGradleBuildFile.existsSync(), isFalse);

        expect(bufferLogger.traceText, contains('Top-level Gradle build file not found, skipping migration of task "clean".'));
        expect(testLogger.statusText, isEmpty);
      });

      testUsingContext('skipped if nothing to upgrade', () {
        topLevelGradleBuildFile.writeAsStringSync('''
tasks.register("clean", Delete) {
  delete rootProject.buildDir
}
        ''');

        final TopLevelGradleBuildFileMigration androidProjectMigration = TopLevelGradleBuildFileMigration(
          project,
          bufferLogger,
        );
        final DateTime topLevelGradleBuildFileLastModified = topLevelGradleBuildFile.lastModifiedSync();
        androidProjectMigration.migrate();

        expect(topLevelGradleBuildFile.lastModifiedSync(), topLevelGradleBuildFileLastModified);
        expect(testLogger.statusText, isEmpty);
      });

      testUsingContext('top-level build.gradle is migrated', () {
        topLevelGradleBuildFile.writeAsStringSync('''
task clean(type: Delete) {
    delete rootProject.buildDir
}
''');

        final TopLevelGradleBuildFileMigration androidProjectMigration = TopLevelGradleBuildFileMigration(
          project,
          bufferLogger,
        );
        androidProjectMigration.migrate();

        expect(bufferLogger.traceText, contains('Migrating "clean" Gradle task to lazy declaration style.'));
        expect(testLogger.statusText, isEmpty);

        expect(topLevelGradleBuildFile.readAsStringSync(), equals('''
tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
'''));
      });
    });
  });
}

class FakeAndroidProject extends Fake implements AndroidProject {
  FakeAndroidProject(this.hostAppGradleRoot);

  @override
  Directory hostAppGradleRoot;
}

class FakeAndroidMigrator extends ProjectMigrator {
  FakeAndroidMigrator() : super(BufferLogger.test());

  @override
  void migrate() {}

  @override
  String migrateLine(String line) {
    return line;
  }
}
