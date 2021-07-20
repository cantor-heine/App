// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

// TODO(justinmc): Move this all onto TextEditingValue?
/// State and logic for transforming that state related to Flutter's text
/// editing.
///
/// Contains only generic text editing logic and purposely excludes specific
/// business logic related to platforms and widgets.
@immutable
class TextEditingModel {
  /// Create an instance of TextEditingModel.
  const TextEditingModel({
    required this.value,
  }) : assert(value != null);

  /// The [TextEditingValue] that this TextEditingModel operates on.
  final TextEditingValue value;

  TextRange get _composing => value.composing;
  TextSelection get _selection => value.selection;
  String get _text => value.text;

  /// Return the given [TextSelection] with its [TextSelection.extentOffset]
  /// moved left by one character.
  ///
  /// {@macro flutter.rendering.RenderEditable.whiteSpace}
  static TextSelection extendGivenSelectionLeft(TextSelection selection, String text, [bool includeWhitespace = true]) {
    // If the selection is already all the way left, there is nothing to do.
    if (selection.extentOffset <= 0) {
      return selection;
    }
    final int previousExtent = previousCharacter(selection.extentOffset, text, includeWhitespace);
    return selection.copyWith(extentOffset: previousExtent);
  }

  /// Return the given [TextSelection] with its [TextSelection.extentOffset]
  /// moved right by one character.
  ///
  /// {@macro flutter.rendering.RenderEditable.whiteSpace}
  static TextSelection extendGivenSelectionRight(TextSelection selection, String text, [bool includeWhitespace = true]) {
    // If the selection is already all the way right, there is nothing to do.
    if (selection.extentOffset >= text.length) {
      return selection;
    }
    final int nextExtent = nextCharacter(selection.extentOffset, text, includeWhitespace);
    return selection.copyWith(extentOffset: nextExtent);
  }

  // TODO(gspencergoog): replace when we expose this ICU information.
  /// Check if the given code unit is a white space or separator
  /// character.
  ///
  /// Includes newline characters from ASCII and separators from the
  /// [unicode separator category](https://www.compart.com/en/unicode/category/Zs)
  static bool isWhitespace(int codeUnit) {
    switch (codeUnit) {
      case 0x9: // horizontal tab
      case 0xA: // line feed
      case 0xB: // vertical tab
      case 0xC: // form feed
      case 0xD: // carriage return
      case 0x1C: // file separator
      case 0x1D: // group separator
      case 0x1E: // record separator
      case 0x1F: // unit separator
      case 0x20: // space
      case 0xA0: // no-break space
      case 0x1680: // ogham space mark
      case 0x2000: // en quad
      case 0x2001: // em quad
      case 0x2002: // en space
      case 0x2003: // em space
      case 0x2004: // three-per-em space
      case 0x2005: // four-er-em space
      case 0x2006: // six-per-em space
      case 0x2007: // figure space
      case 0x2008: // punctuation space
      case 0x2009: // thin space
      case 0x200A: // hair space
      case 0x202F: // narrow no-break space
      case 0x205F: // medium mathematical space
      case 0x3000: // ideographic space
        break;
      default:
        return false;
    }
    return true;
  }

  /// Return a new selection that has been moved left once.
  ///
  /// If it can't be moved left, the original TextSelection is returned.
  static TextSelection moveGivenSelectionLeft(TextSelection selection, String text) {
    // If the selection is already all the way left, there is nothing to do.
    if (selection.isCollapsed && selection.extentOffset <= 0) {
      return selection;
    }

    int previousExtent;
    if (selection.start != selection.end) {
      previousExtent = selection.start;
    } else {
      previousExtent = previousCharacter(selection.extentOffset, text);
    }
    final TextSelection newSelection = selection.copyWith(
      extentOffset: previousExtent,
    );

    final int newOffset = newSelection.extentOffset;
    return TextSelection.fromPosition(TextPosition(offset: newOffset));
  }

  /// Return a new selection that has been moved right once.
  ///
  /// If it can't be moved right, the original TextSelection is returned.
  static TextSelection moveGivenSelectionRight(TextSelection selection, String text) {
    // If the selection is already all the way right, there is nothing to do.
    if (selection.isCollapsed && selection.extentOffset >= text.length) {
      return selection;
    }

    int nextExtent;
    if (selection.start != selection.end) {
      nextExtent = selection.end;
    } else {
      nextExtent = nextCharacter(selection.extentOffset, text);
    }
    final TextSelection nextSelection = selection.copyWith(extentOffset: nextExtent);

    int newOffset = nextSelection.extentOffset;
    newOffset = nextSelection.baseOffset > nextSelection.extentOffset
        ? nextSelection.baseOffset : nextSelection.extentOffset;
    return TextSelection.fromPosition(TextPosition(offset: newOffset));
  }

  /// Returns the index into the string of the next character boundary after the
  /// given index.
  ///
  /// The character boundary is determined by the characters package, so
  /// surrogate pairs and extended grapheme clusters are considered.
  ///
  /// The index must be between 0 and string.length, inclusive. If given
  /// string.length, string.length is returned.
  ///
  /// Setting includeWhitespace to false will only return the index of non-space
  /// characters.
  static int nextCharacter(int index, String string, [bool includeWhitespace = true]) {
    assert(index >= 0 && index <= string.length);
    if (index == string.length) {
      return string.length;
    }

    int count = 0;
    final Characters remaining = string.characters.skipWhile((String currentString) {
      if (count <= index) {
        count += currentString.length;
        return true;
      }
      if (includeWhitespace) {
        return false;
      }
      return isWhitespace(currentString.codeUnitAt(0));
    });
    return string.length - remaining.toString().length;
  }

  /// Returns the index into the string of the previous character boundary
  /// before the given index.
  ///
  /// The character boundary is determined by the characters package, so
  /// surrogate pairs and extended grapheme clusters are considered.
  ///
  /// The index must be between 0 and string.length, inclusive. If index is 0,
  /// 0 will be returned.
  ///
  /// Setting includeWhitespace to false will only return the index of non-space
  /// characters.
  ///
  /// {@macro flutter.rendering.RenderEditable.stopAtReversal}
  static int previousCharacter(int index, String string, [bool includeWhitespace = true]) {
    assert(index >= 0 && index <= string.length);
    if (index == 0) {
      return 0;
    }

    int count = 0;
    int? lastNonWhitespace;
    for (final String currentString in string.characters) {
      if (!includeWhitespace &&
          !isWhitespace(currentString.characters.first.codeUnitAt(0))) {
        lastNonWhitespace = count;
      }
      if (count + currentString.length >= index) {
        return includeWhitespace ? count : lastNonWhitespace ?? 0;
      }
      count += currentString.length;
    }
    return 0;
  }

  /// Return the offset at the start of the nearest word to the left of the
  /// given offset.
  ///
  /// {@macro flutter.rendering.RenderEditable.stopAtReversal}
  static int getLeftByWord(String text, TextMetrics textMetrics, int offset, [bool includeWhitespace = true]) {
    // If the offset is already all the way left, there is nothing to do.
    if (offset <= 0) {
      return offset;
    }

    // If we can just return the start of the text without checking for a word.
    if (offset == 1) {
      return 0;
    }

    final int startPoint = previousCharacter(offset, text, includeWhitespace);
    final TextRange word = textMetrics.getWordBoundary(TextPosition(offset: startPoint));
    return word.start;
  }

  /// Return the offset at the end of the nearest word to the right of the given
  /// offset.
  ///
  /// {@macro flutter.rendering.RenderEditable.stopAtReversal}
  static int getRightByWord(String text, TextMetrics textMetrics, int offset, [bool includeWhitespace = true]) {
    // If the selection is already all the way right, there is nothing to do.
    if (offset == text.length) {
      return offset;
    }

    // If we can just return the end of the text without checking for a word.
    if (offset == text.length - 1 || offset == text.length) {
      return text.length;
    }

    final int startPoint = includeWhitespace || !isWhitespace(text.codeUnitAt(offset))
        ? offset
        : nextCharacter(offset, text, includeWhitespace);
    final TextRange nextWord = textMetrics.getWordBoundary(TextPosition(offset: startPoint));
    return nextWord.end;
  }

  /// Return the given [TextSelection] extended left to the beginning of the
  /// nearest word.
  ///
  /// {@macro flutter.rendering.RenderEditable.whiteSpace}
  ///
  /// {@macro flutter.rendering.RenderEditable.stopAtReversal}
  static TextSelection extendGivenSelectionLeftByWord(String text, TextMetrics textMetrics, TextSelection selection, [bool includeWhitespace = true, bool stopAtReversal = false]) {
    // If the selection is already all the way left, there is nothing to do.
    if (selection.isCollapsed && selection.extentOffset <= 0) {
      return selection;
    }

    final int leftOffset = getLeftByWord(text, textMetrics, selection.extentOffset, includeWhitespace);

    if (stopAtReversal && selection.extentOffset > selection.baseOffset
        && leftOffset < selection.baseOffset) {
      return selection.copyWith(
        extentOffset: selection.baseOffset,
      );
    }

    return selection.copyWith(
      extentOffset: leftOffset,
    );
  }

  /// Return the given [TextSelection] extended right to the end of the nearest
  /// word.
  ///
  /// {@macro flutter.rendering.RenderEditable.whiteSpace}
  ///
  /// {@macro flutter.rendering.RenderEditable.stopAtReversal}
  static TextSelection extendGivenSelectionRightByWord(String text, TextMetrics textMetrics, TextSelection selection, [bool includeWhitespace = true, bool stopAtReversal = false]) {
    // If the selection is already all the way right, there is nothing to do.
    if (selection.isCollapsed && selection.extentOffset == text.length) {
      return selection;
    }

    final int rightOffset = getRightByWord(text, textMetrics, selection.extentOffset, includeWhitespace);

    if (stopAtReversal && selection.baseOffset > selection.extentOffset
        && rightOffset > selection.baseOffset) {
      return selection.copyWith(
        extentOffset: selection.baseOffset,
      );
    }

    return selection.copyWith(
      extentOffset: rightOffset,
    );
  }

  // TODO(justinmc): These static methods that need both the text and selection
  // should probably just be instance methods.
  /// Return the given [TextSelection] moved left to the end of the nearest word.
  ///
  /// A TextSelection that isn't collapsed will be collapsed and moved from the
  /// extentOffset.
  ///
  /// {@macro flutter.rendering.RenderEditable.stopAtReversal}
  static TextSelection moveGivenSelectionLeftByWord(String text, TextMetrics textMetrics, TextSelection selection, [bool includeWhitespace = true]) {
    // If the selection is already all the way left, there is nothing to do.
    if (selection.isCollapsed && selection.extentOffset <= 0) {
      return selection;
    }

    final int leftOffset = getLeftByWord(text, textMetrics, selection.extentOffset, includeWhitespace);
    return selection.copyWith(
      baseOffset: leftOffset,
      extentOffset: leftOffset,
    );
  }

  /// Return the given [TextSelection] moved right to the end of the nearest word.
  ///
  /// A TextSelection that isn't collapsed will be collapsed and moved from the
  /// extentOffset.
  ///
  /// {@macro flutter.rendering.RenderEditable.stopAtReversal}
  static TextSelection moveGivenSelectionRightByWord(String text, TextMetrics textMetrics, TextSelection selection, [bool includeWhitespace = true]) {
    // If the selection is already all the way right, there is nothing to do.
    if (selection.isCollapsed && selection.extentOffset == text.length) {
      return selection;
    }

    final int rightOffset = getRightByWord(text, textMetrics, selection.extentOffset, includeWhitespace);
    return selection.copyWith(
      baseOffset: rightOffset,
      extentOffset: rightOffset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.moveSelectionRightByLine}
  /// Move the current [_selection] to the leftmost point of the current line.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [moveSelectionRightByLine], which is the same but in the opposite
  ///     direction.
  TextSelection moveSelectionLeftByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    // If the previous character is the edge of a line, don't do anything.
    final int previousPoint = TextEditingModel.previousCharacter(_selection.extentOffset, _text, true);
    final TextSelection line = textMetrics.getLineAtOffset(_text, TextPosition(offset: previousPoint));
    if (line.extentOffset == previousPoint) {
      return _selection;
    }

    // When going left, we want to skip over any whitespace before the line,
    // so we go back to the first non-whitespace before asking for the line
    // bounds, since getLineAtOffset finds the line boundaries without
    // including whitespace (like the newline).
    final int startPoint = TextEditingModel.previousCharacter(_selection.extentOffset, _text, false);
    final TextSelection selectedLine = textMetrics.getLineAtOffset(
      _text,
      TextPosition(offset: startPoint),
    );
    return TextSelection.collapsed(
      offset: selectedLine.baseOffset,
    );
  }

  /// Extend the current selection to the end of the field.
  ///
  /// If selectionEnabled is false, keeps the selection collapsed and moves it to
  /// the end.
  ///
  /// See also:
  ///
  ///   * [extendSelectionToStart]
  TextSelection extendSelectionToEnd() {
    if (_selection.extentOffset == _text.length) {
      return _selection;
    }

    return _selection.copyWith(
      extentOffset: _text.length,
    );
  }

  /// Deletes backwards from the selection in [textSelectionDelegate].
  ///
  /// This method operates on the text/selection contained in
  /// [textSelectionDelegate], and does not depend on [selection].
  ///
  /// If the selection is collapsed, deletes a single character before the
  /// cursor.
  ///
  /// If the selection is not collapsed, deletes the selection.
  ///
  /// {@template flutter.rendering.RenderEditable.cause}
  /// The given [SelectionChangedCause] indicates the cause of this change and
  /// will be passed to [onSelectionChanged].
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///   * [deleteForward], which is same but in the opposite direction.
  TextEditingValue delete() {
    // `delete` does not depend on the text layout, and the boundary analysis is
    // done using the `previousCharacter` method instead of ICU, we can keep
    // deleting without having to layout the text. For this reason, we can
    // directly delete the character before the caret in the controller.
    if (!_selection.isValid) {
      return value;
    }
    if (!_selection.isCollapsed) {
      return _deleteNonEmptySelection();
    }

    final String textBefore = _selection.textBefore(value.text);
    if (textBefore.isEmpty) {
      return value;
    }

    final String textAfter = _selection.textAfter(value.text);

    final int characterBoundary = TextEditingModel.previousCharacter(textBefore.length, textBefore);
    final TextSelection newSelection = TextSelection.collapsed(offset: characterBoundary);
    final TextRange composing = value.composing;
    assert(textBefore.length >= characterBoundary);
    final TextRange newComposingRange = !composing.isValid || composing.isCollapsed
      ? TextRange.empty
      : TextRange(
        start: composing.start - (composing.start - characterBoundary).clamp(0, textBefore.length - characterBoundary),
        end: composing.end - (composing.end - characterBoundary).clamp(0, textBefore.length - characterBoundary),
      );

    return TextEditingValue(
      text: textBefore.substring(0, characterBoundary) + textAfter,
      selection: newSelection,
      composing: newComposingRange,
    );
  }

  // Deletes the current non-empty selection.
  //
  // Operates on the text/selection contained in textSelectionDelegate, and does
  // not depend on `RenderEditable.selection`.
  //
  // If the selection is currently non-empty, this method deletes the selected
  // text and returns true. Otherwise this method does nothing and returns
  // false.
  TextEditingValue _deleteNonEmptySelection() {
    assert(_selection.isValid);
    assert(!_selection.isCollapsed);

    final String textBefore = _selection.textBefore(_text);
    final String textAfter = _selection.textAfter(_text);
    final TextSelection newSelection = TextSelection.collapsed(offset: _selection.start);
    final TextRange newComposingRange = !_composing.isValid || _composing.isCollapsed
      ? TextRange.empty
      : TextRange(
        start: _composing.start - (_composing.start - _selection.start).clamp(0, _selection.end - _selection.start),
        end: _composing.end - (_composing.end - _selection.start).clamp(0, _selection.end - _selection.start),
      );

    return TextEditingValue(
      text: textBefore + textAfter,
      selection: newSelection,
      composing: newComposingRange,
    );
  }

  /// Deletes the from the current collapsed selection to the start of the field.
  ///
  /// The given SelectionChangedCause indicates the cause of this change and
  /// will be passed to onSelectionChanged.
  ///
  /// See also:
  ///   * [deleteToEnd]
  TextEditingValue deleteToStart() {
    assert(_selection.isCollapsed);

    if (!_selection.isValid) {
      return value;
    }

    final String textBefore = _selection.textBefore(_text);

    if (textBefore.isEmpty) {
      return value;
    }

    final String textAfter = _selection.textAfter(_text);
    const TextSelection newSelection = TextSelection.collapsed(offset: 0);
    return TextEditingValue(text: textAfter, selection: newSelection);
  }

  /// Deletes the from the current collapsed selection to the end of the field.
  ///
  /// The given SelectionChangedCause indicates the cause of this change and
  /// will be passed to onSelectionChanged.
  ///
  /// See also:
  ///   * [deleteToStart]
  TextEditingValue deleteToEnd() {
    assert(_selection.isCollapsed);

    if (!_selection.isValid) {
      return value;
    }

    final String textAfter = _selection.textAfter(_text);

    if (textAfter.isEmpty) {
      return value;
    }

    final String textBefore = _selection.textBefore(_text);
    final TextSelection newSelection = TextSelection.collapsed(offset: textBefore.length);
    return TextEditingValue(text: textBefore, selection: newSelection);
  }

  // TODO(justinmc): Update the references on this whiteSpace template.
  /// {@template flutter.rendering.TextEditingModel.whiteSpace}
  /// Deletes a word backwards from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a word before the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  /// {@endtemplate}
  ///
  /// {@template flutter.rendering.RenderEditable.whiteSpace}
  /// By default, includeWhitespace is set to true, meaning that whitespace can
  /// be considered a word in itself.  If set to false, the selection will be
  /// extended past any whitespace and the first word following the whitespace.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///   * [deleteForwardByWord], which is same but in the opposite direction.
  TextEditingValue deleteByWord(TextMetrics textMetrics, [bool includeWhitespace = true]) {
    assert(_selection != null);

    if (!_selection.isValid) {
      return value;
    }

    if (!_selection.isCollapsed) {
      return _deleteNonEmptySelection();
    }

    String textBefore = _selection.textBefore(_text);
    if (textBefore.isEmpty) {
      return value;
    }

    final int characterBoundary = TextEditingModel.getLeftByWord(_text, textMetrics, textBefore.length, includeWhitespace);
    textBefore = textBefore.trimRight().substring(0, characterBoundary);

    final String textAfter = _selection.textAfter(_text);
    final TextSelection newSelection = TextSelection.collapsed(offset: characterBoundary);
    return TextEditingValue(text: textBefore + textAfter, selection: newSelection);
  }

  /// {@template flutter.rendering.TextEditingModel.deleteByLine}
  /// Deletes a line backwards from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a line before the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///   * [deleteForwardByLine], which is same but in the opposite direction.
  TextEditingValue deleteByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    if (!_selection.isValid) {
      return value;
    }

    if (!_selection.isCollapsed) {
      return _deleteNonEmptySelection();
    }

    String textBefore = _selection.textBefore(_text);
    if (textBefore.isEmpty) {
      return value;
    }

    // When there is a line break, line delete shouldn't do anything
    final bool isPreviousCharacterBreakLine = textBefore.codeUnitAt(textBefore.length - 1) == 0x0A;
    if (isPreviousCharacterBreakLine) {
      return value;
    }

    final TextSelection line = textMetrics.getLineAtOffset(_text, TextPosition(offset: textBefore.length - 1));
    textBefore = textBefore.substring(0, line.start);

    final String textAfter = _selection.textAfter(_text);
    final TextSelection newSelection = TextSelection.collapsed(offset: textBefore.length);
    return TextEditingValue(text: textBefore + textAfter, selection: newSelection);
  }

  /// {@template flutter.rendering.TextEditingModel.deleteForward}
  /// Deletes in the forward direction.
  ///
  /// If the selection is collapsed, deletes a single character after the
  /// cursor.
  ///
  /// If the selection is not collapsed, deletes the selection.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [delete], which is the same but in the opposite direction.
  TextEditingValue deleteForward() {
    if (!_selection.isValid) {
      return value;
    }
    if (!_selection.isCollapsed) {
      return _deleteNonEmptySelection();
    }

    final String textAfter = _selection.textAfter(_text);
    if (textAfter.isEmpty) {
      return value;
    }

    final String textBefore = _selection.textBefore(_text);
    final int characterBoundary = TextEditingModel.nextCharacter(0, textAfter);
    final TextRange composing = _composing;
    final TextRange newComposingRange = !composing.isValid || composing.isCollapsed
      ? TextRange.empty
      : TextRange(
        start: composing.start - (composing.start - textBefore.length).clamp(0, characterBoundary),
        end: composing.end - (composing.end - textBefore.length).clamp(0, characterBoundary),
      );
    return TextEditingValue(
      text: textBefore + textAfter.substring(characterBoundary),
      selection: _selection,
      composing: newComposingRange,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.deleteForward}
  /// Deletes a word in the forward direction from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a word after the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// {@macro flutter.rendering.RenderEditable.whiteSpace}
  ///
  /// See also:
  ///
  ///   * [deleteByWord], which is same but in the opposite direction.
  TextEditingValue deleteForwardByWord(TextMetrics textMetrics, [bool includeWhitespace = true]) {
    assert(_selection != null);

    if (!_selection.isValid) {
      return value;
    }

    if (!_selection.isCollapsed) {
      return _deleteNonEmptySelection();
    }

    String textAfter = _selection.textAfter(_text);

    if (textAfter.isEmpty) {
      return value;
    }

    final String textBefore = _selection.textBefore(_text);
    final int characterBoundary = TextEditingModel.getRightByWord(_text, textMetrics, textBefore.length, includeWhitespace);
    textAfter = textAfter.substring(characterBoundary - textBefore.length);

    return TextEditingValue(text: textBefore + textAfter, selection: _selection);
  }

  /// {@template flutter.rendering.TextEditingModel.deleteForwardByLine}
  /// Deletes a line in the forward direction from the current selection.
  ///
  /// If the [selection] is collapsed, deletes a line after the cursor.
  ///
  /// If the [selection] is not collapsed, deletes the selection.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///   * [deleteByLine], which is same but in the opposite direction.
  TextEditingValue deleteForwardByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    if (!_selection.isValid) {
      return value;
    }

    if (!_selection.isCollapsed) {
      return _deleteNonEmptySelection();
    }

    String textAfter = _selection.textAfter(_text);
    if (textAfter.isEmpty) {
      return value;
    }

    // When there is a line break, it shouldn't do anything.
    final bool isNextCharacterBreakLine = textAfter.codeUnitAt(0) == 0x0A;
    if (isNextCharacterBreakLine) {
      return value;
    }

    final String textBefore = _selection.textBefore(_text);
    final TextSelection line = textMetrics.getLineAtOffset(_text, TextPosition(offset: textBefore.length));
    textAfter = textAfter.substring(line.end - textBefore.length, textAfter.length);

    return TextEditingValue(text: textBefore + textAfter, selection: _selection);
  }

  /// {@template flutter.rendering.TextEditingModel.extendSelectionDown}
  /// Keeping [selection]'s [TextSelection.baseOffset] fixed, move the
  /// [TextSelection.extentOffset] down by one line.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [extendSelectionUp], which is same but in the opposite direction.
  TextSelection extendSelectionDown(TextMetrics textMetrics) {
    assert(_selection != null);

    // If the selection is collapsed at the end of the field already, then
    // nothing happens.
    if (_selection.isCollapsed && _selection.extentOffset >= _text.length) {
      return _selection;
    }

    final TextPosition positionBelow = textMetrics.getTextPositionBelow(_selection.extentOffset);
    if (positionBelow.offset == _selection.extentOffset) {
      return _selection.copyWith(
        extentOffset: _text.length,
      );
    }
    return _selection.copyWith(
      extentOffset: positionBelow.offset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.expandSelectionToEnd}
  /// Expand the current selection to the end of the field.
  ///
  /// The selection will never shrink. The [TextSelection.extentOffset] will
  // always be at the end of the field, regardless of the original order of
  /// [TextSelection.baseOffset] and [TextSelection.extentOffset].
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [expandSelectionToStart], which is same but in the opposite direction.
  TextSelection expandSelectionToEnd() {
    assert(_selection != null);

    if (_selection.extentOffset == _text.length) {
      return _selection;
    }

    final int firstOffset = math.max(0, math.min(
      _selection.baseOffset,
      _selection.extentOffset,
    ));
    return TextSelection(
      baseOffset: firstOffset,
      extentOffset: _text.length,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.extendSelectionLeft}
  /// Keeping [_selection]'s [TextSelection.baseOffset] fixed, move the
  /// [TextSelection.extentOffset] left.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [extendSelectionRight], which is same but in the opposite direction.
  TextSelection extendSelectionLeft() {
    assert(_selection != null);

    return extendGivenSelectionLeft(
      _selection,
      _text,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.extendSelectionLeftByLine}
  /// Extend the current [_selection] to the start of
  /// [TextSelection.extentOffset]'s line.
  ///
  /// Uses [TextSelection.baseOffset] as a pivot point and doesn't change it.
  /// If [TextSelection.extentOffset] is right of [TextSelection.baseOffset],
  /// then collapses the selection.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [extendSelectionRightByLine], which is same but in the opposite
  ///     direction.
  ///   * [expandSelectionRightByLine], which strictly grows the selection
  ///     regardless of the order.
  TextSelection extendSelectionLeftByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    // When going left, we want to skip over any whitespace before the line,
    // so we go back to the first non-whitespace before asking for the line
    // bounds, since getLineAtOffset finds the line boundaries without
    // including whitespace (like the newline).
    final int startPoint = TextEditingModel.previousCharacter(_selection.extentOffset, _text, false);
    final TextSelection selectedLine = textMetrics.getLineAtOffset(_text, TextPosition(offset: startPoint));

    if (_selection.extentOffset > _selection.baseOffset) {
      return _selection.copyWith(
        extentOffset: _selection.baseOffset,
      );
    }
    return _selection.copyWith(
      extentOffset: selectedLine.baseOffset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.extendSelectionRight}
  /// Keeping [_selection]'s [TextSelection.baseOffset] fixed, move the
  /// [TextSelection.extentOffset] right.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [extendSelectionLeft], which is same but in the opposite direction.
  TextSelection extendSelectionRight() {
    assert(_selection != null);

    return TextEditingModel.extendGivenSelectionRight(
      _selection,
      _text,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.extendSelectionRightByLine}
  /// Extend the current [_selection] to the end of [TextSelection.extentOffset]'s
  /// line.
  ///
  /// Uses [TextSelection.baseOffset] as a pivot point and doesn't change it. If
  /// [TextSelection.extentOffset] is left of [TextSelection.baseOffset], then
  /// collapses the selection.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [extendSelectionLeftByLine], which is same but in the opposite
  ///     direction.
  ///   * [expandSelectionRightByLine], which strictly grows the selection
  ///     regardless of the order.
  TextSelection extendSelectionRightByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    final int startPoint = TextEditingModel.nextCharacter(_selection.extentOffset, _text, false);
    final TextSelection selectedLine = textMetrics.getLineAtOffset(_text, TextPosition(offset: startPoint));

    if (_selection.extentOffset < _selection.baseOffset) {
      return _selection.copyWith(
        extentOffset: _selection.baseOffset,
      );
    }
    return _selection.copyWith(
      extentOffset: selectedLine.extentOffset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.extendSelectionUp}
  /// Keeping [_selection]'s [TextSelection.baseOffset] fixed, move the
  /// [TextSelection.extentOffset] up by one
  /// line.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [extendSelectionDown], which is the same but in the opposite
  ///     direction.
  TextSelection extendSelectionUp(TextMetrics textMetrics) {
    assert(_selection != null);

    // If the selection is collapsed at the beginning of the field already, then
    // nothing happens.
    if (_selection.isCollapsed && _selection.extentOffset <= 0.0) {
      return _selection;
    }

    final TextPosition positionAbove = textMetrics.getTextPositionAbove(_selection.extentOffset);
    if (positionAbove.offset == _selection.extentOffset) {
      return _selection.copyWith(
        extentOffset: 0,
      );
    }
    return _selection.copyWith(
      baseOffset: _selection.baseOffset,
      extentOffset: positionAbove.offset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.expandSelectionToStart}
  /// Expand the current [_selection] to the start of the field.
  ///
  /// The selection will never shrink. The [TextSelection.extentOffset] will
  /// always be at the start of the field, regardless of the original order of
  /// [TextSelection.baseOffset] and [TextSelection.extentOffset].
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [expandSelectionToEnd], which is the same but in the opposite
  ///     direction.
  TextSelection expandSelectionToStart() {
    assert(_selection != null);

    if (_selection.extentOffset == 0) {
      return _selection;
    }

    final int lastOffset = math.max(0, math.max(
      _selection.baseOffset,
      _selection.extentOffset,
    ));
    return TextSelection(
      baseOffset: lastOffset,
      extentOffset: 0,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.expandSelectionLeftByLine}
  /// Expand the current [_selection] to the start of the line.
  ///
  /// The selection will never shrink. The upper offset will be expanded to the
  /// beginning of its line, and the original order of baseOffset and
  /// [TextSelection.extentOffset] will be preserved.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [expandSelectionRightByLine], which is the same but in the opposite
  ///     direction.
  TextSelection expandSelectionLeftByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    final int firstOffset = math.min(_selection.baseOffset, _selection.extentOffset);
    final int startPoint = TextEditingModel.previousCharacter(firstOffset, _text, false);
    final TextSelection selectedLine = textMetrics.getLineAtOffset(_text, TextPosition(offset: startPoint));

    if (_selection.extentOffset <= _selection.baseOffset) {
      return _selection.copyWith(
        extentOffset: selectedLine.baseOffset,
      );
    }
    return _selection.copyWith(
      baseOffset: selectedLine.baseOffset,
    );
  }

  /// Extend the current selection to the start of the field.
  ///
  /// See also:
  ///
  ///   * [extendSelectionToEnd], which is the same but in the opposite
  ///     direction.
  TextSelection extendSelectionToStart() {
    if (_selection.extentOffset == 0) {
      return _selection;
    }

    return _selection.copyWith(
      extentOffset: 0,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.expandSelectionRightByLine}
  /// Expand the current [_selection] to the end of the line.
  ///
  /// The selection will never shrink. The lower offset will be expanded to the
  /// end of its line and the original order of [TextSelection.baseOffset] and
  /// [TextSelection.extentOffset] will be preserved.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [expandSelectionLeftByLine], which is the same but in the opposite
  ///     direction.
  TextSelection expandSelectionRightByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    final int lastOffset = math.max(_selection.baseOffset, _selection.extentOffset);
    final int startPoint = TextEditingModel.nextCharacter(lastOffset, _text, false);
    final TextSelection selectedLine = textMetrics.getLineAtOffset(_text, TextPosition(offset: startPoint));

    if (_selection.extentOffset >= _selection.baseOffset) {
      return _selection.copyWith(
        extentOffset: selectedLine.extentOffset,
      );
    }
    return _selection.copyWith(
      baseOffset: selectedLine.extentOffset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.moveSelectionDown}
  /// Move the current [_selection] to the next line.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [moveSelectionUp], which is the same but in the opposite direction.
  TextSelection moveSelectionDown(TextMetrics textMetrics) {
    assert(_selection != null);

    // If the selection is collapsed at the end of the field already, then
    // nothing happens.
    if (_selection.isCollapsed && _selection.extentOffset >= _text.length) {
      return _selection;
    }

    final TextPosition positionBelow = textMetrics.getTextPositionBelow(_selection.extentOffset);

    late final TextSelection nextSelection;
    if (positionBelow.offset == _selection.extentOffset) {
      nextSelection = _selection.copyWith(
        baseOffset: _text.length,
        extentOffset: _text.length,
      );
    } else {
      nextSelection = TextSelection.fromPosition(positionBelow);
    }

    return nextSelection;
  }

  /// {@template flutter.rendering.TextEditingModel.moveSelectionRightByLine}
  /// Move the current [_selection] to the rightmost point of the current line.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [moveSelectionLeftByLine], which is the same but in the opposite
  ///     direction.
  TextSelection moveSelectionRightByLine(TextMetrics textMetrics) {
    assert(_selection != null);

    // If already at the right edge of the line, do nothing.
    final TextSelection currentLine = textMetrics.getLineAtOffset(
      _text,
      TextPosition(
        offset: _selection.extentOffset,
      ),
    );
    if (currentLine.extentOffset == _selection.extentOffset) {
      return _selection;
    }

    // When going right, we want to skip over any whitespace after the line,
    // so we go forward to the first non-whitespace character before asking
    // for the line bounds, since getLineAtOffset finds the line
    // boundaries without including whitespace (like the newline).
    final int startPoint = TextEditingModel.nextCharacter(_selection.extentOffset, _text, false);
    final TextSelection selectedLine = textMetrics.getLineAtOffset(_text, TextPosition(offset: startPoint));
    return TextSelection.collapsed(
      offset: selectedLine.extentOffset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.moveSelectionToEnd}
  /// Move the current [_selection] to the end of the field.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [moveSelectionToStart], which is the same but in the opposite
  ///     direction.
  TextSelection moveSelectionToEnd() {
    assert(_selection != null);

    if (_selection.isCollapsed && _selection.extentOffset == _text.length) {
      return _selection;
    }
    return TextSelection.collapsed(
      offset: _text.length,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.moveSelectionToStart}
  /// Move the current [_selection] to the start of the field.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [moveSelectionToEnd], which is the same but in the opposite direction.
  TextSelection moveSelectionToStart() {
    assert(_selection != null);

    if (_selection.isCollapsed && _selection.extentOffset == 0) {
      return _selection;
    }
    return const TextSelection.collapsed(offset: 0);
  }

  /// {@template flutter.rendering.TextEditingModel.moveSelectionUp}
  /// Move the current [_selection] up by one line.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  ///
  /// See also:
  ///
  ///   * [moveSelectionDown], which is the same but in the opposite direction.
  TextSelection moveSelectionUp(TextMetrics textMetrics) {
    assert(_selection != null);

    // If the selection is collapsed at the beginning of the field already, then
    // nothing happens.
    if (_selection.isCollapsed && _selection.extentOffset <= 0.0) {
      return _selection;
    }

    final TextPosition positionAbove = textMetrics.getTextPositionAbove(_selection.extentOffset);
    if (positionAbove.offset == _selection.extentOffset) {
      return _selection.copyWith(baseOffset: 0, extentOffset: 0);
    }
    return _selection.copyWith(
      baseOffset: positionAbove.offset,
      extentOffset: positionAbove.offset,
    );
  }

  /// {@template flutter.rendering.TextEditingModel.selectAll}
  /// Set the current [_selection] to contain the entire text value.
  /// {@endtemplate}
  ///
  /// {@macro flutter.rendering.RenderEditable.cause}
  TextSelection selectAll() {
    return _selection.copyWith(
      baseOffset: 0,
      extentOffset: _text.length,
    );
  }
}

// TODO(justinmc): Document and move to own file.
// TODO(justinmc): Rename to TextEditingMetrics?
/// A read-only interface for accessing information about some editable text.
abstract class TextMetrics {
  TextSelection getLineAtOffset(String text, TextPosition position);

  TextRange getWordBoundary(TextPosition position);

  /// Returns the TextPosition above the given offset into _plainText.
  ///
  /// If the offset is already on the first line, the given offset will be
  /// returned.
  TextPosition getTextPositionAbove(int offset);

  /// Returns the TextPosition below the given offset into _plainText.
  ///
  /// If the offset is already on the last line, the given offset will be
  /// returned.
  TextPosition getTextPositionBelow(int offset);

  /// Returns the TextPosition above or below the given offset.
  TextPosition getTextPositionVertical(int textOffset, double verticalOffset);
}
