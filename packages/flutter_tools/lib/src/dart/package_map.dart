// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:package_config/package_config.dart';

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../convert.dart';

const String kPackagesFileName = '.packages';

// No touching!
String get globalPackagesPath => _globalPackagesPath ?? kPackagesFileName;

set globalPackagesPath(String value) {
  _globalPackagesPath = value;
}

bool get isUsingCustomPackagesPath => _globalPackagesPath != null;

String _globalPackagesPath;

/// Load the package configuration from [file] or throws a [ToolExit]
/// if the operation would fail.
///
/// If [nonFatal] is true, in the event of an error an empty package
/// config is returned.
Future<PackageConfig> loadPackageConfigWithLogging(File file, {
  @required Logger logger,
  bool throwOnError = true,
}) async {
  final FileSystem fileSystem = file.fileSystem;
  bool didError = false;
  final PackageConfig result = await loadPackageConfigUri(
    file.absolute.uri,
    loader: (Uri uri) {
      final File configFile = fileSystem.file(uri);
      if (!configFile.existsSync()) {
        return null;
      }
      return Future<Uint8List>.value(configFile.readAsBytesSync());
    },
    onError: (dynamic error) {
      if (!throwOnError) {
        return;
      }
      logger.printTrace(error.toString());
      String message = '${file.path} does not exist.';
      final String pubspecPath = fileSystem.path.absolute(fileSystem.path.dirname(file.path), 'pubspec.yaml');
      if (fileSystem.isFileSync(pubspecPath)) {
        message += '\nDid you run "flutter pub get" in this directory?';
      } else {
        message += '\nDid you run this command from the same directory as your pubspec.yaml file?';
      }
      logger.printError(message);
      didError = true;
    }
  );
  if (didError) {
    throwToolExit(null);
  }
  return result;
}

/// Parses a [PackageConfig] from the given package file.
///
/// If parsing fails, returns an empty package config unless `fatal` is true.
PackageConfig createPackageConfig(File file, {bool fatal = false}) {
  try {
    final Uri baseLocation = file.absolute.uri;
    final Map<String, Object> rawData = json.decode(file.readAsStringSync()) as Map<String, Object>;
    final List<Object> rawPackages = rawData['packages'] as List<Object>;
    final List<Package> packages = <Package>[];
    for (final Object rawPackage in rawPackages) {
      final Map<String, Object> packageData = rawPackage as Map<String, Object>;
      final String name = packageData['name'] as String;
      Uri rootUri = Uri.parse(packageData['rootUri'] as String);
      final Uri packageUri = Uri.parse(packageData['packageUri'] as String);
      rootUri = baseLocation.resolveUri(rootUri);
      if (!rootUri.path.endsWith('/')) {
        rootUri = rootUri.replace(path: rootUri.path + '/');
      }
      Uri packageRoot = rootUri;
      if (packageUri != null) {
        packageRoot = rootUri.resolveUri(packageUri);
      }
      if (!packageRoot.path.endsWith('/')) {
        packageRoot = packageRoot.replace(path: packageRoot.path + '/');
      }
      final LanguageVersion languageVersion = LanguageVersion.parse(packageData['languageVersion'] as String);
      packages.add(Package(
        name,
        rootUri,
        packageUriRoot: packageUri,
        languageVersion: languageVersion,
      ));
    }
    return PackageConfig(packages);
  } on Exception {
    if (fatal) {
      rethrow;
    }
    return PackageConfig.empty;
  }
}
