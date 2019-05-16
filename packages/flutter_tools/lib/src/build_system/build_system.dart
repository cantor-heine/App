// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../base/file_system.dart';
import '../base/platform.dart';
import '../build_info.dart';
import '../cache.dart';
import '../convert.dart';
import '../globals.dart';
import 'targets.dart';

/// Return the name for the build mode, or "any" if null.
String getNameForBuildMode(BuildMode buildMode) {
  switch (buildMode) {
    case BuildMode.debug:
      return 'debug';
    case BuildMode.profile:
      return 'profile';
    case BuildMode.release:
      return 'relese';
    case BuildMode.dynamicProfile:
      return 'dynamic-profile';
    case BuildMode.dynamicRelease:
      return 'dynamic-release';
  }
  return 'any';
}

/// Returns the host folder name for a particular target platform.
String getHostFolderForTargetPlaltform(TargetPlatform targetPlatform) {
  switch (targetPlatform) {
    case TargetPlatform.android_arm:
    case TargetPlatform.android_arm64:
    case TargetPlatform.android_x64:
    case TargetPlatform.android_x86:
      return 'android';
    case TargetPlatform.ios:
      return 'ios';
    case TargetPlatform.darwin_x64:
      return 'macos';
    case TargetPlatform.linux_x64:
      return 'linux';
    case TargetPlatform.windows_x64:
      return 'windows';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
    case TargetPlatform.web:
      return 'web';
    case TargetPlatform.tester:
      throw UnsupportedError('tester is not a support platform for building.');
  }
  return 'any';
}


/// An input function produces a list of additional input files for an
/// environment.
typedef InputFunction = List<FileSystemEntity> Function(Environment environment);

/// An exception thrown when a rule declares an output that was not produced
/// by the invocation.
class MissingOutputException implements Exception {
  const MissingOutputException(this.file, this.target);

  /// The file we expected to find.
  final File file;

  /// The name of the target this file should have been output from.
  final String target;

  @override
  String toString() {
    return '${file.path} was declared as an output, but was not generated by '
    'the invocation. Check the definition of target:$target for errors';
  }
}

/// Finds the locations of all dart files within the project.
///
/// This does not attempt to determine if a file is used or imported, so it
/// may otherwise report more files than strictly necessary.
List<FileSystemEntity> listDartSources(
  Environment environment,
) {
  return environment.projectDir
    .childDirectory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'))
    .toList();
}

/// The function signature of a build target which can be invoked to perform
/// the underlying task.
typedef BuildInvocation = Future<void> Function(
  List<FileSystemEntity> inputs,
  Environment environment,
);

/// A Target describes a single step during a flutter build.
///
/// The target inputs are required to be files discoverable via a combination
/// of at least one of the magic ambient value and zero or more magic local
/// values.
///
/// To determine if a target needs to be executed, the [BuildSystem] performs a
/// timestamp analysis of the evaluated input files. If any date after an output
/// stamp or are otherwise missing, the target is re-run.
///
/// Because the set of inputs or outputs might change based on the invocation,
/// each target stores a JSON file containing the input timestamps and named
/// after the target invocation joined with target platform and mode.
/// The modified time of the file stores the tool invocation time, and the
/// output files are stored as well to detect deleted/modified files.
///
///
///  file: `example_target.debug.android_arm64`
///
/// {
///   "build_number": 12345,
///   "inputs": [
///      ["absolute/path/foo", 123456],
///      ["absolute/path/bar", 123456],
///      ...
///    ],
///    "outputs": [
///      "absolte/path/fizz"
///    ]
/// }
///
/// We don't re-run if the target or mode change because we expect that these
/// invocations will produce different outputs. For example, if I separately run
/// a target which produces the gen_snapshot output for `android_arm` and
/// `android_arm64`, this should not produce files which overwrite eachother.
/// This is not currently the case and will need to be adjusted.
///
/// For more information on the `build_number` field, see
/// [Environment.buildNumber].
class Target {
  const Target({
    @required this.name,
    @required this.inputs,
    @required this.outputs,
    @required this.invocation,
    this.dependencies,
    this.platforms,
    this.modes,
    this.phony = false,
  });

  final String name;
  final List<Target> dependencies;
  final List<dynamic> inputs;
  final List<dynamic> outputs;
  final BuildInvocation invocation;
  final bool phony;

  /// The target platform this target supports.
  ///
  /// If left empty, this supports all platforms.
  final List<TargetPlatform> platforms;

  /// The build modes this target supports.
  ///
  /// If left empty, this supports all modes.
  final List<BuildMode> modes;

  /// Check if we can skip the target invocation.
  bool canSkipInvocation(List<FileSystemEntity> inputs, Environment environment) {
    // A phony target can never be skipped. This might be necessary if we're
    // not aware of its inputs or outputs, or they are tracked by a separate
    //  system.
    if (phony) {
      return false;
    }
    final File stamp = _findStampFile(name, environment);

    /// Case 1: The stamp file does not exist, then we cannot skip the target.
    if (!stamp.existsSync()) {
      return false;
    }
    final FileStat stampStat = stamp.statSync();
    final Map<String, Object> values = json.decode(stamp.readAsStringSync());
    final Map<String, int> inputStamps = <String, int>{};
    for (List<Object> pair in values['inputs']) {
      assert(pair.length == 2);
      inputStamps[pair.first] = pair.last;
    }
    // Case 2: Files were removed.
    if (inputs.length != inputStamps.length) {
      return false;
    }

    // Check that the current input files have not been changed since the last
    // invocation.
    for (File inputFile in inputs) {
      assert(inputFile.existsSync());
      final String absolutePath = inputFile.absolute.path;
      final int previousTimestamp = inputStamps[absolutePath];
      // Case 3: A new input was added.
      if (previousTimestamp == null) {
        return false;
      }
      final int currentTimestamp =
          inputFile.statSync().modified.millisecondsSinceEpoch;
      // Case 4: timestamps are not identical.
      if (previousTimestamp != currentTimestamp) {
        return false;
      }
    }

    // Check that the last set of output files have no been changed since the
    // last invocation. While the set of output files can vary based on inputs,
    // it should be safe to skip if none of the inputs changed.
    for (String absoluteOutputPath in values['outputs']) {
      final FileStat fileStat = fs.statSync(absoluteOutputPath);
      // Case 5: output was deleted for some reason.
      if (fileStat == null) {
        return false;
      }
      // Case 6: File was modified after stamp file was written.
      if (fileStat.modified.isAfter(stampStat.modified)) {
        return false;
      }
    }
    // Once we've reached this point, it should be safe to skip the step.
    return true;
  }

  void writeStamp(
    List<FileSystemEntity> inputs,
    List<FileSystemEntity> outputs,
    Environment environment,
  ) {
    if (phony) {
      return;
    }
    final File stamp = _findStampFile(name, environment);
    if (!stamp.existsSync()) {
      stamp.createSync(recursive: true);
    }
    final List<List<Object>> inputStamps = <List<Object>>[];
    for (FileSystemEntity input in inputs) {
      if (!input.existsSync())  {
        throw Exception('$name: Did not find expected input ${input.path}');
      }
      inputStamps.add(<Object>[
        input.absolute.path,
        input.statSync().modified.millisecondsSinceEpoch,
      ]);
    }
    final List<String> outputStamps = <String>[];
    for (FileSystemEntity output in outputs) {
      if (!output.existsSync()) {
        throw Exception('$name: Did not produce expected output ${output.path}');
      }
      outputStamps.add(output.absolute.path);
    }
    final Map<String, Object> result = <String, Object>{
      'inputs': inputStamps,
      'outputs': outputStamps,
    };
    stamp.writeAsStringSync(json.encode(result));
  }

  /// Resolve the set of input patterns and functions into a concrete list of
  /// files.
  List<FileSystemEntity> resolveInputs(
    Environment environment,
  ) {
    return _resolveConfiguration(inputs, environment);
  }

  /// Find the current set of declared outputs, including wildcard directories.
  List<FileSystemEntity> resolveOutputs(
    Environment environment,
  ) {
    return _resolveConfiguration(outputs, environment);
  }

  /// Convert the target to a JSON structure appropriate for consumption by
  /// external systems.
  ///
  /// This requires an environment variable to resolve the paths of inputs
  /// and outputs.
  Map<String, Object> toJson(Environment environment) {
    return <String, Object>{
      'name': name,
      'phony': phony,
      'dependencies': dependencies.map((Target target) => target.name).toList(),
      'inputs': resolveInputs(environment).map((FileSystemEntity file) => file.absolute.path).toList(),
      'outputs': resolveOutputs(environment).map((FileSystemEntity file) => file.absolute.path).toList(),
    };
  }

  /// Locate the stamp file for a particular target `name` and `environment`.
  static File _findStampFile(String name, Environment environment) {
    final String platform = getNameForTargetPlatform(environment.targetPlatform);
    final String mode = getNameForBuildMode(environment.buildMode);
    final String fileName = '$name.$mode.$platform';
    return environment.stampDir.childFile(fileName);
  }

  static List<FileSystemEntity> _resolveConfiguration(List<dynamic> config, Environment environment) {
    // Perform some simple substitutions to produce a list of files that
    // are considered build inputs or outputs.
    final List<FileSystemEntity> files = <FileSystemEntity>[];
    for (dynamic rawInput in config)  {
      if (rawInput is String) {
        // First, perform substituion of the environmental values and then
        // of the local values.
        rawInput = rawInput
          .replaceAll('{PROJECT_DIR}', environment.projectDir.absolute.path)
          .replaceAll('{BUILD_DIR}', environment.buildDir.absolute.path)
          .replaceAll('{CACHE_DIR}', environment.cacheDir.absolute.path)
          .replaceAll('{COPY_DIR}', environment.copyDir.absolute.path)
          .replaceAll('{platform}', getNameForTargetPlatform(environment.targetPlatform))
          .replaceAll('{mode}', getNameForBuildMode(environment.buildMode));
        // On windows, swap `/` to `\`.
        if (platform.isWindows) {
          rawInput = rawInput.replaceAll(r'/', r'\');
        }
        if (rawInput.endsWith(platform.pathSeparator)) {
          files.add(fs.directory(fs.path.normalize(rawInput)));
        } else {
          files.add(fs.file(fs.path.normalize(rawInput)));
        }
      } else if (rawInput is InputFunction) {
        files.addAll(rawInput(environment));
      } else {
        assert(false);
      }
    }
    return files;
  }
}

/// The [Environment] contains specical paths configured by the user.
///
/// These are defined by a top level configuration or build arguments
/// passed to the flutter tool. The intention is that  it makes it easier
/// to integrate it into existing arbitrary build systems, while keeping
/// the build backwards compatible.
///
/// # Magic Ambient Values:
///
/// ## PROJECT_DIR
///
///   The root of the flutter project where a pubspec and dart files can be
///   found.
///
///   This value is computed from the location of the relevant pubspec. Most
///   other ambient value defaults are defined relative to this directory.
///
/// ## BUILD_DIR
///
///   the root of the output directory where build step intermediates and
///   products are written.
///
///   Defaults to {PROJECT_DIR}/build/
///
/// ## STAMP_DIR
///
/// The root of the directory where timestamp output is stored. Defaults to
/// {PROJECT_DIR}/.stamp/
///
/// # Magic local values
///
/// These are defined by the particular invocation of the target itself.
///
/// ## platform
///
/// The current platform the target is being executed for. Certain targets do
/// not require a target at all, in which case this value will be null and
/// substitution will fail.
///
/// ## build_mod
///
/// The current build mode the target is being executed for, one of `release`,
/// `debug`, and `profile`. Defaults to `debug` if not specified.
///
/// # Flavors
///
/// TBD based on understanding how these work now.
class Environment {
  /// Create a new [Environment] object.
  ///
  /// Only [projectDir] is required. The remaining environment locations have
  /// defaults based on it.
  ///
  /// If [targetPlatform] and/or [buildMode] are not defined, they will often
  /// default to `any`.
  factory Environment({
    @required Directory projectDir,
    Directory stampDir,
    Directory buildDir,
    Directory cacheDir,
    Directory copyDir,
    TargetPlatform targetPlatform,
    BuildMode buildMode,
  }) {
    assert(projectDir != null);
    return Environment._(
      projectDir: projectDir,
      stampDir: stampDir ?? projectDir.childDirectory('build'),
      buildDir: buildDir ?? projectDir.childDirectory('build'),
      cacheDir: cacheDir ?? Cache.instance.getCacheArtifacts(),
      copyDir: copyDir ?? projectDir
        .childDirectory(getHostFolderForTargetPlaltform(targetPlatform))
        .childDirectory('flutter'),
      targetPlatform: targetPlatform,
      buildMode: buildMode,
    );
  }

  Environment._({
    @required this.projectDir,
    @required this.stampDir,
    @required this.buildDir,
    @required this.cacheDir,
    @required this.copyDir,
    @required this.targetPlatform,
    @required this.buildMode,
  });

  /// The `PROJECT_DIR` magic environment varaible.
  final Directory projectDir;

  /// The `STAMP_DIR` magic environment variable.
  ///
  /// Defaults to `{PROJECT_ROOT}/build`.
  final Directory stampDir;

  /// The `BUILD_DIR` magic environment variable.
  ///
  /// Defaults to `{PROJECT_ROOT}/build`.
  final Directory buildDir;

  /// The `CACHE_DIR` magic environment variable.
  ///
  /// Defaults to `{FLUTTER_ROOT}/bin/cache`.
  final Directory cacheDir;

  /// The `COPY_DIR` magic environment variable.
  ///
  /// Defaults to `{PROJECT_ROOT}/{host_folder}/flutter`
  final Directory copyDir;

  /// The currently selected build mode.
  final BuildMode buildMode;

  /// The current target platform, or `null` if none.
  final TargetPlatform targetPlatform;
}

class BuildSystem {
  const BuildSystem([this.targets = allTargets]);

  final List<Target> targets;

  /// Build the target `name` and all of its dependencies.
  Future<void> build(
    String name,
    Environment environment,
  ) async {
    // Initialize any destination directories that don't currently exist.
    if (!environment.cacheDir.existsSync()) {
      environment.cacheDir.createSync(recursive: true);
    }
    if (!environment.copyDir.existsSync()) {
      environment.copyDir.createSync(recursive: true);
    }

    // Compute the required order of targets.
    final List<Target> ordered = _computeTargetOrder(targets, name, environment);

    // Visit each target and check if its stamp is up to date. If so,
    // we can safely skip it. Otherwise, we must invoke the associated rule.
    for (Target target in ordered) {
      final List<FileSystemEntity> inputs = target.resolveInputs(environment);
      if (target.canSkipInvocation(inputs, environment)) {
        printTrace('Skipping target: ${target.name}');
        continue;
      }
      printTrace('${target.name}: Starting');
      await target.invocation(inputs, environment);

      printTrace('${target.name}: Complete');
      final List<FileSystemEntity> outputs = target.resolveOutputs(environment);
      // Write the stamp file containing the timestamps of all output, input
      // files, as well as a build number.
      target.writeStamp(inputs, outputs, environment);
    }
  }

  /// Describe the target `name` and all of its dependencies.
  List<Map<String, Object>> describe(
    String name,
    Environment environment,
  ) {
    // Compute the required order of targets.
    final List<Target> ordered = _computeTargetOrder(targets, name, environment);
    final List<Map<String, Object>> result = <Map<String, Object>>[];
    for (Target target in ordered) {
      result.add(target.toJson(environment));
    }
    return result;
  }

  static List<Target> _computeTargetOrder(List<Target> allTargets, String name, Environment environment) {
    /// Step 1: Find the target we have been asked to invoke.
    final Target target = allTargets.firstWhere((Target target) => target.name  == name, orElse: () => null);

    /// Error case 1: The target name did not exist. In the interest of brevity,
    /// we do nothing, but to be complete we should print an error which fully
    /// describes the error along with targets that are closest in spelling.
    /// Furthermore, we should log this error in analytics to track if it is
    /// being hit frequently.
    if (target == null) {
      throw Exception('No registered target named $name.');
    }

    // Step 2: Flatten the dependencies into a set of targets to invoke
    // in order. This is done performing a depth-first search and adding
    // a target to the resulting order if it either has no dependencies,
    // or if all dependencies have already been added. We take advantage
    // of the fact that the literal [Set] provides an ordered [LinkedHashSet].
    final Set<Target> ordered = <Target>{};
    final Set<Target> visited = <Target>{};
    void orderTargets(Target current) {
      // If we've already visited this target, returning so we do not
      // repeat ourselves in the resulting order
      if (visited.contains(current)) {
        return;
      }
      visited.add(current);
      // If the target has no dependencies, we can add it the current order.
      if (current.dependencies.isEmpty) {
        ordered.add(current);
        return;
      }
      // Visit each dependency recursively, and when complete add this
      // target to the order.
      current.dependencies.forEach(orderTargets);
      // We can't hit the case where we visit a target recursively, right?
      // that would trip visited, but we need to make sure that this case
      // is covered via testing.
      ordered.add(current);
    }
    orderTargets(target);
    return ordered.toList();
  }
}
