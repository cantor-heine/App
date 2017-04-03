// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import 'base/common.dart';
import 'base/clock.dart';
import 'base/context.dart';
import 'base/io.dart';
import 'base/process.dart';
import 'base/process_manager.dart';
import 'cache.dart';
import 'globals.dart';

final Set<String> kKnownBranchNames = new Set<String>.from(<String>[
  'master',
  'alpha',
  'hackathon',
  'codelab',
  'beta'
]);

class FlutterVersion {
  @visibleForTesting
  FlutterVersion() {
    _channel = _runGit('git rev-parse --abbrev-ref --symbolic @{u}');

    final int slash = _channel.indexOf('/');
    if (slash != -1) {
      final String remote = _channel.substring(0, slash);
      _repositoryUrl = _runGit('git ls-remote --get-url $remote');
      _channel = _channel.substring(slash + 1);
    } else if (_channel.isEmpty) {
      _channel = 'unknown';
    }

    _frameworkRevision = _runGit('git log -n 1 --pretty=format:%H');
    _frameworkAge = _runGit('git log -n 1 --pretty=format:%ar');
  }

  String _repositoryUrl;
  String get repositoryUrl => _repositoryUrl;

  String _channel;
  /// `master`, `alpha`, `hackathon`, ...
  String get channel => _channel;

  String _frameworkRevision;
  String get frameworkRevision => _frameworkRevision;
  String get frameworkRevisionShort => _shortGitRevision(frameworkRevision);

  String _frameworkAge;
  String get frameworkAge => _frameworkAge;

  String get frameworkDate => frameworkCommitDate;

  String get dartSdkVersion => Cache.dartSdkVersion.split(' ')[0];

  String get engineRevision => Cache.engineRevision;
  String get engineRevisionShort => _shortGitRevision(engineRevision);

  String _runGit(String command) => runSync(command.split(' '), workingDirectory: Cache.flutterRoot);

  @override
  String toString() {
    final String flutterText = 'Flutter • channel $channel • ${repositoryUrl == null ? 'unknown source' : repositoryUrl}';
    final String frameworkText = 'Framework • revision $frameworkRevisionShort ($frameworkAge) • $frameworkCommitDate';
    final String engineText = 'Engine • revision $engineRevisionShort';
    final String toolsText = 'Tools • Dart $dartSdkVersion';

    // Flutter • channel master • https://github.com/flutter/flutter.git
    // Framework • revision 2259c59be8 • 19 minutes ago • 2016-08-15 22:51:40
    // Engine • revision fe509b0d96
    // Tools • Dart 1.19.0-dev.5.0

    return '$flutterText\n$frameworkText\n$engineText\n$toolsText';
  }

  /// A date String describing the last framework commit.
  String get frameworkCommitDate => _latestGitCommitDate();

  static String _latestGitCommitDate([String branch]) {
    final List<String> args = <String>['git', 'log'];

    if (branch != null) {
      args.add(branch);
    }

    args.addAll(<String>['-n', '1', '--pretty=format:%ad', '--date=format:%Y-%m-%d %H:%M:%S']);
    return _runSync(args, Cache.flutterRoot, lenient: false);
  }

  /// The name of the temporary git remote used to check for the latest
  /// available Flutter framework version.
  ///
  /// In the absence of bugs and crashes a Flutter developer should never see
  /// this remote appear in their `git remote` list, but also if it happens to
  /// persist we do the proper clean-up for extra robustness.
  static const String _kVersionCheckRemote = '__flutter_version_check__';

  /// The date of the latest framework commit in the remote repository.
  ///
  /// Throws [ToolExit] if a git command fails, for example, when the remote git
  /// repository is not reachable due to a network issue.
  static Future<String> fetchRemoteFrameworkCommitDate() async {
    await _removeVersionCheckRemoteIfExists();
    try {
      await _run(<String>[
        'git',
        'remote',
        'add',
        _kVersionCheckRemote,
        'https://github.com/flutter/flutter.git',
      ], Cache.flutterRoot, lenient: false);
      await _run(<String>['git', 'fetch', _kVersionCheckRemote, 'master'], Cache.flutterRoot, lenient: false);
      return _latestGitCommitDate('$_kVersionCheckRemote/master');
    } finally {
      await _removeVersionCheckRemoteIfExists();
    }
  }

  static Future<Null> _removeVersionCheckRemoteIfExists() async {
    final List<String> remotes = (await _run(<String>['git', 'remote'], Cache.flutterRoot, lenient: false))
        .split('\n')
        .map((String name) => name.trim())  // to account for OS-specific line-breaks
        .toList();
    if (remotes.contains(_kVersionCheckRemote)) {
      await _run(<String>['git', 'remote', 'remove', _kVersionCheckRemote], Cache.flutterRoot, lenient: false);
    }
  }

  static FlutterVersion get instance => context.putIfAbsent(FlutterVersion, () => new FlutterVersion());

  /// Return a short string for the version (`alpha/a76bc8e22b`).
  static String getVersionString({ bool whitelistBranchName: false }) {
    final String cwd = Cache.flutterRoot;

    String commit = _shortGitRevision(_runSync(<String>['git', 'rev-parse', 'HEAD'], cwd));
    commit = commit.isEmpty ? 'unknown' : commit;

    String branch = _runSync(<String>['git', 'rev-parse', '--abbrev-ref', 'HEAD'], cwd);
    branch = branch == 'HEAD' ? 'master' : branch;

    if (whitelistBranchName || branch.isEmpty) {
      // Only return the branch names we know about; arbitrary branch names might contain PII.
      if (!kKnownBranchNames.contains(branch))
        branch = 'dev';
    }

    return '$branch/$commit';
  }

  /// We warn the user if the age of their Flutter installation is greater than
  /// this duration.
  @visibleForTesting
  static const Duration kVersionAgeConsideredUpToDate = const Duration(days: 4 * 7);

  /// The amount of time we wait before pinging the server to check for the
  /// availability of a newer version of Flutter.
  @visibleForTesting
  static const Duration kCheckAgeConsideredUpToDate = const Duration(days: 1);

  /// The prefix of the stamp file where we cache Flutter version check data.
  @visibleForTesting
  static const String kFlutterVersionCheckStampFile = 'flutter_version_check';

  /// Checks if the currently installed version of Flutter is up-to-date, and
  /// warns the user if it isn't.
  ///
  /// This function must run while [Cache.lock] is acquired because it reads and
  /// writes shared cache files.
  Future<Null> checkFlutterVersionFreshness() async {
    final DateTime localFrameworkCommitDate = DateTime.parse(frameworkCommitDate);
    final Duration frameworkAge = clock.now().difference(localFrameworkCommitDate);
    final bool installationSeemsOutdated = frameworkAge > kVersionAgeConsideredUpToDate;

    Future<bool> newerFrameworkVersionAvailable() async {
      final DateTime latestFlutterCommitDate = await _getLatestAvailableFlutterVersion();

      if (latestFlutterCommitDate == null)
        return false;

      return latestFlutterCommitDate.isAfter(localFrameworkCommitDate);
    }

    if (installationSeemsOutdated && await newerFrameworkVersionAvailable()) {
      printStatus(versionOutOfDateMessage(frameworkAge), emphasis: true);
    }
  }

  @visibleForTesting
  static String versionOutOfDateMessage(Duration frameworkAge) {
    String warning = 'WARNING: your installation of Flutter is ${frameworkAge.inDays} days old.';
    // Append enough spaces to match the message box width.
    warning += ' ' * (74 - warning.length);

    return '''
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║ $warning ║
  ║                                                                            ║
  ║ To update to the latest version, run flutter upgrade.                      ║
  ╚════════════════════════════════════════════════════════════════════════════╝
''';
  }

  /// Gets the release date of the latest available Flutter version.
  ///
  /// This method sends a server request if it's been more than
  /// [kCheckAgeConsideredUpToDate] since the last version check.
  ///
  /// Returns `null` if the cached version is out-of-date or missing, and we are
  /// unable to reach the server to get the latest version.
  Future<DateTime> _getLatestAvailableFlutterVersion() async {
    Cache.checkLockAcquired();
    const JsonEncoder kPrettyJsonEncoder = const JsonEncoder.withIndent('  ');
    final String versionCheckStamp = Cache.instance.getStampFor(kFlutterVersionCheckStampFile);

    if (versionCheckStamp != null) {
      final Map<String, String> data = JSON.decode(versionCheckStamp);
      final DateTime lastTimeVersionWasChecked = DateTime.parse(data['lastTimeVersionWasChecked']);
      final Duration timeSinceLastCheck = clock.now().difference(lastTimeVersionWasChecked);

      // Don't ping the server too often. Return cached value if it's fresh.
      if (timeSinceLastCheck < kCheckAgeConsideredUpToDate) {
        return DateTime.parse(data['lastKnownRemoteVersion']);
      }
    }

    // Cache is empty or it's been a while since the last server ping. Ping the server.
    try {
      final DateTime remoteFrameworkCommitDate = DateTime.parse(await FlutterVersion.fetchRemoteFrameworkCommitDate());
      Cache.instance.setStampFor(kFlutterVersionCheckStampFile, kPrettyJsonEncoder.convert(<String, String>{
        'lastTimeVersionWasChecked': '${clock.now()}',
        'lastKnownRemoteVersion': '$remoteFrameworkCommitDate',
      }));
      return remoteFrameworkCommitDate;
    } on ToolExit catch(error) {
      // This happens when any of the git commands fails, which can happen when
      // there's no Internet connectivity. Remote version check is best effort
      // only. We do not prevent the command from running when it fails.
      printTrace('Failed to check Flutter version in the remote repository: ${error.message}');
      return null;
    }
  }
}

/// Runs [command] and returns the standard output as a string.
///
/// If [lenient] is `true` and the command fails, returns an empty string.
/// Otherwise, throws a [ToolExit] exception.
String _runSync(List<String> command, String cwd, {bool lenient: true}) {
  final ProcessResult results = processManager.runSync(command, workingDirectory: cwd);

  if (results.exitCode == 0)
    return results.stdout.trim();

  if (!lenient) {
    throwToolExit(
      'Command exited with code ${results.exitCode}: ${command.join(' ')}\n'
      'Standard error: ${results.stderr}',
      exitCode: results.exitCode,
    );
  }

  return '';
}

/// Runs [command] and returns the standard output as a string.
///
/// If [lenient] is `true` and the command fails, returns an empty string.
/// Otherwise, throws a [ToolExit] exception.
Future<String> _run(List<String> command, String cwd, {bool lenient: true}) async {
  final ProcessResult results = await processManager.run(command, workingDirectory: cwd);

  if (results.exitCode == 0)
    return results.stdout.trim();

  if (!lenient) {
    throwToolExit(
        'Command exited with code ${results.exitCode}: ${command.join(' ')}\n'
            'Standard error: ${results.stderr}',
        exitCode: results.exitCode,
    );
  }

  return '';
}

String _shortGitRevision(String revision) {
  if (revision == null)
    return '';
  return revision.length > 10 ? revision.substring(0, 10) : revision;
}
