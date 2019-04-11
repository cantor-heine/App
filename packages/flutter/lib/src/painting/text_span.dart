// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show ParagraphBuilder;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'basic_types.dart';
import 'inline_span.dart';
import 'text_style.dart';
import 'text_painter.dart';

/// An immutable span of text.
///
/// A [TextSpan] object can be styled using its [style] property.
/// The style will be applied to the [text] and the [children].
///
/// A [TextSpan] object can just have plain text, or it can have
/// children [TextSpan] objects with their own styles that (possibly
/// only partially) override the [style] of this object. If a
/// [TextSpan] has both [text] and [children], then the [text] is
/// treated as if it was an unstyled [TextSpan] at the start of the
/// [children] list.
///
/// To paint a [TextSpan] on a [Canvas], use a [TextPainter]. To display a text
/// span in a widget, use a [RichText]. For text with a single style, consider
/// using the [Text] widget.
///
/// {@tool sample}
///
/// The text "Hello world!", in black:
///
/// ```dart
/// TextSpan(
///   text: 'Hello world!',
///   style: TextStyle(color: Colors.black),
/// )
/// ```
/// {@end-tool}
///
/// _There is some more detailed sample code in the documentation for the
/// [recognizer] property._
///
/// Widgets may be embedded inline. Specify a widget within the [children]
/// tree by wrapping the widget with a [WidgetSpan]. The widget will be laid
/// out inline within the paragraph.
///
/// See also:
///
///  * [WidgetSpan], a leaf node that represents an embedded inline widget
///    in a [TextSpan] tree.
///  * [Text], a widget for showing uniformly-styled text.
///  * [RichText], a widget for finer control of text rendering.
///  * [TextPainter], a class for painting [TextSpan] objects on a [Canvas].
@immutable
class TextSpan extends InlineSpan {
  /// Creates a [TextSpan] with the given values.
  ///
  /// For the object to be useful, at least one of [text] or
  /// [children] should be set.
  const TextSpan({
    this.text,
    this.children,
    TextStyle style,
    GestureRecognizer recognizer,
    String semanticsLabel,
  }) : super(style: style, recognizer: recognizer, semanticsLabel: semanticsLabel);

  /// The text contained in the span.
  ///
  /// If both [text] and [children] are non-null, the text will precede the
  /// children.
  final String text;

  /// Additional spans to include as children.
  ///
  /// If both [text] and [children] are non-null, the text will precede the
  /// children.
  ///
  /// Modifying the list after the [TextSpan] has been created is not
  /// supported and may have unexpected results.
  ///
  /// The list must not contain any nulls.
  final List<InlineSpan> children;

  /// Apply the [style], [text], and [children] of this object to the
  /// given [ParagraphBuilder], from which a [Paragraph] can be obtained.
  /// [Paragraph] objects can be drawn on [Canvas] objects.
  ///
  /// Rather than using this directly, it's simpler to use the
  /// [TextPainter] class to paint [TextSpan] objects onto [Canvas]
  /// objects.
  void build(ui.ParagraphBuilder builder, { double textScaleFactor = 1.0, List<PlaceholderDimensions> dimensions }) {
    assert(debugAssertIsValid());
    final bool hasStyle = style != null;
    if (hasStyle)
      builder.pushStyle(style.getTextStyle(textScaleFactor: textScaleFactor));
    if (text != null)
      builder.addText(text);
    if (children != null) {
      for (InlineSpan child in children) {
        assert(child != null);
        child.build(builder, textScaleFactor: textScaleFactor, dimensions: dimensions);
      }
    }
    if (hasStyle)
      builder.pop();
  }

  /// Walks this text span and its descendants in pre-order and calls [visitor]
  /// for each span that has text.
  @override
  bool visitInlineSpan(bool visitor(InlineSpan span)) {
    if (text != null) {
      if (!visitor(this))
        return false;
    }
    if (children != null) {
      for (InlineSpan child in children) {
        if (!child.visitInlineSpan(visitor))
          return false;
      }
    }
    return true;
  }

  /// Returns the text span that contains the given position in the text.
  TextSpan getSpanForPosition(TextPosition position) {
    assert(debugAssertIsValid());
    final TextAffinity affinity = position.affinity;
    final int targetOffset = position.offset;
    int offset = 0;
    TextSpan result;
    visitInlineSpan((InlineSpan span) {
      assert(result == null);
      TextSpan textSpan = InlineSpan.asType<TextSpan>(span);
      if (textSpan == null)
        return true;
      final int endOffset = offset + textSpan.text.length;
      if (targetOffset == offset && affinity == TextAffinity.downstream ||
          targetOffset > offset && targetOffset < endOffset ||
          targetOffset == endOffset && affinity == TextAffinity.upstream) {
        result = span;
        return false;
      }
      offset = endOffset;
      return true;
    });
    return result;
  }

  /// Flattens the [TextSpan] tree into a single string.
  ///
  /// Styles are not honored in this process. If `includeSemanticsLabels` is
  /// true, then the text returned will include the [semanticsLabel]s instead of
  /// the text contents when they are present.
  String toPlainText({bool includeSemanticsLabels = true}) {
    assert(debugAssertIsValid());
    final StringBuffer buffer = StringBuffer();
    visitInlineSpan((InlineSpan span) {
      TextSpan textSpan = InlineSpan.asType<TextSpan>(span);
      if (textSpan == null)
        return true;
      if (textSpan.semanticsLabel != null && includeSemanticsLabels) {
        buffer.write(textSpan.semanticsLabel);
      } else {
        buffer.write(textSpan.text);
      }
      return true;
    });
    return buffer.toString();
  }

  /// Returns the UTF-16 code unit at the given index in the flattened string.
  ///
  /// Returns null if the index is out of bounds.
  int codeUnitAt(int index) {
    if (index < 0)
      return null;
    int offset = 0;
    int result;
    visitInlineSpan((InlineSpan span) {
      TextSpan textSpan = InlineSpan.asType<TextSpan>(span);
      if (textSpan == null)
        return true;
      if (index - offset < textSpan.text.length) {
        result = textSpan.text.codeUnitAt(index - offset);
        return false;
      }
      offset += textSpan.text.length;
      return true;
    });
    return result;
  }

  /// In checked mode, throws an exception if the object is not in a
  /// valid configuration. Otherwise, returns true.
  ///
  /// This is intended to be used as follows:
  ///
  /// ```dart
  /// assert(myTextSpan.debugAssertIsValid());
  /// ```
  bool debugAssertIsValid() {
    assert(() {
      if (!visitInlineSpan((InlineSpan span) {
        TextSpan textSpan = InlineSpan.asType<TextSpan>(span);
        if (textSpan == null)
          return true;
        if (textSpan.children != null) {
          for (InlineSpan child in textSpan.children) {
            if (child == null)
              return false;
          }
        }
        return true;
      })) {
        throw FlutterError(
          'TextSpan contains a null child.\n'
          'A TextSpan object with a non-null child list should not have any nulls in its child list.\n'
          'The full text in question was:\n'
          '${toStringDeep(prefixLineOne: '  ')}'
        );
      }
      return true;
    }());
    return true;
  }

  /// Describe the difference between this text span and another, in terms of
  /// how much damage it will make to the rendering. The comparison is deep.
  ///
  /// Comparing a [TextSpan] with a [WidgetSpan] will result in [RenderComparison.layout].
  ///
  /// See also:
  ///
  ///  * [TextStyle.compareTo], which does the same thing for [TextStyle]s.
  RenderComparison compareTo(InlineSpan other) {
    if (identical(this, other))
      return RenderComparison.identical;
    if (!(other is TextSpan))
      return RenderComparison.layout;
    TextSpan textSpan = other;
    if (textSpan.text != text ||
        children?.length != textSpan.children?.length ||
        (style == null) != (textSpan.style == null))
      return RenderComparison.layout;
    RenderComparison result = recognizer == textSpan.recognizer ? RenderComparison.identical : RenderComparison.metadata;
    if (style != null) {
      final RenderComparison candidate = style.compareTo(textSpan.style);
      if (candidate.index > result.index)
        result = candidate;
      if (result == RenderComparison.layout)
        return result;
    }
    if (children != null) {
      for (int index = 0; index < children.length; index += 1) {
        final RenderComparison candidate = children[index].compareTo(textSpan.children[index]);
        if (candidate.index > result.index)
          result = candidate;
        if (result == RenderComparison.layout)
          return result;
      }
    }
    return result;
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    final TextSpan typedOther = other;
    return typedOther.text == text
        && typedOther.style == style
        && typedOther.recognizer == recognizer
        && typedOther.semanticsLabel == semanticsLabel
        && listEquals<InlineSpan>(typedOther.children, children);
  }

  @override
  int get hashCode => hashValues(style, text, recognizer, semanticsLabel, hashList(children));

  @override
  String toStringShort() => '$runtimeType';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties.add(StringProperty('text', text, showName: false, defaultValue: null));
    if (style == null && text == null && children == null)
      properties.add(DiagnosticsNode.message('(empty)'));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    if (children == null)
      return const <DiagnosticsNode>[];
    return children.map<DiagnosticsNode>((InlineSpan child) {
      if (child != null) {
        return child.toDiagnosticsNode();
      } else {
        return DiagnosticsNode.message('<null child>');
      }
    }).toList();
  }
}
