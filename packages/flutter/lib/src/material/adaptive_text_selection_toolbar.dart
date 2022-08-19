// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

import 'desktop_text_selection_toolbar.dart';
import 'text_selection_toolbar.dart';
import 'text_selection_toolbar_buttons_builder.dart';
import 'theme.dart';

/// The default context menu for text selection for the current platform.
///
/// Typically, this widget would passed to `contextMenuBuilder` in a supported
/// parent widget, such as:
///
/// * [EditableText.contextMenuBuilder]
/// * [TextField.contextMenuBuilder]
/// * [CupertinoTextField.contextMenuBuilder]
/// * [SelectionArea.contextMenuBuilder]
/// * [SelectableText.contextMenuBuilder]
///
/// See also:
///
/// * [EditableTextContextMenuButtonItemsBuilder], which builds the
///   [ContextMenuButtonItem]s.
/// * [TextSelectionToolbarButtonsBuilder], which builds the button Widgets
///   given [ContextMenuButtonItem]s.
/// * [CupertinoAdaptiveTextSelectionToolbar], which does the same thing as this
///   widget but only for Cupertino context menus.
/// * [TextSelectionToolbar], the default toolbar for Android.
/// * [DesktopTextSelectionToolbar], the default toolbar for desktop platforms
///    other than MacOS.
/// * [CupertinoTextSelectionToolbar], the default toolbar for iOS.
/// * [CupertinoDesktopTextSelectionToolbar], the default toolbar for MacOS.
class AdaptiveTextSelectionToolbar extends StatelessWidget {
  /// Create an instance of [AdaptiveTextSelectionToolbar] with the
  /// given [children].
  ///
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.constructor.editableText}
  /// To adaptively generate the default buttons for [EditableText] for the
  /// current platform, use [AdaptiveTextSelectionToolbar.editableText].
  /// {@endtemplate}
  ///
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.constructor.selectableRegion}
  /// To adaptively generate the default buttons for [SelectableRegion] for the
  /// current platform, use [AdaptiveTextSelectionToolbar.selectableRegion].
  /// {@endtemplate}
  ///
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.constructor.buttonItems}
  /// To specify the button labels and callbacks but still adaptively generate
  /// the look of the buttons based on the current platform, use
  /// [AdaptiveTextSelectionToolbar.buttonItems].
  /// {@endtemplate}
  const AdaptiveTextSelectionToolbar({
    super.key,
    required this.children,
    required this.primaryAnchor,
    this.secondaryAnchor,
  }) : buttonItems = null,
       editableTextState = null,
       selectableRegionState = null;

  /// Create an instance of [AdaptiveTextSelectionToolbar] and
  /// adaptively generate the buttons based on the current platform and the
  /// given [editableTextState].
  ///
  /// {@template flutter.material.AdaptiveTextSelectionToolbar}
  /// To specify the [children] widgets directly, use the main constructor
  /// [AdaptiveTextSelectionToolbar.AdaptiveTextSelectionToolbar].
  /// {@endtemplate}
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.constructor.selectableRegion}
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.constructor.buttonItems}
  ///
  /// See also:
  ///
  ///  * [EditableTextContextMenuButtonItemsBuilder], which builds the default
  ///    [ContextMenuButtonItem]s for [EditableText] on the platform.
  const AdaptiveTextSelectionToolbar.editableText({
    super.key,
    required this.editableTextState,
    required this.primaryAnchor,
    this.secondaryAnchor,
  }) : buttonItems = null,
       children = null,
       selectableRegionState = null;

  /// Create an instance of [AdaptiveTextSelectionToolbar] and
  /// adaptively generate the buttons based on the current platform and the
  /// given [selectableRegionState].
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar}
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editableText}
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.constructor.buttonItems}
  ///
  /// See also:
  ///
  ///  * [SelectableRegionContextMenuButtonItemsBuilder], which builds the
  ///    default [ContextMenuButtonItem]s for [SelectableRegion] on the
  ///    current platform.
  const AdaptiveTextSelectionToolbar.selectableRegion({
    super.key,
    required this.selectableRegionState,
    required this.primaryAnchor,
    this.secondaryAnchor,
  }) : buttonItems = null,
       children = null,
       editableTextState = null;

  /// Create an instance of [AdaptiveTextSelectionToolbar] and
  /// adaptively generate the buttons based on the current platform and
  /// [buttonItems].
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar}
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.constructor.editableText}
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.constructor.selectableRegion}
  ///
  /// See also:
  ///
  ///  * [SelectableRegionContextMenuButtonItemsBuilder], which can be used to
  ///    build the default [ContextMenuButtonType]s for a [SelectableRegion].
  ///  * [EditableTextContextMenuButtonItemsBuilder], which can be used to
  ///    build the default [ContextMenuButtonType]s for an [EditableText].
  const AdaptiveTextSelectionToolbar.buttonItems({
    super.key,
    required this.buttonItems,
    required this.primaryAnchor,
    this.secondaryAnchor,
  }) : children = null,
       editableTextState = null,
       selectableRegionState = null;

  /// {@template flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// The data that will be used to adaptively generate each child button of the
  /// menu when using [AdaptiveTextSelectionToolbar.buttonItems].
  /// {@endtemplate}
  final List<ContextMenuButtonItem>? buttonItems;

  /// The children of the toolbar, typically buttons, when using the main
  /// [AdaptiveTextSelectionToolbar.new] constructor.
  final List<Widget>? children;

  /// Used to adaptively generate the default buttons for this
  /// [EditableTextState] on the current platform when using the
  /// [AdaptiveTextSelectionToolbar.editableText] constructor.
  final EditableTextState? editableTextState;

  /// Used to adaptively generate the default buttons for this
  /// [SelectableRegionState] on the current platform when using the
  /// [AdaptiveTextSelectionToolbar.selectableRegion] constructor.
  final SelectableRegionState? selectableRegionState;

  /// {@template flutter.material.AdaptiveTextSelectionToolbar.primaryAnchor}
  /// The main location on which to anchor the menu.
  ///
  /// Optionally, [secondaryAnchor] can be provided as an alternative anchor
  /// location if the menu doesn't fit here.
  /// {@endtemplate}
  final Offset primaryAnchor;

  /// {@template flutter.material.AdaptiveTextSelectionToolbar.secondaryAnchor}
  /// The optional secondary location on which to anchor the menu, if it doesn't
  /// fit at [primaryAnchor].
  /// {@endtemplate}
  final Offset? secondaryAnchor;

  @override
  Widget build(BuildContext context) {
    // If there aren't any buttons to build, build an empty toolbar.
    if ((children?.isEmpty ?? false) || (buttonItems?.isEmpty ?? false)) {
      return const SizedBox(width: 0.0, height: 0.0);
    }

    if (children?.isNotEmpty ?? false) {
      return _AdaptiveTextSelectionToolbarFromChildren(
        primaryAnchor: primaryAnchor,
        secondaryAnchor: secondaryAnchor,
        children: children!,
      );
    }

    if (buttonItems?.isNotEmpty ?? false) {
      return _AdaptiveTextSelectionToolbarFromButtonItems(
        primaryAnchor: primaryAnchor,
        secondaryAnchor: secondaryAnchor,
        buttonItems: buttonItems!,
      );
    }

    if (selectableRegionState != null) {
      return SelectableRegionContextMenuButtonItemsBuilder(
        selectableRegionState: selectableRegionState!,
        builder: (BuildContext context, List<ContextMenuButtonItem> buttonItems) {
          return AdaptiveTextSelectionToolbar.buttonItems(
            primaryAnchor: primaryAnchor,
            secondaryAnchor: secondaryAnchor,
            buttonItems: buttonItems,
          );
        },
      );
    }

    return EditableTextContextMenuButtonItemsBuilder(
      editableTextState: editableTextState!,
      builder: (BuildContext context, List<ContextMenuButtonItem> buttonItems) {
        return _AdaptiveTextSelectionToolbarFromButtonItems(
          primaryAnchor: primaryAnchor,
          secondaryAnchor: secondaryAnchor,
          buttonItems: buttonItems,
        );
      },
    );
  }
}

/// The default text selection toolbar by platform given the [children] for the
/// platform.
class _AdaptiveTextSelectionToolbarFromChildren extends StatelessWidget {
  const _AdaptiveTextSelectionToolbarFromChildren({
    required this.primaryAnchor,
    this.secondaryAnchor,
    required this.children,
  }) : assert(children != null);

  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.primaryAnchor}
  final Offset primaryAnchor;

  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.secondaryAnchor}
  final Offset? secondaryAnchor;

  /// The children of the toolbar, typically buttons.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // If there aren't any buttons to build, build an empty toolbar.
    if (children.isEmpty) {
      return const SizedBox(width: 0.0, height: 0.0);
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        return CupertinoTextSelectionToolbar(
          anchorAbove: primaryAnchor,
          anchorBelow: secondaryAnchor == null ? primaryAnchor : secondaryAnchor!,
          children: children,
        );
      case TargetPlatform.android:
        return TextSelectionToolbar(
          anchorAbove: primaryAnchor,
          anchorBelow: secondaryAnchor == null ? primaryAnchor : secondaryAnchor!,
          children: children,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return DesktopTextSelectionToolbar(
          anchor: primaryAnchor,
          children: children,
        );
      case TargetPlatform.macOS:
        return CupertinoDesktopTextSelectionToolbar(
          anchor: primaryAnchor,
          children: children,
        );
    }
  }
}

/// The default text selection toolbar by platform given [buttonItems]
/// representing the children for the platform.
class _AdaptiveTextSelectionToolbarFromButtonItems extends StatelessWidget {
  const _AdaptiveTextSelectionToolbarFromButtonItems({
    required this.primaryAnchor,
    this.secondaryAnchor,
    required this.buttonItems,
  }) : assert(buttonItems != null);

  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.primaryAnchor}
  final Offset primaryAnchor;

  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.secondaryAnchor}
  final Offset? secondaryAnchor;

  /// The information needed to create each child button of the menu.
  final List<ContextMenuButtonItem> buttonItems;

  @override
  Widget build(BuildContext context) {
    // If there aren't any buttons to build, build an empty toolbar.
    if (buttonItems.isEmpty) {
      return const SizedBox(width: 0.0, height: 0.0);
    }

    return TextSelectionToolbarButtonsBuilder(
      buttonItems: buttonItems,
      builder: (BuildContext context, List<Widget> children) {
        return _AdaptiveTextSelectionToolbarFromChildren(
          primaryAnchor: primaryAnchor,
          secondaryAnchor: secondaryAnchor,
          children: children,
        );
      },
    );
  }
}
