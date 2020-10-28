// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

import '../android/android_device.dart';
import '../application_package.dart';
import '../artifacts.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../build_info.dart';
import '../device.dart';
import '../drive/drive_service.dart';
import '../globals.dart' as globals;
import '../runner/flutter_command.dart' show FlutterCommandResult, FlutterOptions;
import '../web/web_device.dart';
import 'run.dart';

/// Runs integration (a.k.a. end-to-end) tests.
///
/// An integration test is a program that runs in a separate process from your
/// Flutter application. It connects to the application and acts like a user,
/// performing taps, scrolls, reading out widget properties and verifying their
/// correctness.
///
/// This command takes a target Flutter application that you would like to test
/// as the `--target` option (defaults to `lib/main.dart`). It then looks for a
/// corresponding test file within the `test_driver` directory. The test file is
/// expected to have the same name but contain the `_test.dart` suffix. The
/// `_test.dart` file would generally be a Dart program that uses
/// `package:flutter_driver` and exercises your application. Most commonly it
/// is a test written using `package:test`, but you are free to use something
/// else.
///
/// The app and the test are launched simultaneously. Once the test completes
/// the application is stopped and the command exits. If all these steps are
/// successful the exit code will be `0`. Otherwise, you will see a non-zero
/// exit code.
class DriveCommand extends RunCommandBase {
  DriveCommand({
    bool verboseHelp = false,
    @visibleForTesting FlutterDriverFactory flutterDriverFactory,
    @required FileSystem fileSystem,
    @required Logger logger,
  }) : _flutterDriverFactory = flutterDriverFactory,
       _fileSystem = fileSystem,
       _logger = logger {
    requiresPubspecYaml();
    addEnableExperimentation(hide: !verboseHelp);

    // By default, the drive app should not publish the VM service port over mDNS
    // to prevent a local network permission dialog on iOS 14+,
    // which cannot be accepted or dismissed in a CI environment.
    addPublishPort(enabledByDefault: false, verboseHelp: verboseHelp);
    argParser
      ..addFlag('keep-app-running',
        defaultsTo: null,
        help: 'Will keep the Flutter application running when done testing.\n'
              'By default, "flutter drive" stops the application after tests are finished, '
              'and --keep-app-running overrides this. On the other hand, if --use-existing-app '
              'is specified, then "flutter drive" instead defaults to leaving the application '
              'running, and --no-keep-app-running overrides it.',
      )
      ..addOption('use-existing-app',
        help: 'Connect to an already running instance via the given observatory URL. '
              'If this option is given, the application will not be automatically started, '
              'and it will only be stopped if --no-keep-app-running is explicitly set.',
        valueHelp: 'url',
      )
      ..addOption('driver',
        help: 'The test file to run on the host (as opposed to the target file to run on '
              'the device).\n'
              'By default, this file has the same base name as the target file, but in the '
              '"test_driver/" directory instead, and with "_test" inserted just before the '
              'extension, so e.g. if the target is "lib/main.dart", the driver will be '
              '"test_driver/main_test.dart".',
        valueHelp: 'path',
      )
      ..addFlag('build',
        defaultsTo: true,
        help: '(Deprecated) Build the app before running. To use an existing app, pass the --use-application-binary '
          'flag with an existing APK',
      )
      ..addOption('driver-port',
        defaultsTo: '4444',
        help: 'The port where Webdriver server is launched at. Defaults to 4444.',
        valueHelp: '4444'
      )
      ..addFlag('headless',
        defaultsTo: true,
        help: 'Whether the driver browser is going to be launched in headless mode. Defaults to true.',
      )
      ..addOption('browser-name',
        defaultsTo: 'chrome',
        help: 'Name of browser where tests will be executed. \n'
              'Following browsers are supported: \n'
              'Chrome, Firefox, Safari (macOS and iOS) and Edge. Defaults to Chrome.',
        allowed: <String>[
          'android-chrome',
          'chrome',
          'edge',
          'firefox',
          'ios-safari',
          'safari',
        ],
      )
      ..addOption('browser-dimension',
        defaultsTo: '1600,1024',
        help: 'The dimension of browser when running Flutter Web test. \n'
              'This will affect screenshot and all offset-related actions. \n'
              'By default. it is set to 1600,1024 (1600 by 1024).',
      )
      ..addFlag('android-emulator',
        defaultsTo: true,
        help: 'Whether to perform Flutter Driver testing on Android Emulator.'
          'Works only if \'browser-name\' is set to \'android-chrome\'')
      ..addOption('chrome-binary',
        help: 'Location of Chrome binary. '
          'Works only if \'browser-name\' is set to \'chrome\'')
      ..addOption('write-sksl-on-exit',
        help:
          'Attempts to write an SkSL file when the drive process is finished '
          'to the provided file, overwriting it if necessary.')
      ..addMultiOption('test-arguments', help: 'Additional arguments to pass to the '
          'Dart VM running The test script.');
  }

  FlutterDriverFactory _flutterDriverFactory;
  final FileSystem _fileSystem;
  final Logger _logger;

  @override
  final String name = 'drive';

  @override
  final String description = 'Run integration tests for the project on an attached device or emulator.';

  @override
  final List<String> aliases = <String>['driver'];

  String get userIdentifier => stringArg(FlutterOptions.kDeviceUser);

  @override
  bool get startPausedDefault => true;

  @override
  Future<void> validateCommand() async {
    if (userIdentifier != null) {
      final Device device = await findTargetDevice();
      if (device is! AndroidDevice) {
        throwToolExit('--${FlutterOptions.kDeviceUser} is only supported for Android');
      }
    }
    return super.validateCommand();
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    final String testFile = _getTestFile();
    if (testFile == null) {
      throwToolExit(null);
    }
    if (await _fileSystem.type(testFile) != FileSystemEntityType.file) {
      throwToolExit('Test file not found: $testFile');
    }
    final Device device = await findTargetDevice(includeUnsupportedDevices: stringArg('use-application-binary') == null);
    if (device == null) {
      throwToolExit(null);
    }

    final bool web = device is WebServerDevice || device is ChromiumDevice;
    _flutterDriverFactory ??= FlutterDriverFactory(
      applicationPackageFactory: ApplicationPackageFactory.instance,
      logger: _logger,
      processUtils: globals.processUtils,
      dartSdkPath: globals.artifacts.getArtifactPath(Artifact.engineDartBinary),
   );
    final DriverService driverService = _flutterDriverFactory.createDriverService(web);
    final BuildInfo buildInfo = getBuildInfo();
    final DebuggingOptions debuggingOptions = createDebuggingOptions();
    final File applicationBinary = stringArg('use-application-binary') == null
      ? null
      : _fileSystem.file(stringArg('use-application-binary'));

    await driverService.start(
      buildInfo,
      device,
      debuggingOptions,
      ipv6,
      applicationBinary: applicationBinary,
      route: route,
      userIdentifier: userIdentifier,
      mainPath: targetFile,
      platformArgs: <String, Object>{
        if (traceStartup)
          'trace-startup': traceStartup,
        if (web)
          '--no-launch-chrome': true,
      }
    );

    final int testResult = await driverService.startTest(
      testFile,
      stringsArg('test-arguments'),
      <String, String>{},
      chromeBinary: stringArg('chrome-binary'),
      headless: boolArg('headless'),
      browserDimension: stringArg('browser-dimension').split(','),
      browserName: stringArg('browser-name'),
      driverPort: stringArg('driver-port') != null
        ? int.tryParse(stringArg('driver-port'))
        : null,
      androidEmulator: boolArg('android-emulator'),
    );

    if (boolArg('keep-app-running') ?? (argResults['use-existing-app'] != null)) {
      _logger.printStatus('Leaving the application running.');
    } else {
      final File skslFile = stringArg('write-sksl-on-exit') != null
        ? _fileSystem.file(stringArg('write-sksl-on-exit'))
        : null;
      await driverService.stop(userIdentifier: userIdentifier, writeSkslOnExit: skslFile);
    }
    if (testResult != 0) {
      throwToolExit(null);
    }
    return FlutterCommandResult.success();
  }

  String _getTestFile() {
    if (argResults['driver'] != null) {
      return stringArg('driver');
    }

    // If the --driver argument wasn't provided, then derive the value from
    // the target file.
    String appFile = _fileSystem.path.normalize(targetFile);

    // This command extends `flutter run` and therefore CWD == package dir
    final String packageDir = _fileSystem.currentDirectory.path;

    // Make appFile path relative to package directory because we are looking
    // for the corresponding test file relative to it.
    if (!_fileSystem.path.isRelative(appFile)) {
      if (!_fileSystem.path.isWithin(packageDir, appFile)) {
        _logger.printError(
          'Application file $appFile is outside the package directory $packageDir'
        );
        return null;
      }

      appFile = _fileSystem.path.relative(appFile, from: packageDir);
    }

    final List<String> parts = _fileSystem.path.split(appFile);

    if (parts.length < 2) {
      _logger.printError(
        'Application file $appFile must reside in one of the sub-directories '
        'of the package structure, not in the root directory.'
      );
      return null;
    }

    // Look for the test file inside `test_driver/` matching the sub-path, e.g.
    // if the application is `lib/foo/bar.dart`, the test file is expected to
    // be `test_driver/foo/bar_test.dart`.
    final String pathWithNoExtension = _fileSystem.path.withoutExtension(_fileSystem.path.joinAll(
      <String>[packageDir, 'test_driver', ...parts.skip(1)]));
    return '${pathWithNoExtension}_test${_fileSystem.path.extension(appFile)}';
  }
}
