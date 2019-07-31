// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Defines the visual properties of [MaterialBanner] widgets.
///
/// Descendant widgets obtain the current [MaterialBannerThemeData] object using
/// `MaterialBannerTheme.of(context)`. Instances of [MaterialBannerThemeData]
/// can be customized with [MaterialBannerThemeData.copyWith].
///
/// Typically a [MaterialBannerThemeData] is specified as part of the overall
/// [Theme] with [ThemeData.bannerTheme].
///
/// All [MaterialBannerThemeData] properties are `null` by default. When null,
/// the [MaterialBanner] will provide its own defaults.
///
/// See also:
///
///  * [ThemeData], which describes the overall theme information for the
///    application.
class MaterialBannerThemeData extends Diagnosticable {

  /// Creates a theme that can be used for [ThemeData.bannerTheme].
  const MaterialBannerThemeData({
    this.backgroundColor,
    this.contentTextStyle,
  });

  /// The background color of a [MaterialBanner].
  final Color backgroundColor;

  /// Used to configure the [DefaultTextStyle] for the [MaterialBanner.content]
  /// widget.
  final TextStyle contentTextStyle;

  /// Creates a copy of this object with the given fields replaced with the
  /// new values.
  MaterialBannerThemeData copyWith({
    Color backgroundColor,
    TextStyle contentTextStyle,
  }) {
    return MaterialBannerThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      contentTextStyle: contentTextStyle ?? this.contentTextStyle,
    );
  }

  /// Linearly interpolate between two Card themes.
  ///
  /// The argument `t` must not be null.
  ///
  /// {@macro dart.ui.shadow.lerp}
  static MaterialBannerThemeData lerp(MaterialBannerThemeData a, MaterialBannerThemeData b, double t) {
    assert(t != null);
    return MaterialBannerThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      contentTextStyle: TextStyle.lerp(a?.contentTextStyle, b?.contentTextStyle, t),
    );
  }

  @override
  int get hashCode {
    return hashValues(
      backgroundColor,
      contentTextStyle,
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    final MaterialBannerThemeData typedOther = other;
    return typedOther.backgroundColor == backgroundColor
        && typedOther.contentTextStyle == contentTextStyle;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('contentTextStyle', contentTextStyle, defaultValue: null));
  }
}

/// An inherited widget that defines the configuration for
/// [MaterialBanner]s in this widget's subtree.
///
/// Values specified here are used for [MaterialBanner] properties that are not
/// given an explicit non-null value.
class MaterialBannerTheme extends InheritedWidget {
  /// Creates a banner theme that controls the configurations for
  /// [MaterialBanner]s in its widget subtree.
  const MaterialBannerTheme({
    Key key,
    this.data,
    Widget child,
  }) : super(key: key, child: child);

  /// The properties for descendant [MaterialBanner] widgets.
  final MaterialBannerThemeData data;

  /// The closest instance of this class' [data] value that encloses the given
  /// context.
  ///
  /// If there is no ancestor, it returns [ThemeData.bannerTheme]. Applications
  /// can assume that the returned value will not be null.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// MaterialBannerThemeData theme = MaterialBannerTheme.of(context);
  /// ```
  static MaterialBannerThemeData of(BuildContext context) {
    final MaterialBannerTheme popupMenuTheme = context.inheritFromWidgetOfExactType(MaterialBannerTheme);
    return popupMenuTheme?.data ?? Theme.of(context).bannerTheme;
  }

  @override
  bool updateShouldNotify(MaterialBannerTheme oldWidget) => data != oldWidget.data;
}
