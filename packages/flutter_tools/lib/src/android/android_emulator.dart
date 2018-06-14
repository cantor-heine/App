// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' show ProcessResult;

import 'package:meta/meta.dart';

import '../android/android_sdk.dart';
import '../android/android_workflow.dart';
import '../base/file_system.dart';
import '../base/process_manager.dart';
import '../emulator.dart';
import 'android_sdk.dart';

class AndroidEmulators extends EmulatorDiscovery {
  @override
  bool get supportsPlatform => true;

  @override
  bool get canListAnything => androidWorkflow.canListEmulators;

  @override
  Future<List<Emulator>> get emulators async => getEmulatorAvds();
}

class AndroidEmulator extends Emulator {
  AndroidEmulator(String id, [this._properties])
      : super(id, _properties != null && _properties.isNotEmpty);

  Map<String, String> _properties;

  @override
  String get name => _prop('hw.device.name');

  @override
  String get manufacturer => _prop('hw.device.manufacturer');

  @override
  String get label => _properties['avd.ini.displayname'];

  String _prop(String name) => _properties != null ? _properties[name] : null;

  @override
  Future<void> launch() async {
    final Future<void> launchResult =
        processManager.run(<String>[getEmulatorPath(), '-avd', id])
            .then((ProcessResult runResult) {
              if (runResult.exitCode != 0) {
                throw '${runResult.stdout}\n${runResult.stderr}'.trimRight();
              }
            });
    // emulator continues running on a successful launch so if we
    // haven't quit within 3 seconds we assume that's a success and just
    // return.
    return Future.any<void>(<Future<void>>[
      launchResult,
      new Future<void>.delayed(const Duration(seconds: 3))
    ]);
  }
}

/// Return the list of available emulator AVDs.
List<AndroidEmulator> getEmulatorAvds() {
  final String emulatorPath = getEmulatorPath(androidSdk);
  if (emulatorPath == null) {
    return <AndroidEmulator>[];
  }

  final String listAvdsOutput = processManager.runSync(<String>[emulatorPath, '-list-avds']).stdout;

  final List<AndroidEmulator> emulators = <AndroidEmulator>[];
  if (listAvdsOutput != null) {
    extractEmulatorAvdInfo(listAvdsOutput, emulators);
  }
  return emulators;
}

/// Parse the given `emulator -list-avds` output in [text], and fill out the given list
/// of emulators by reading information from the relevant ini files.
void extractEmulatorAvdInfo(String text, List<AndroidEmulator> emulators) {
  for (String id in text.trim().split('\n').where((String l) => l != '')) {
    emulators.add(_createEmulator(id));
  }
}

AndroidEmulator _createEmulator(String id) {
  id = id.trim();
  final File iniFile = fs.file(fs.path.join(getAvdPath(), '$id.ini'));
  if (iniFile.existsSync()) {
    final Map<String, String> ini = parseIniLines(iniFile.readAsLinesSync());
    if (ini['path'] != null) {
      final File configFile = fs.file(fs.path.join(ini['path'], 'config.ini'));
      if (configFile.existsSync()) {
        final Map<String, String> properties =
            parseIniLines(configFile.readAsLinesSync());
        return new AndroidEmulator(id, properties);
      }
    }
  }

  return new AndroidEmulator(id);
}

@visibleForTesting
Map<String, String> parseIniLines(List<String> contents) {
  final Map<String, String> results = <String, String>{};

  final Iterable<List<String>> properties = contents
      .map((String l) => l.trim())
      // Strip blank lines/comments
      .where((String l) => l != '' && !l.startsWith('#'))
      // Discard anything that isn't simple name=value
      .where((String l) => l.contains('='))
      // Split into name/value
      .map((String l) => l.split('='));

  for (List<String> property in properties) {
    results[property[0].trim()] = property[1].trim();
  }

  return results;
}
