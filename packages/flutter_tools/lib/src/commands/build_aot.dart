// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../aot.dart';
import '../base/common.dart';
import '../build_info.dart';
import '../ios/bitcode.dart';
import '../resident_runner.dart';
import '../runner/flutter_command.dart';
import 'build.dart';

/// Builds AOT snapshots into platform specific library containers.
class BuildAotCommand extends BuildSubCommand with TargetPlatformBasedDevelopmentArtifacts {
  BuildAotCommand({this.aotBuilder}) {
    addTreeShakeIconsFlag();
    usesTargetOption();
    addBuildModeFlags();
    usesPubOption();
    usesDartDefines();
    argParser
      ..addOption('output-dir', defaultsTo: getAotBuildDirectory())
      ..addOption('target-platform',
        defaultsTo: 'android-arm',
        allowed: <String>['android-arm', 'android-arm64', 'ios', 'android-x64'],
      )
      ..addFlag('quiet', defaultsTo: false)
      ..addMultiOption('ios-arch',
        splitCommas: true,
        defaultsTo: defaultIOSArchs.map<String>(getNameForDarwinArch),
        allowed: DarwinArch.values.map<String>(getNameForDarwinArch),
        help: 'iOS architectures to build.',
      )
      ..addMultiOption(FlutterOptions.kExtraFrontEndOptions,
        splitCommas: true,
        hide: true,
      )
      ..addMultiOption(FlutterOptions.kExtraGenSnapshotOptions,
        splitCommas: true,
        hide: true,
      )
      ..addFlag('bitcode',
        defaultsTo: kBitcodeEnabledDefault,
        help: 'Build the AOT bundle with bitcode. Requires a compatible bitcode engine.',
        hide: true,
      );
  }

  AotBuilder aotBuilder;

  @override
  final String name = 'aot';

  @override
  final String description = "Build an ahead-of-time compiled snapshot of your app's Dart code.";

  @override
  Future<FlutterCommandResult> runCommand() async {
    final String targetPlatform = stringArg('target-platform');
    final TargetPlatform platform = getTargetPlatformForName(targetPlatform);
    final String outputPath = stringArg('output-dir') ?? getAotBuildDirectory();
    final BuildMode buildMode = getBuildMode();
    if (platform == null) {
      throwToolExit('Unknown platform: $targetPlatform');
    }

    aotBuilder ??= AotBuilder();

    await aotBuilder.build(
      platform: platform,
      outputPath: outputPath,
      buildMode: buildMode,
      mainDartFile: findMainDartFile(targetFile),
      bitcode: boolArg('bitcode'),
      quiet: boolArg('quiet'),
      iosBuildArchs: stringsArg('ios-arch').map<DarwinArch>(getIOSArchForName),
      extraFrontEndOptions: stringsArg(FlutterOptions.kExtraFrontEndOptions),
      extraGenSnapshotOptions: stringsArg(FlutterOptions.kExtraGenSnapshotOptions),
      dartDefines: dartDefines,
      treeShakeIcons: boolArg('tree-shake-icons'),
    );
    return FlutterCommandResult.success();
  }
}
