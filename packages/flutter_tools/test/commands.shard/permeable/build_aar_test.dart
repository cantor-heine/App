// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:args/command_runner.dart';
import 'package:flutter_tools/src/android/android_builder.dart';
import 'package:flutter_tools/src/android/android_sdk.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/build_aar.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/globals_null_migrated.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:meta/meta.dart';
import 'package:test/fake.dart';

import '../../src/android_common.dart';
import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/fakes.dart';
import '../../src/test_flutter_command_runner.dart';

void main() {
  Cache.disableLocking();

  Future<BuildAarCommand> runCommandIn(String target, { List<String> arguments }) async {
    final BuildAarCommand command = BuildAarCommand(verboseHelp: false);
    final CommandRunner<void> runner = createTestCommandRunner(command);
    await runner.run(<String>[
      'aar',
      '--no-pub',
      ...?arguments,
      target,
    ]);
    return command;
  }

  group('Usage', () {
    Directory tempDir;
    TestUsage testUsage;

    setUp(() {
      testUsage = TestUsage();
      tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_tools_packages_test.');
    });

    tearDown(() {
      tryToDelete(tempDir);
    });

    testUsingContext('indicate that project is a module', () async {
      final String projectPath = await createProject(tempDir,
          arguments: <String>['--no-pub', '--template=module']);

      final BuildAarCommand command = await runCommandIn(projectPath);
      expect((await command.usageValues).commandBuildAarProjectType, 'module');

    }, overrides: <Type, Generator>{
      AndroidBuilder: () => FakeAndroidBuilder(),
    });

    testUsingContext('indicate that project is a plugin', () async {
      final String projectPath = await createProject(tempDir,
          arguments: <String>['--no-pub', '--template=plugin', '--project-name=aar_test']);

      final BuildAarCommand command = await runCommandIn(projectPath);
      expect((await command.usageValues).commandBuildAarProjectType, 'plugin');

    }, overrides: <Type, Generator>{
      AndroidBuilder: () => FakeAndroidBuilder(),
    });

    testUsingContext('indicate the target platform', () async {
      final String projectPath = await createProject(tempDir,
          arguments: <String>['--no-pub', '--template=module']);

      final BuildAarCommand command = await runCommandIn(projectPath,
          arguments: <String>['--target-platform=android-arm']);
      expect((await command.usageValues).commandBuildAarTargetPlatform, 'android-arm');

    }, overrides: <Type, Generator>{
      AndroidBuilder: () => FakeAndroidBuilder(),
    });

    testUsingContext('logs success', () async {
      final String projectPath = await createProject(tempDir,
          arguments: <String>['--no-pub', '--template=module']);

      await runCommandIn(projectPath,
          arguments: <String>['--target-platform=android-arm']);

      expect(testUsage.events, contains(
        const TestUsageEvent(
          'tool-command-result',
          'aar',
          label: 'success',
        ),
      ));
    },
    overrides: <Type, Generator>{
      AndroidBuilder: () => FakeAndroidBuilder(),
      Usage: () => testUsage,
    });
  });

  group('flag parsing', () {
    Directory tempDir;
    FakeAndroidBuilder fakeAndroidBuilder;

    setUp(() {
      fakeAndroidBuilder = FakeAndroidBuilder();
      tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_tools_build_aar_test.');
    });

    tearDown(() {
      tryToDelete(tempDir);
    });

    testUsingContext('defaults', () async {
      final String projectPath = await createProject(tempDir,
        arguments: <String>['--no-pub']);
      await runCommandIn(projectPath);

      expect(fakeAndroidBuilder.buildNumber, '1.0');
      expect(fakeAndroidBuilder.androidBuildInfo.length, 3);

      final List<BuildMode> buildModes = <BuildMode>[];
      for (final AndroidBuildInfo androidBuildInfo in fakeAndroidBuilder.androidBuildInfo) {
        final BuildInfo buildInfo = androidBuildInfo.buildInfo;
        buildModes.add(buildInfo.mode);
        if (buildInfo.mode.isPrecompiled) {
          expect(buildInfo.treeShakeIcons, isTrue);
          expect(buildInfo.trackWidgetCreation, isTrue);
        } else {
          expect(buildInfo.treeShakeIcons, isFalse);
          expect(buildInfo.trackWidgetCreation, isTrue);
        }
        expect(buildInfo.flavor, isNull);
        expect(buildInfo.splitDebugInfoPath, isNull);
        expect(buildInfo.dartObfuscation, isFalse);
        expect(androidBuildInfo.targetArchs, <AndroidArch>[AndroidArch.armeabi_v7a, AndroidArch.arm64_v8a, AndroidArch.x86_64]);
      }
      expect(buildModes.length, 3);
      expect(buildModes, containsAll(<BuildMode>[BuildMode.debug, BuildMode.profile, BuildMode.release]));
    }, overrides: <Type, Generator>{
      AndroidBuilder: () => fakeAndroidBuilder,
    });

    testUsingContext('parses flags', () async {
      final String projectPath = await createProject(tempDir,
        arguments: <String>['--no-pub']);
      await runCommandIn(
        projectPath,
        arguments: <String>[
          '--no-debug',
          '--no-profile',
          '--target-platform',
          'android-x86',
          '--tree-shake-icons',
          '--flavor',
          'free',
          '--build-number',
          '200',
          '--split-debug-info',
          '/project-name/v1.2.3/',
          '--obfuscate',
          '--dart-define=foo=bar'
        ],
      );

      expect(fakeAndroidBuilder.buildNumber, '200');

      final AndroidBuildInfo androidBuildInfo = fakeAndroidBuilder.androidBuildInfo.single;
      expect(androidBuildInfo.targetArchs, <AndroidArch>[AndroidArch.x86]);

      final BuildInfo buildInfo = androidBuildInfo.buildInfo;
      expect(buildInfo.mode, BuildMode.release);
      expect(buildInfo.treeShakeIcons, isTrue);
      expect(buildInfo.flavor, 'free');
      expect(buildInfo.splitDebugInfoPath, '/project-name/v1.2.3/');
      expect(buildInfo.dartObfuscation, isTrue);
      expect(buildInfo.dartDefines.contains('foo=bar'), isTrue);
      expect(buildInfo.nullSafetyMode, NullSafetyMode.sound);
    }, overrides: <Type, Generator>{
      AndroidBuilder: () => fakeAndroidBuilder,
    });
  });

  group('Gradle', () {
    Directory tempDir;
    AndroidSdk mockAndroidSdk;


    setUp(() {
      tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_tools_packages_test.');
      mockAndroidSdk = FakeAndroidSdk(globals.fs.directory('irrelevant'));
    });

    tearDown(() {
      tryToDelete(tempDir);
    });

    group('AndroidSdk', () {
      testUsingContext('throws throwsToolExit if AndroidSdk is null', () async {
        final String projectPath = await createProject(tempDir,
            arguments: <String>['--no-pub', '--template=module']);

        await expectLater(() async {
          await runBuildAarCommand(
            projectPath,
            arguments: <String>['--no-pub'],
          );
        }, throwsToolExit(
          message: 'No Android SDK found. Try setting the ANDROID_SDK_ROOT environment variable',
        ));
      },
      overrides: <Type, Generator>{
        AndroidSdk: () => null,
        FlutterProjectFactory: () => FakeFlutterProjectFactory(tempDir),
        ProcessManager: () => FakeProcessManager.any(),
      });
    });

    testUsingContext('support ExtraDartFlagOptions',
            () async {
      final String projectPath = await createProject(tempDir,
          arguments: <String>['--no-pub', '--template=module']);

      globals.fs.directory(globals.fs.path.join(tempDir.path, 'flutter_project',
          'build', 'host','outputs','repo')).createSync(recursive: true);

      await runBuildAarCommand(projectPath,
          arguments: <String>[
            '--extra-front-end-options=foo',
            '--extra-front-end-options=bar',
            '--extra-front-end-options=--testflag,--testflag2'
          ]);
    },
        overrides: <Type, Generator>{
          AndroidSdk: () => mockAndroidSdk,
          FlutterProjectFactory: () => FakeFlutterProjectFactory(tempDir),
          ProcessManager: () => FakeProcessManager.any(),
          FeatureFlags: () => TestFeatureFlags(isIOSEnabled: false),
    });
  });
}

Future<BuildAarCommand> runBuildAarCommand(
  String target, {
  List<String> arguments,
}) async {
  final BuildAarCommand command = BuildAarCommand(verboseHelp: false);
  final CommandRunner<void> runner = createTestCommandRunner(command);
  await runner.run(<String>[
    'aar',
    '--no-pub',
    ...?arguments,
    globals.fs.path.join(target, 'lib', 'main.dart'),
  ]);
  return command;
}

class FakeAndroidBuilder extends Fake implements AndroidBuilder {
  FlutterProject project;
  Set<AndroidBuildInfo> androidBuildInfo;
  String target;
  String outputDirectoryPath;
  String buildNumber;

  @override
  Future<void> buildAar({
    @required FlutterProject project,
    @required Set<AndroidBuildInfo> androidBuildInfo,
    @required String target,
    @required String outputDirectoryPath,
    @required String buildNumber,
  }) async {
    this.project = project;
    this.androidBuildInfo = androidBuildInfo;
    this.target = target;
    this.outputDirectoryPath = outputDirectoryPath;
    this.buildNumber = buildNumber;
  }
}

class FakeAndroidSdk extends Fake implements AndroidSdk {
  FakeAndroidSdk(this.directory);

  @override
  final Directory directory;
}
