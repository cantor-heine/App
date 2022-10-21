// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pool/pool.dart';
import 'package:process/process.dart';

import '../../artifacts.dart';
import '../../base/error_handling_io.dart';
import '../../base/file_system.dart';
import '../../base/io.dart';
import '../../base/logger.dart';
import '../../build_info.dart';
import '../../convert.dart';
import '../../devfs.dart';
import '../build_system.dart';

/// The output shader format that should be used by the [ShaderCompiler].
enum ShaderTarget {
  impellerAndroid('--runtime-stage-gles'),
  impelleriOS('--runtime-stage-metal'),
  sksl('--sksl');

  const ShaderTarget(this.target);

  final String target;
}

/// A wrapper around [ShaderCompiler] to support hot reload of shader sources.
class DevelopmentShaderCompiler {
  DevelopmentShaderCompiler({
    required ShaderCompiler shaderCompiler,
    required FileSystem fileSystem,
    @visibleForTesting math.Random? random,
  }) : _shaderCompiler = shaderCompiler,
       _fileSystem = fileSystem,
       _random = random ?? math.Random();

  final ShaderCompiler _shaderCompiler;
  final FileSystem _fileSystem;
  final Pool _compilationPool = Pool(4);
  final math.Random _random;

  late ShaderTarget _shaderTarget;
  bool _debugConfigured = false;

  /// Configure the output format of the shader compiler for a particular
  /// flutter device.
  void configureCompiler(TargetPlatform? platform, { required bool enableImpeller }) {
    switch (platform) {
      case TargetPlatform.ios:
        _shaderTarget = enableImpeller ? ShaderTarget.impelleriOS : ShaderTarget.sksl;
        break;
      case TargetPlatform.android_arm64:
      case TargetPlatform.android_x64:
      case TargetPlatform.android_x86:
      case TargetPlatform.android_arm:
      case TargetPlatform.android:
        _shaderTarget = enableImpeller ? ShaderTarget.impellerAndroid : ShaderTarget.sksl;
        break;
      case TargetPlatform.darwin:
      case TargetPlatform.linux_x64:
      case TargetPlatform.linux_arm64:
      case TargetPlatform.windows_x64:
      case TargetPlatform.fuchsia_arm64:
      case TargetPlatform.fuchsia_x64:
      case TargetPlatform.tester:
      case TargetPlatform.web_javascript:
        assert(!enableImpeller);
        _shaderTarget = ShaderTarget.sksl;
        break;
      case null:
        return;
    }
    _debugConfigured = true;
  }

  /// Recompile the input shader and return a devfs content that should be synced
  /// to the attached device in its place.
  Future<DevFSContent?> recompileShader(DevFSContent inputShader) async {
    assert(_debugConfigured);
    final File output = _fileSystem.systemTempDirectory.childFile('${_random.nextDouble()}.temp');
    late File inputFile;
    bool cleanupInput = false;
    Uint8List result;
    PoolResource? resource;
    try {
      resource = await _compilationPool.request();
      if (inputShader is DevFSFileContent) {
        inputFile = inputShader.file as File;
      } else {
        inputFile = _fileSystem.systemTempDirectory.childFile('${_random.nextDouble()}.temp');
        inputFile.writeAsBytesSync(await inputShader.contentsAsBytes());
        cleanupInput = true;
      }
      final bool success = await _shaderCompiler.compileShader(
        input: inputFile,
        outputPath: output.path,
        target: _shaderTarget,
        fatal: false,
      );
      if (!success) {
        return null;
      }
      result = output.readAsBytesSync();
    } finally {
      resource?.release();
      ErrorHandlingFileSystem.deleteIfExists(output);
      if (cleanupInput) {
        ErrorHandlingFileSystem.deleteIfExists(inputFile);
      }
    }
    return DevFSByteContent(result);
  }
}

/// A class the wraps the functionality of the Impeller shader compiler
/// impellerc.
class ShaderCompiler {
  ShaderCompiler({
    required ProcessManager processManager,
    required Logger logger,
    required FileSystem fileSystem,
    required Artifacts artifacts,
  }) : _processManager = processManager,
       _logger = logger,
       _fs = fileSystem,
       _artifacts = artifacts;

  final ProcessManager _processManager;
  final Logger _logger;
  final FileSystem _fs;
  final Artifacts _artifacts;

  /// The [Source] inputs that targets using this should depend on.
  ///
  /// See [Target.inputs].
  static const List<Source> inputs = <Source>[
    Source.pattern('{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/shader_compiler.dart'),
    Source.hostArtifact(HostArtifact.impellerc),
  ];

  /// Calls impellerc, which transforms the [input] glsl shader into a
  /// platform specific shader at [outputPath].
  ///
  /// All parameters are required.
  ///
  /// If the shader compiler subprocess fails, it will print the stdout and
  /// stderr to the log and throw a [ShaderCompilerException]. Otherwise, it
  /// will return true.
  Future<bool> compileShader({
    required File input,
    required String outputPath,
    required ShaderTarget target,
    bool fatal = true,
  }) async {
    final File impellerc = _fs.file(
      _artifacts.getHostArtifact(HostArtifact.impellerc),
    );
    if (!impellerc.existsSync()) {
      throw ShaderCompilerException._(
        'The impellerc utility is missing at "${impellerc.path}". '
        'Run "flutter doctor".',
      );
    }

    final List<String> cmd = <String>[
      impellerc.path,
      target.target,
      '--iplr',
      '--sl=$outputPath',
      '--spirv=$outputPath.spirv',
      '--input=${input.path}',
      '--input-type=frag',
      '--include=${input.parent.path}',
    ];
    final Process impellercProcess = await _processManager.start(cmd);
    final int code = await impellercProcess.exitCode;
    if (code != 0) {
      final String stdout = await utf8.decodeStream(impellercProcess.stdout);
      final String stderr = await utf8.decodeStream(impellercProcess.stderr);
      _logger.printTrace(stdout);
      _logger.printError(stderr);
      if (fatal) {
        throw ShaderCompilerException._(
          'Shader compilation of "${input.path}" to "$outputPath" '
          'failed with exit code $code.\n'
          'impellerc stdout:\n$stdout\n'
          'impellerc stderr:\n$stderr',
        );
      }
      return false;
    }
    ErrorHandlingFileSystem.deleteIfExists(_fs.file('$outputPath.spirv'));
    return true;
  }
}

class ShaderCompilerException implements Exception {
  ShaderCompilerException._(this.message);

  final String message;

  @override
  String toString() => 'ShaderCompilerException: $message\n\n';
}
