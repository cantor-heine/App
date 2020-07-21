// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as path;

import 'base_code_gen.dart';
import 'key_data.dart';
import 'utils.dart';


/// Generates the keyboard_keys.dart and keyboard_maps.dart files, based on the
/// information in the key data structure given to it.
class MacOsCodeGenerator extends BaseCodeGenerator {
  MacOsCodeGenerator(KeyData keyData) : super(keyData);

  /// This generates the map of macOS key codes to physical keys.
  String get _macOsScanCodeMap {
    final StringBuffer macOsScanCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.macOsScanCode != null) {
        macOsScanCodeMap.writeln('  { ${toHex(entry.macOsScanCode)}, ${toHex(entry.usbHidCode)} },    // ${entry.constantName}');
      }
    }
    return macOsScanCodeMap.toString().trimRight();
  }

  /// This generates the map of macOS number pad key codes to logical keys.
  String get _macOsNumpadMap {
    final StringBuffer macOsNumPadMap = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.macOsScanCode != null) {
        macOsNumPadMap.writeln('  { ${toHex(entry.macOsScanCode)}, ${toHex(entry.flutterId, digits: 10)} },    // ${entry.constantName}');
      }
    }
    return macOsNumPadMap.toString().trimRight();
  }

  String get _macOsFunctionKeyMap {
    final StringBuffer macOsFunctionKeyMap = StringBuffer();
    for (final Key entry in functionKeyData) {
      if (entry.macOsScanCode != null) {
        macOsFunctionKeyMap.writeln('  { ${toHex(entry.macOsScanCode)}, ${toHex(entry.flutterId, digits: 10)} },    // ${entry.constantName}');
      }
    }
    return macOsFunctionKeyMap.toString().trimRight();
  }

  @override
  String get templatePath => path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data', 'keyboard_map_darwin_cc.tmpl');

  @override
  Map<String, String> mappings() {
    return <String, String>{
      'MACOS_SCAN_CODE_MAP': _macOsScanCodeMap,
      'MACOS_NUMPAD_MAP': _macOsNumpadMap,
      'MACOS_FUNCTION_KEY_MAP': _macOsFunctionKeyMap,
    };
  }
}
