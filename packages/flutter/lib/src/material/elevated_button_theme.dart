// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'theme.dart';

/// A [ButtonStyle] that overrides the default appearance of
/// [ElevatedButton]s when it's used with [ElevatedButtonTheme] or with the
/// overall [Theme]'s [ThemeData.ElevatedButtonTheme].
///
/// The [style]'s properties override [ElevatedButton]'s default style,
/// i.e.  the [ButtonStyle] returned by [ElevatedButton.defaultStyleOf]. Only
/// the style's non-null property values or resolved non-null
/// [MaterialStateProperty] values are used.
///
/// See also:
///
///  * [ElevatedButtonTheme], the theme which is configured with this class.
///  * [ElevatedButton.defaultStyleOf], which returns the default [ButtonStyle]
///    for text buttons.
///  * [ElevatedButton.styleOf], which converts simple values into a
///    [ButtonStyle] that's consistent with [ElevatedButton]'s defaults.
///  * [MaterialStateProperty.resolve], "resolve" a material state property
///    to a simple value based on a set of [MaterialState]s.
///  * [ThemeData.ElevatedButtonTheme], which can be used to override the default
///    [ButtonStyle] for [ElevatedButton]s below the overall [Theme].
@immutable
class ElevatedButtonThemeData with Diagnosticable {
  /// Creates an [ElevatedButtonThemeData].
  ///
  /// The [style] may be null.
  const ElevatedButtonThemeData({ this.style });

  /// Overrides for [ElevatedButton]'s default style.
  ///
  /// Non-null properties or non-null resolved [MaterialStateProperty]
  /// values override the [ButtonStyle] returned by
  /// [ElevatedButton.defaultStyleOf].
  ///
  /// If [style] is null, then this theme doesn't override anything.
  final ButtonStyle style;

  /// Linearly interpolate between two elevated button themes.
  static ElevatedButtonThemeData lerp(ElevatedButtonThemeData a, ElevatedButtonThemeData b, double t) {
    assert (t != null);
    if (a == null && b == null)
      return null;
    return ElevatedButtonThemeData(
      style: ButtonStyle.lerp(a?.style, b?.style, t),
    );
  }

  @override
  int get hashCode {
    return style.hashCode;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is ElevatedButtonThemeData && other.style == style;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
  }
}

/// Overrides the default [ButtonStyle] of its [ElevatedButton] descendants.
///
/// See also:
///
///  * [ElevatedButtonThemeData], which is used to configure this theme.
///  * [ElevatedButton.defaultStyleOf], which returns the default [ButtonStyle]
///    for elevated buttons.
///  * [ElevatedButton.styleOf], which converts simple values into a
///    [ButtonStyle] that's consistent with [ElevatedButton]'s defaults.
///  * [ThemeData.ElevatedButtonTheme], which can be used to override the default
///    [ButtonStyle] for [ElevatedButton]s below the overall [Theme].
class ElevatedButtonTheme extends InheritedTheme {
  /// Create a [ElevatedButtonTheme].
  ///
  /// The [data] parameter must not be null.
  const ElevatedButtonTheme({
    Key key,
    @required this.data,
    Widget child,
  }) : assert(data != null), super(key: key, child: child);

  /// The configuration of this theme.
  final ElevatedButtonThemeData data;

  /// The closest instance of this class that encloses the given context.
  ///
  /// If there is no enclosing [ElevatedButtonsTheme] widget, then
  /// [ThemeData.ElevatedButtonTheme] is used.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// ElevatedButtonTheme theme = ElevatedButtonTheme.of(context);
  /// ```
  static ElevatedButtonThemeData of(BuildContext context) {
    final ElevatedButtonTheme buttonTheme = context.dependOnInheritedWidgetOfExactType<ElevatedButtonTheme>();
    return buttonTheme?.data ?? Theme.of(context).elevatedButtonTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    final ElevatedButtonTheme ancestorTheme = context.findAncestorWidgetOfExactType<ElevatedButtonTheme>();
    return identical(this, ancestorTheme) ? child : ElevatedButtonTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ElevatedButtonTheme oldWidget) => data != oldWidget.data;
}


@Deprecated(
  'This class was briefly released with the wrong name. '
  'The correct name is ContainedButtonThemeData. '
  'This class was deprecated after within 24 hours of its debut.'
)
@immutable
class ContainedButtonThemeData extends ElevatedButtonThemeData {
  const ContainedButtonThemeData({ ButtonStyle style }) : super(style: style);

  static ContainedButtonThemeData lerp(ContainedButtonThemeData a, ContainedButtonThemeData b, double t) {
    return ElevatedButtonThemeData.lerp(a, b, t) as ContainedButtonThemeData;
  }
}

@Deprecated(
  'This class was briefly released with the wrong name. '
  'The correct name is ElevatedButtonTheme. '
  'This class was deprecated after within 24 hours of its debut.'
)
class ContainedButtonTheme extends ElevatedButtonTheme {
  const ContainedButtonTheme({
    Key key,
    @required ContainedButtonThemeData data,
    Widget child,
  }) : assert(data != null), super(key: key, data: data, child: child);
}
