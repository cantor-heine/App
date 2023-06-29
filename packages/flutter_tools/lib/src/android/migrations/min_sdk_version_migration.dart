// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../../base/file_system.dart';
import '../../base/project_migrator.dart';
import '../../project.dart';
import '../gradle_utils.dart';

@visibleForTesting
const String minSdk16 = 'minSdkVersion 16';
@visibleForTesting
const String minSdk17 = 'minSdkVersion 17';
@visibleForTesting
const String minSdk18 = 'minSdkVersion 18';
@visibleForTesting
const String flutterMinSdk = 'minSdkVersion flutter.minSdkVersion';
@visibleForTesting
const String appGradleNotFoundWarning = 'Module level build.gradle file not found, skipping minSdkVersion migration.';

class MinSdkVersionMigration extends ProjectMigrator {
  MinSdkVersionMigration(
      AndroidProject project,
      super.logger,
  ) : _project = project;


  final AndroidProject _project;

  @override
  void migrate() {
    try {
      processFileLines(_project.appGradleFile);
    } on FileSystemException {
      // Skip if we cannot find the app level build.gradle file.
      logger.printTrace(appGradleNotFoundWarning);
    }
  }

  @override
  String migrateFileContents(String fileContents) {
    return fileContents.replaceAll(jellyBeanMinSdkVersionMatch, flutterMinSdk);
  }
}
