// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:path/path.dart' as path;

import 'base_code_gen.dart';
import 'logical_key_data.dart';
import 'physical_key_data.dart';
import 'utils.dart';

/// Given an [input] string, wraps the text at 80 characters and prepends each
/// line with the [prefix] string. Use for generated comments.
String _wrapString(String input) {
  return wrapString(input, prefix: '  /// ');
}

/// Generates the keyboard_key.dart based on the information in the key data
/// structure given to it.
class KeyboardKeysCodeGenerator extends BaseCodeGenerator {
  KeyboardKeysCodeGenerator(PhysicalKeyData physicalData, this.logicalData) : super(physicalData);

  final LogicalKeyData logicalData;
  PhysicalKeyData get physicalData => keyData;

  /// Gets the generated definitions of PhysicalKeyboardKeys.
  String get _physicalDefinitions {
    final StringBuffer definitions = StringBuffer();
    for (final PhysicalKeyEntry entry in physicalData.data) {
      final String firstComment = _wrapString('Represents the location of the '
        '"${entry.commentName}" key on a generalized keyboard.');
      final String otherComments = _wrapString('See the function '
        '[RawKeyEvent.physicalKey] for more information.');
      definitions.write('''

$firstComment  ///
$otherComments  static const PhysicalKeyboardKey ${entry.constantName} = PhysicalKeyboardKey(${toHex(entry.usbHidCode, digits: 8)});
''');
    }
    return definitions.toString();
  }

  String get _physicalDebugNames {
    final StringBuffer result = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data) {
      result.write('''
      ${toHex(entry.usbHidCode, digits: 8)}: '${entry.commentName}',
''');
    }
    return result.toString();
  }

  /// Gets the generated definitions of LogicalKeyboardKeys.
  String get _logicalDefinitions {
    final StringBuffer definitions = StringBuffer();
    void printKey(int flutterId, String constantName, String commentName, {String? otherComments}) {
      final String firstComment = _wrapString('Represents the logical "$commentName" key on the keyboard.');
      otherComments ??= _wrapString('See the function [RawKeyEvent.logicalKey] for more information.');
      definitions.write('''

$firstComment  ///
$otherComments  static const LogicalKeyboardKey $constantName = LogicalKeyboardKey(${toHex(flutterId, digits: 11)});
''');
    }

    for (final LogicalKeyEntry entry in logicalData.data.values) {
      printKey(
        entry.value,
        entry.constantName,
        entry.commentName,
      );
    }
    for (final String name in PhysicalKeyEntry.synonyms.keys) {
      // Use the first item in the synonyms as a template for the ID to use.
      // It won't end up being the same value because it'll be in the pseudo-key
      // plane.
      final List<String> synonyms = PhysicalKeyEntry.synonyms[name]!;
      final PhysicalKeyEntry entry = physicalData.data.firstWhere((PhysicalKeyEntry item) => item.chromiumCode == synonyms[0]);
      final Set<String> unionNames = synonyms.map<String>((dynamic name) {
        return upperCamelToLowerCamel(name as String);
      }).toSet();
      printKey(PhysicalKeyEntry.synonymPlane | entry.flutterId, name, PhysicalKeyEntry.getCommentName(name),
          otherComments: _wrapString('This key represents the union of the keys '
              '$unionNames when comparing keys. This key will never be generated '
              'directly, its main use is in defining key maps.'));
    }
    return definitions.toString();
  }

  String get _logicalSynonyms {
    final StringBuffer result = StringBuffer();
    PhysicalKeyEntry.synonyms.forEach((String name, List<String> synonyms) {
      for (final String synonym in synonyms) {
        final String keyName = upperCamelToLowerCamel(synonym);
        result.writeln('    $keyName: $name,');
      }
    });
    return result.toString();
  }

  String get _logicalKeyLabels {
    final StringBuffer result = StringBuffer();
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      result.write('''
    ${toHex(entry.value, digits: 11)}: '${entry.commentName}',
''');
    }
    LogicalKeyData.synonyms.forEach((String name, List<String> synonyms) {
      // Use the first item in the synonyms as a template for the ID to use.
      // It won't end up being the same value because it'll be in the pseudo-key
      // plane.
      final PhysicalKeyEntry entry = keyData.data.firstWhere((PhysicalKeyEntry item) => item.chromiumCode == synonyms[0]);
      result.write('''
    ${toHex(PhysicalKeyEntry.synonymPlane | entry.flutterId, digits: 11)}: '${PhysicalKeyEntry.getCommentName(name)}',
''');
    });
    return result.toString();
  }

  /// This generates the map of USB HID codes to physical keys.
  String get _predefinedHidCodeMap {
    final StringBuffer scanCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in physicalData.data) {
      scanCodeMap.writeln('    ${toHex(entry.usbHidCode)}: ${entry.constantName},');
    }
    return scanCodeMap.toString().trimRight();
  }

  /// This generates the map of Flutter key codes to logical keys.
  String get _predefinedKeyCodeMap {
    final StringBuffer keyCodeMap = StringBuffer();
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      keyCodeMap.writeln('    ${toHex(entry.value, digits: 10)}: ${entry.constantName},');
    }
    PhysicalKeyEntry.synonyms.forEach((String entry, List<String> synonyms) {
      // Use the first item in the synonyms as a template for the ID to use.
      // It won't end up being the same value because it'll be in the pseudo-key
      // plane.
      final PhysicalKeyEntry primaryKey = physicalData.data.firstWhere((PhysicalKeyEntry item) {
        return item.chromiumCode == synonyms[0];
      });
      assert(primaryKey != null);
      keyCodeMap.writeln('    ${toHex(PhysicalKeyEntry.synonymPlane | primaryKey.flutterId, digits: 10)}: $entry,');
    });
    return keyCodeMap.toString().trimRight();
  }

  @override
  String get templatePath => path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data', 'keyboard_key.tmpl');

  @override
  Map<String, String> mappings() {
    return <String, String>{
      'PHYSICAL_KEY_MAP': _predefinedHidCodeMap,
      'LOGICAL_KEY_MAP': _predefinedKeyCodeMap,
      'LOGICAL_KEY_DEFINITIONS': _logicalDefinitions,
      'LOGICAL_KEY_SYNONYMS': _logicalSynonyms,
      'LOGICAL_KEY_KEY_LABELS': _logicalKeyLabels,
      'PHYSICAL_KEY_DEFINITIONS': _physicalDefinitions,
      'PHYSICAL_KEY_DEBUG_NAMES': _physicalDebugNames,
    };
  }
}
