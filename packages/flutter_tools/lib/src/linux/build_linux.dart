// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:unified_analytics/unified_analytics.dart';

import '../artifacts.dart';
import '../base/analyze_size.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/project_migrator.dart';
import '../base/terminal.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../cache.dart';
import '../cmake.dart';
import '../cmake_project.dart';
import '../convert.dart';
import '../flutter_plugins.dart';
import '../globals.dart' as globals;
import '../migrations/cmake_custom_command_migration.dart';
import '../migrations/cmake_native_assets_migration.dart';

// Matches the following error and warning patterns:
// - <file path>:<line>:<column>: (fatal) error: <error...>
// - <file path>:<line>:<column>: warning: <warning...>
// - clang: error: <link error...>
// - Error: <tool error...>
final RegExp errorMatcher = RegExp(r'(?:(?:.*:\d+:\d+|clang):\s)?(fatal\s)?(?:error|warning):\s.*', caseSensitive: false);

/// Builds the Linux project through the Makefile.
Future<void> buildLinux(
  LinuxProject linuxProject,
  BuildInfo buildInfo, {
  String? target,
  SizeAnalyzer? sizeAnalyzer,
  bool needCrossBuild = false,
  required TargetPlatform targetPlatform,
  String targetSysroot = '/',
  required Logger logger,
}) async {
  target ??= 'lib/main.dart';
  if (!linuxProject.cmakeFile.existsSync()) {
    throwToolExit('No Linux desktop project configured. See '
      'https://docs.flutter.dev/desktop#add-desktop-support-to-an-existing-flutter-app '
      'to learn about adding Linux support to a project.');
  }

  final List<ProjectMigrator> migrators = <ProjectMigrator>[
    CmakeCustomCommandMigration(linuxProject, logger),
    CmakeNativeAssetsMigration(linuxProject, 'linux', logger),
  ];

  final ProjectMigration migration = ProjectMigration(migrators);
  await migration.run();

  // Build the environment that needs to be set for the re-entrant flutter build
  // step.
  final Map<String, String> environmentConfig = buildInfo.toEnvironmentConfig();
  environmentConfig['FLUTTER_TARGET'] = target;
  final LocalEngineInfo? localEngineInfo = globals.artifacts?.localEngineInfo;
  if (localEngineInfo != null) {
    final String targetOutPath = localEngineInfo.targetOutPath;
    // $ENGINE/src/out/foo_bar_baz -> $ENGINE/src
    environmentConfig['FLUTTER_ENGINE'] = globals.fs.path.dirname(globals.fs.path.dirname(targetOutPath));
    environmentConfig['LOCAL_ENGINE'] = localEngineInfo.localTargetName;
    environmentConfig['LOCAL_ENGINE_HOST'] = localEngineInfo.localHostName;
  }
  writeGeneratedCmakeConfig(Cache.flutterRoot!, linuxProject, buildInfo, environmentConfig, logger);

  createPluginSymlinks(linuxProject.parent);

  final Status status = logger.startProgress(
    'Building Linux application...',
  );
  final String buildModeName = buildInfo.mode.cliName;
  final Directory platformBuildDirectory = globals.fs.directory(getLinuxBuildDirectory(targetPlatform));
  final Directory buildDirectory = platformBuildDirectory.childDirectory(buildModeName);
  try {
    await _runCmake(buildModeName, linuxProject.cmakeFile.parent, buildDirectory,
                    needCrossBuild, targetPlatform, targetSysroot);
    await _runBuild(buildDirectory);
  } finally {
    status.cancel();
  }

  final String? binaryName = getCmakeExecutableName(linuxProject);
  final File binaryFile = buildDirectory
    .childDirectory('bundle')
    .childFile('$binaryName');
  final FileSystemEntity buildOutput =  binaryFile.existsSync() ? binaryFile : binaryFile.parent;
  // We don't print a size because the output directory can contain
  // optional files not needed by the user and because the binary is not
  // self-contained.
  globals.printStatus(
    '${globals.terminal.successMark} '
    'Built ${globals.fs.path.relative(buildOutput.path)}',
    color: TerminalColor.green,
  );

  if (buildInfo.codeSizeDirectory != null && sizeAnalyzer != null) {
    final String arch = getNameForTargetPlatform(targetPlatform);
    final File codeSizeFile = globals.fs.directory(buildInfo.codeSizeDirectory)
      .childFile('snapshot.$arch.json');
    final File precompilerTrace = globals.fs.directory(buildInfo.codeSizeDirectory)
      .childFile('trace.$arch.json');
    final Map<String, Object?> output = await sizeAnalyzer.analyzeAotSnapshot(
      aotSnapshot: codeSizeFile,
      // This analysis is only supported for release builds.
      outputDirectory: globals.fs.directory(
        globals.fs.path.join(getLinuxBuildDirectory(targetPlatform), 'release', 'bundle'),
      ),
      precompilerTrace: precompilerTrace,
      type: 'linux',
    );
    final File outputFile = globals.fsUtils.getUniqueFile(
      globals.fs
        .directory(globals.fsUtils.homeDirPath)
        .childDirectory('.flutter-devtools'), 'linux-code-size-analysis', 'json',
    )..writeAsStringSync(jsonEncode(output));
    // This message is used as a sentinel in analyze_apk_size_test.dart
    logger.printStatus(
      'A summary of your Linux bundle analysis can be found at: ${outputFile.path}',
    );

    // DevTools expects a file path relative to the .flutter-devtools/ dir.
    final String relativeAppSizePath = outputFile.path.split('.flutter-devtools/').last.trim();
    logger.printStatus(
      '\nTo analyze your app size in Dart DevTools, run the following command:\n'
      'dart devtools --appSizeBase=$relativeAppSizePath'
    );
  }
}

Future<void> _runCmake(String buildModeName, Directory sourceDir, Directory buildDir,
    bool needCrossBuild, TargetPlatform targetPlatform, String targetSysroot) async {
  final Stopwatch sw = Stopwatch()..start();

  await buildDir.create(recursive: true);

  final String buildFlag = sentenceCase(buildModeName);
  final bool needCrossBuildOptionsForArm64 = needCrossBuild
      && targetPlatform == TargetPlatform.linux_arm64;
  int result;
  if (!globals.processManager.canRun('cmake')) {
    throwToolExit(globals.userMessages.cmakeMissing);
  }

  final String? cc = Platform.environment['CC'];
  final String? cxx = Platform.environment['CXX'];

  final String? clang = _which(cc ?? 'clang');
  if (clang == null) {
    if (cc != null) {
      throwToolExit('Unable to locate $cc for CC environment variable.'
          ' Please ensure that $cc is installed and in your PATH.');
    } else {
      throwToolExit('Unable to locate clang');
    }
  }
  final String? clangPlusPlus = _which(cxx ?? 'clang++');
  if (clangPlusPlus == null) {
    if (cxx != null) {
      throwToolExit('Unable to locate $cxx for CXX environment variable.'
          ' Please ensure that $cxx is installed and in your PATH.');
    } else {
      throwToolExit('Unable to locate clang++');
    }
  }
  // Warn user if C/C++ compilers are not the system default clang/clang++.
  if (!clang.startsWith('/usr/bin/clang')) {
    globals.printStatus(
      'Warning: C compiler is set to $clang.${(cc != null) ? ' CC environment variable is set to $cc.' : ''} '
      'Please consider using the distribution-provided clang',
      color: TerminalColor.yellow,
    );
  }

  if (!clangPlusPlus.startsWith('/usr/bin/clang++')) {
    globals.printStatus(
      'Warning: C++ compiler is set to $clangPlusPlus.${(cxx != null) ? ' CXX environment variable is set to $cxx.' : ''} '
      'Please consider using the distribution-provided clang++',
      color: TerminalColor.yellow,
    );
  }

  result = await globals.processUtils.stream(
    <String>[
      'cmake',
      '-G',
      'Ninja',
      '-DCMAKE_BUILD_TYPE=$buildFlag',
      '-DFLUTTER_TARGET_PLATFORM=${getNameForTargetPlatform(targetPlatform)}',
      // Support cross-building for arm64 targets on x64 hosts.
      // (Cross-building for x64 on arm64 hosts isn't supported now.)
      if (needCrossBuild)
        '-DFLUTTER_TARGET_PLATFORM_SYSROOT=$targetSysroot',
      if (needCrossBuildOptionsForArm64)
        '-DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu',
      if (needCrossBuildOptionsForArm64)
        '-DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-gnu',
      sourceDir.path,
    ],
    workingDirectory: buildDir.path,
    environment: <String, String>{
      'CC': clang,
      'CXX': clangPlusPlus,
    },
    trace: true,
  );
  if (result != 0) {
    throwToolExit('Unable to generate build files');
  }
  final Duration elapsedDuration = sw.elapsed;
  globals.flutterUsage.sendTiming('build', 'cmake-linux', elapsedDuration);
  globals.analytics.send(Event.timing(
    workflow: 'build',
    variableName: 'cmake-linux',
    elapsedMilliseconds: elapsedDuration.inMilliseconds,
  ));
}

Future<void> _runBuild(Directory buildDir) async {
  final Stopwatch sw = Stopwatch()..start();

  int result;
  try {
    result = await globals.processUtils.stream(
      <String>[
        'ninja',
        '-C',
        buildDir.path,
        'install',
      ],
      environment: <String, String>{
        if (globals.logger.isVerbose)
          'VERBOSE_SCRIPT_LOGGING': 'true',
        if (!globals.logger.isVerbose)
          'PREFIXED_ERROR_LOGGING': 'true',
      },
      trace: true,
      stdoutErrorMatcher: errorMatcher,
    );
  } on ArgumentError {
    throwToolExit("ninja not found. Run 'flutter doctor' for more information.");
  }
  if (result != 0) {
    throwToolExit('Build process failed');
  }
  final Duration elapsedDuration = sw.elapsed;
  globals.flutterUsage.sendTiming('build', 'linux-ninja', elapsedDuration);
  globals.analytics.send(Event.timing(
    workflow: 'build',
    variableName: 'linux-ninja',
    elapsedMilliseconds: elapsedDuration.inMilliseconds,
  ));
}

// This is a simplified version of the 'which' command.
String? _which(String executable) {
  if (executable.isEmpty) {
    return null;
  }

  if (executable.contains('/')) {
    final File file = globals.fs.file(executable);
    if (file.existsSync() && _checkIfExecutable(file)) {
      return file.path;
    }
    return null;
  }

  final String? envPath = globals.platform.environment['PATH'];
  if (envPath == null) {
    return null;
  }

  final List<String> pathSegments = envPath.split(':');
  for (final String pathSegment in pathSegments) {
    final File file =
        globals.fs.file(globals.fs.path.join(pathSegment, executable));
    if (file.existsSync() && _checkIfExecutable(file)) {
      return file.path;
    }
  }

  return null;
}

bool _checkIfExecutable(File file) {
  final FileStat stat = file.statSync();
  const int isExecutable = 0x40;
  const int isReadable = 0x100;
  const int isExecutableAndReadable = isExecutable | isReadable;
  return (stat.mode & isExecutableAndReadable) == isExecutableAndReadable;
}
