// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as path;

import 'key_data.dart';
import 'utils.dart';

String wrapDartDoc(String source) {
  return wrapString(source, prefix: '  /// ');
}

/// Generates the keyboard_keys.dart and keyboard_maps.dart files, based on the
/// information in the key data structure given to it.
class DartCodeGenerator {
  DartCodeGenerator(this.keyData);

  /// Gets the generated definitions of PhysicalKeyboardKeys.
  String get physicalDefinitions {
    final StringBuffer definitions = StringBuffer();
    for (final Key entry in keyData.data) {
      final String firstComment = wrapDartDoc('Represents the location of the '
        '"${entry.commentName}" key on a generalized keyboard.');
      final String otherComments = wrapDartDoc('See the function '
        '[RawKeyEvent.physicalKey] for more information.');
      definitions.write('''

$firstComment  ///
$otherComments  static const PhysicalKeyboardKey ${entry.constantName} = PhysicalKeyboardKey(${toHex(entry.usbHidCode, digits: 8)}, debugName: kReleaseMode ? null : '${entry.commentName}');
''');
    }
    return definitions.toString();
  }

  /// Gets the generated definitions of LogicalKeyboardKeys.
  String get logicalDefinitions {
    String escapeLabel(String label) => label.contains("'") ? 'r"$label"' : "r'$label'";
    final StringBuffer definitions = StringBuffer();
    void printKey(int flutterId, String keyLabel, String constantName, String commentName, {String otherComments}) {
      final String firstComment = wrapDartDoc('Represents the logical "$commentName" key on the keyboard.');
      otherComments ??= wrapDartDoc('See the function [RawKeyEvent.logicalKey] for more information.');
      if (keyLabel == null) {
        definitions.write('''

$firstComment  ///
$otherComments  static const LogicalKeyboardKey $constantName = LogicalKeyboardKey(${toHex(flutterId, digits: 11)}, debugName: kReleaseMode ? null : '$commentName');
''');
      } else {
        definitions.write('''

$firstComment  ///
$otherComments  static const LogicalKeyboardKey $constantName = LogicalKeyboardKey(${toHex(flutterId, digits: 11)}, keyLabel: ${escapeLabel(keyLabel)}, debugName: kReleaseMode ? null : '$commentName');
''');
      }
    }

    for (final Key entry in keyData.data) {
      printKey(
        entry.flutterId,
        entry.keyLabel,
        entry.constantName,
        entry.commentName,
      );
    }
    for (final String name in Key.synonyms.keys) {
      // Use the first item in the synonyms as a template for the ID to use.
      // It won't end up being the same value because it'll be in the pseudo-key
      // plane.
      final Key entry = keyData.data.firstWhere((Key item) => item.name == Key.synonyms[name][0]);
      final Set<String> unionNames = Key.synonyms[name].map<String>((dynamic name) {
        return upperCamelToLowerCamel(name as String);
      }).toSet();
      printKey(Key.synonymPlane | entry.flutterId, entry.keyLabel, name, Key.getCommentName(name),
          otherComments: wrapDartDoc('This key represents the union of the keys '
              '$unionNames when comparing keys. This key will never be generated '
              'directly, its main use is in defining key maps.'));
    }
    return definitions.toString();
  }

  String get logicalSynonyms {
    final StringBuffer synonyms = StringBuffer();
    for (final String name in Key.synonyms.keys) {
      for (final String synonym in Key.synonyms[name].cast<String>()) {
        final String keyName = upperCamelToLowerCamel(synonym);
        synonyms.writeln('    $keyName: $name,');
      }
    }
    return synonyms.toString();
  }

  List<Key> get numpadKeyData {
    return keyData.data.where((Key entry) {
      return entry.constantName.startsWith('numpad') && entry.keyLabel != null;
    }).toList();
  }

  List<Key> get functionKeyData {
    final RegExp functionKeyRe = RegExp(r'^f[0-9]+$');
    return keyData.data.where((Key entry) {
      return functionKeyRe.hasMatch(entry.constantName);
    }).toList();
  }

  /// This generates the map of USB HID codes to physical keys.
  String get predefinedHidCodeMap {
    final StringBuffer scanCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      scanCodeMap.writeln('    ${toHex(entry.usbHidCode)}: ${entry.constantName},');
    }
    return scanCodeMap.toString().trimRight();
  }

  /// This generates the map of Flutter key codes to logical keys.
  String get predefinedKeyCodeMap {
    final StringBuffer keyCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      keyCodeMap.writeln('    ${toHex(entry.flutterId, digits: 10)}: ${entry.constantName},');
    }
    for (final String entry in Key.synonyms.keys) {
      // Use the first item in the synonyms as a template for the ID to use.
      // It won't end up being the same value because it'll be in the pseudo-key
      // plane.
      final Key primaryKey = keyData.data.firstWhere((Key item) {
        return item.name == Key.synonyms[entry][0];
      }, orElse: () => null);
      assert(primaryKey != null);
      keyCodeMap.writeln('    ${toHex(Key.synonymPlane | primaryKey.flutterId, digits: 10)}: $entry,');
    }
    return keyCodeMap.toString().trimRight();
  }

  /// This generates the map of GLFW number pad key codes to logical keys.
  String get glfwNumpadMap {
    final StringBuffer glfwNumpadMap = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.glfwKeyCodes != null) {
        for (final int code in entry.glfwKeyCodes.cast<int>()) {
          glfwNumpadMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return glfwNumpadMap.toString().trimRight();
  }

  /// This generates the map of GLFW key codes to logical keys.
  String get glfwKeyCodeMap {
    final StringBuffer glfwKeyCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.glfwKeyCodes != null) {
        for (final int code in entry.glfwKeyCodes.cast<int>()) {
          glfwKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return glfwKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of GTK number pad key codes to logical keys.
  String get gtkNumpadMap {
    final StringBuffer gtkNumpadMap = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.gtkKeyCodes != null) {
        for (final int code in entry.gtkKeyCodes.cast<int>()) {
          gtkNumpadMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return gtkNumpadMap.toString().trimRight();
  }

  /// This generates the map of GTK key codes to logical keys.
  String get gtkKeyCodeMap {
    final StringBuffer gtkKeyCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.gtkKeyCodes != null) {
        for (final int code in entry.gtkKeyCodes.cast<int>()) {
          gtkKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return gtkKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of XKB USB HID codes to physical keys.
  String get xkbScanCodeMap {
    final StringBuffer xkbScanCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.xKbScanCode != null) {
        xkbScanCodeMap.writeln('  ${toHex(entry.xKbScanCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return xkbScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Android key codes to logical keys.
  String get androidKeyCodeMap {
    final StringBuffer androidKeyCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.androidKeyCodes != null) {
        for (final int code in entry.androidKeyCodes.cast<int>()) {
          androidKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return androidKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of Android number pad key codes to logical keys.
  String get androidNumpadMap {
    final StringBuffer androidKeyCodeMap = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.androidKeyCodes != null) {
        for (final int code in entry.androidKeyCodes.cast<int>()) {
          androidKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return androidKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of Android scan codes to physical keys.
  String get androidScanCodeMap {
    final StringBuffer androidScanCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.androidScanCodes != null) {
        for (final int code in entry.androidScanCodes.cast<int>()) {
          androidScanCodeMap.writeln('  $code: PhysicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return androidScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Windows scan codes to physical keys.
  String get windowsScanCodeMap {
    final StringBuffer windowsScanCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.windowsScanCode != null) {
        windowsScanCodeMap.writeln('  ${toHex(entry.windowsScanCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return windowsScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Windows number pad key codes to logical keys.
  String get windowsNumpadMap {
    final StringBuffer windowsNumPadMap = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.windowsKeyCodes != null){
        for (final int code in entry.windowsKeyCodes) {
          windowsNumPadMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return windowsNumPadMap.toString().trimRight();
  }

  /// This generates the map of Windows key codes to logical keys.
  String get windowsKeyCodeMap {
    final StringBuffer windowsKeyCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.windowsKeyCodes != null) {
        for (final int code in entry.windowsKeyCodes) {
          windowsKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return windowsKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of macOS key codes to physical keys.
  String get macOsScanCodeMap {
    final StringBuffer macOsScanCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.macOsScanCode != null) {
        macOsScanCodeMap.writeln('  ${toHex(entry.macOsScanCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return macOsScanCodeMap.toString().trimRight();
  }

  /// This generates the map of macOS number pad key codes to logical keys.
  String get macOsNumpadMap {
    final StringBuffer macOsNumPadMap = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.macOsScanCode != null) {
        macOsNumPadMap.writeln('  ${toHex(entry.macOsScanCode)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return macOsNumPadMap.toString().trimRight();
  }

  String get macOsFunctionKeyMap {
    final StringBuffer macOsFunctionKeyMap = StringBuffer();
    for (final Key entry in functionKeyData) {
      if (entry.macOsScanCode != null) {
        macOsFunctionKeyMap.writeln('  ${toHex(entry.macOsScanCode)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return macOsFunctionKeyMap.toString().trimRight();
  }

  /// This generates the map of Fuchsia key codes to logical keys.
  String get fuchsiaKeyCodeMap {
    final StringBuffer fuchsiaKeyCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.usbHidCode != null) {
        fuchsiaKeyCodeMap.writeln('  ${toHex(entry.flutterId)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return fuchsiaKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of Fuchsia USB HID codes to physical keys.
  String get fuchsiaHidCodeMap {
    final StringBuffer fuchsiaScanCodeMap = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.usbHidCode != null) {
        fuchsiaScanCodeMap.writeln('  ${toHex(entry.usbHidCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return fuchsiaScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Web KeyboardEvent codes to logical keys.
  String get webLogicalKeyMap {
    final StringBuffer result = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': LogicalKeyboardKey.${entry.constantName},");
      }
    }
    return result.toString().trimRight();
  }

  /// This generates the map of Web KeyboardEvent codes to physical keys.
  String get webPhysicalKeyMap {
    final StringBuffer result = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': PhysicalKeyboardKey.${entry.constantName},");
      }
    }
    return result.toString().trimRight();
  }

  /// This generates the map of Web number pad codes to logical keys.
  String get webNumpadMap {
    final StringBuffer result = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': LogicalKeyboardKey.${entry.constantName},");
      }
    }
    return result.toString().trimRight();
  }

  /// This generates the map of Web KeyboardEvent codes to logical key ids.
  String get webLogicalKeyCodeMap {
    final StringBuffer result = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': ${toHex(entry.flutterId, digits: 10)},");
      }
    }
    return result.toString().trimRight();
  }

  /// This generates the map of Web KeyboardEvent codes to physical key USB HID codes.
  String get webPhysicalKeyCodeMap {
    final StringBuffer result = StringBuffer();
    for (final Key entry in keyData.data) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': ${toHex(entry.usbHidCode)},");
      }
    }
    return result.toString().trimRight();
  }

  /// This generates the map of Web number pad codes to logical key ids.
  String get webNumpadCodeMap {
    final StringBuffer result = StringBuffer();
    for (final Key entry in numpadKeyData) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': ${toHex(entry.flutterId, digits: 10)},");
      }
    }
    return result.toString().trimRight();
  }

  /// Substitutes the various maps and definitions into the template file for
  /// keyboard_key.dart.
  String generateKeyboardKeys() {
    final Map<String, String> mappings = <String, String>{
      'PHYSICAL_KEY_MAP': predefinedHidCodeMap,
      'LOGICAL_KEY_MAP': predefinedKeyCodeMap,
      'LOGICAL_KEY_DEFINITIONS': logicalDefinitions,
      'LOGICAL_KEY_SYNONYMS': logicalSynonyms,
      'PHYSICAL_KEY_DEFINITIONS': physicalDefinitions,
    };

    final String template = File(path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data', 'keyboard_key.tmpl')).readAsStringSync();
    return injectDictionary(template, mappings);
  }

  /// Substitutes the various platform specific maps into the template file for
  /// keyboard_maps.dart.
  String generateKeyboardMaps() {
    // There is no macOS keycode map since macOS uses keycode to represent a physical key.
    // The LogicalKeyboardKey is generated by raw_keyboard_macos.dart from the unmodified characters
    // from NSEvent.
    final Map<String, String> mappings = <String, String>{
      'ANDROID_SCAN_CODE_MAP': androidScanCodeMap,
      'ANDROID_KEY_CODE_MAP': androidKeyCodeMap,
      'ANDROID_NUMPAD_MAP': androidNumpadMap,
      'FUCHSIA_SCAN_CODE_MAP': fuchsiaHidCodeMap,
      'FUCHSIA_KEY_CODE_MAP': fuchsiaKeyCodeMap,
      'MACOS_SCAN_CODE_MAP': macOsScanCodeMap,
      'MACOS_NUMPAD_MAP': macOsNumpadMap,
      'MACOS_FUNCTION_KEY_MAP': macOsFunctionKeyMap,
      'GLFW_KEY_CODE_MAP': glfwKeyCodeMap,
      'GLFW_NUMPAD_MAP': glfwNumpadMap,
      'GTK_KEY_CODE_MAP': gtkKeyCodeMap,
      'GTK_NUMPAD_MAP': gtkNumpadMap,
      'XKB_SCAN_CODE_MAP': xkbScanCodeMap,
      'WEB_LOGICAL_KEY_MAP': webLogicalKeyMap,
      'WEB_PHYSICAL_KEY_MAP': webPhysicalKeyMap,
      'WEB_NUMPAD_MAP': webNumpadMap,
      'WINDOWS_LOGICAL_KEY_MAP': windowsKeyCodeMap,
      'WINDOWS_PHYSICAL_KEY_MAP': windowsScanCodeMap,
      'WINDOWS_NUMPAD_MAP': windowsNumpadMap,
    };

    final String template = File(path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data', 'keyboard_maps.tmpl')).readAsStringSync();
    return injectDictionary(template, mappings);
  }

  /// Substitutes the web specific maps into the template file for
  /// keyboard_map_web.dart in the engine.
  String generateWebKeyboardMap() {
    final Map<String, String> mappings = <String, String>{
      'WEB_LOGICAL_KEY_CODE_MAP': webLogicalKeyCodeMap,
      'WEB_PHYSICAL_KEY_CODE_MAP': webPhysicalKeyCodeMap,
      'WEB_NUMPAD_CODE_MAP': webNumpadCodeMap,
    };

    final String template = File(path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data', 'keyboard_map_web.tmpl')).readAsStringSync();
    return injectDictionary(template, mappings);
  }

  /// The database of keys loaded from disk.
  final KeyData keyData;
}
