// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'scrollbar.dart';

// TODO(abarth): These constants probably belong somewhere more general.

const TextStyle _kCupertinoDialogTitleStyle = const TextStyle(
  fontFamily: '.SF UI Display',
  inherit: false,
  fontSize: 18.0,
  fontWeight: FontWeight.w500,
  color: CupertinoColors.black,
  height: 1.06,
  letterSpacing: 0.48,
  textBaseline: TextBaseline.alphabetic,
);

const TextStyle _kCupertinoDialogContentStyle = const TextStyle(
  fontFamily: '.SF UI Text',
  inherit: false,
  fontSize: 13.4,
  fontWeight: FontWeight.w300,
  color: CupertinoColors.black,
  height: 1.036,
  textBaseline: TextBaseline.alphabetic,
);

const TextStyle _kCupertinoDialogActionStyle = const TextStyle(
  fontFamily: '.SF UI Text',
  inherit: false,
  fontSize: 16.8,
  fontWeight: FontWeight.w400,
  color: CupertinoColors.activeBlue,
  textBaseline: TextBaseline.alphabetic,
);

const double _kCupertinoDialogWidth = 270.0;

// _kCupertinoDialogBlurOverlayDecoration is applied to the blurred backdrop to
// lighten the blurred image. Brightening is done to counteract the dark modal
// barrier that appears behind the dialog. The overlay blend mode does the
// brightening. The white color doesn't paint any white, it's just the basis
// for the overlay blend mode.
const BoxDecoration _kCupertinoDialogBlurOverlayDecoration = const BoxDecoration(
  color: CupertinoColors.white,
  backgroundBlendMode: BlendMode.overlay,
);

const double _kEdgePadding = 20.0;
const double _kButtonHeight = 45.0;
const double _kDialogCornerRadius = 12.0;

// _kDialogColor is a translucent white that is painted on top of the blurred
// backdrop.
const Color _kDialogColor = const Color(0xC0FFFFFF);
const Color _kButtonDividerColor = const Color(0x20000000);

/// An iOS-style dialog.
///
/// This dialog widget does not have any opinion about the contents of the
/// dialog. Rather than using this widget directly, consider using
/// [CupertinoAlertDialog], which implement a specific kind of dialog.
///
/// Push with `Navigator.of(..., rootNavigator: true)` when using with
/// [CupertinoTabScaffold] to ensure that the dialog appears above the tabs.
///
/// See also:
///
///  * [CupertinoAlertDialog], which is a dialog with title, contents, and
///    actions.
///  * <https://developer.apple.com/ios/human-interface-guidelines/views/alerts/>
class CupertinoDialog extends StatelessWidget {
  /// Creates an iOS-style dialog.
  const CupertinoDialog({
    Key key,
    this.child,
  }) : super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new ClipRRect(
        borderRadius: BorderRadius.circular(_kDialogCornerRadius),
        child: new BackdropFilter(
          filter: new ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: new Container(
            width: _kCupertinoDialogWidth,
            decoration: _kCupertinoDialogBlurOverlayDecoration,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// An iOS-style alert dialog.
///
/// An alert dialog informs the user about situations that require
/// acknowledgement. An alert dialog has an optional title, optional content,
/// and an optional list of actions. The title is displayed above the content
/// and the actions are displayed below the content.
///
/// This dialog styles its title and content (typically a message) to match the
/// standard iOS title and message dialog text style. These default styles can
/// be overridden by explicitly defining [TextStyle]s for [Text] widgets that
/// are part of the title or content.
///
/// To display action buttons that look like standard iOS dialog buttons,
/// provide [CupertinoDialogAction]s for the [actions] given to this dialog.
///
/// Typically passed as the child widget to [showDialog], which displays the
/// dialog.
///
/// See also:
///
///  * [CupertinoDialog], which is a generic iOS-style dialog.
///  * [CupertinoDialogAction], which is an iOS-style dialog button.
///  * <https://developer.apple.com/ios/human-interface-guidelines/views/alerts/>
class CupertinoAlertDialog extends StatelessWidget {
  /// Creates an iOS-style alert dialog.
  ///
  /// The [actions] must not be null.
  const CupertinoAlertDialog({
    Key key,
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.scrollController,
    this.actionScrollController,
  })  : assert(actions != null),
        super(key: key);

  /// The (optional) title of the dialog is displayed in a large font at the top
  /// of the dialog.
  ///
  /// Typically a [Text] widget.
  final Widget title;

  /// The (optional) content of the dialog is displayed in the center of the
  /// dialog in a lighter font.
  ///
  /// Typically a [Text] widget.
  final Widget content;

  /// The (optional) set of actions that are displayed at the bottom of the
  /// dialog.
  ///
  /// Typically this is a list of [CupertinoDialogAction] widgets.
  final List<Widget> actions;

  /// A scroll controller that can be used to control the scrolling of the
  /// [content] in the dialog.
  ///
  /// Defaults to null, and is typically not needed, since most alert messages
  /// are short.
  ///
  /// See also:
  ///
  ///  * [actionScrollController], which can be used for controlling the actions
  ///    section when there are many actions.
  final ScrollController scrollController;

  /// A scroll controller that can be used to control the scrolling of the
  /// actions in the dialog.
  ///
  /// Defaults to null, and is typically not needed.
  ///
  /// See also:
  ///
  ///  * [scrollController], which can be used for controlling the [content]
  ///    section when it is long.
  final ScrollController actionScrollController;

  Widget _buildContent() {
    final List<Widget> children = <Widget>[];

    if (title != null || content != null) {
      final Widget titleSection = new _CupertinoAlertContentSection(
        title: title,
        content: content,
        scrollController: scrollController,
      );
      children.add(new Flexible(flex: 3, child: titleSection));
      // Add padding between the sections.
      children.add(const Padding(padding: const EdgeInsets.only(top: 8.0)));
    }

    return new Container(
      key: const Key('cupertino_alert_dialog_content_section'),
      color: _kDialogColor,
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildActions() {
    Widget actionSection = new Container(
      height: 0.0,
    );
    if (actions.isNotEmpty) {
      actionSection = new _CupertinoAlertActionSection(
        children: actions,
        scrollController: actionScrollController,
      );
    }

    return actionSection;
  }

  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new Container(
        margin: const EdgeInsets.symmetric(vertical: _kEdgePadding),
        width: _kCupertinoDialogWidth,
        // The following clip is critical. The BackdropFilter needs to have
        // rounded corners, but SKIA cannot internally create a rounded rect
        // shape. Therefore, we have no choice but to clip, ourselves.
        child: ClipRRect(
          key: const Key('cupertino_alert_dialog_modal'),
          borderRadius: BorderRadius.circular(_kDialogCornerRadius),
          child: new BackdropFilter(
            filter: new ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: new Container(
              decoration: _kCupertinoDialogBlurOverlayDecoration,
              child: new _CupertinoDialogRenderWidget(
                isStacked: actions.length > 2,
                children: <Widget>[
                  new BaseLayoutId<_CupertinoDialogRenderWidget, MultiChildLayoutParentData>(
                    id: _AlertDialogSections.contentSection,
                    child: _buildContent(),
                  ),
                  new BaseLayoutId<_CupertinoDialogRenderWidget, MultiChildLayoutParentData>(
                    id: _AlertDialogSections.actionsSection,
                    child: _buildActions(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// iOS style layout policy widget for sizing an alert dialog's content section and
// action button section.
//
// The sizing policy is partially determined by whether or not action buttons
// are stacked vertically, or positioned horizontally. [isStacked] is used to
// indicate whether or not the buttons should be stacked vertically.
//
// See [_RenderCupertinoDialog] for specific layout policy details.
class _CupertinoDialogRenderWidget extends MultiChildRenderObjectWidget {
  _CupertinoDialogRenderWidget({
    Key key,
    @required List<Widget> children,
    bool isStacked = false,
  }) : super(key: key, children: children);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return new _RenderCupertinoDialog();
  }

  @override
  void updateRenderObject(BuildContext context, _RenderCupertinoDialog renderObject) {
    // NO-OP
  }
}

// iOS style layout policy for sizing an alert dialog's content section and action
// button section.
//
// The policy is as follows:
//
// If all content and buttons fit on screen:
// The content section and action button section are sized intrinsically and centered
// vertically on screen.
//
// If all content and buttons do not fit on screen:
// A minimum height for the action button section is calculated. The action
// button section will not be rendered shorter than this minimum.  See
// [_RenderCupertinoDialogActions] for the minimum height calculation.
//
// With the minimum action button section calculated, the content section is
// laid out as tall as it wants to be, up to the point that it hits the
// minimum button height at the bottom.
//
// After the content section is laid out, the action button section is allowed
// to take up any remaining space that was not consumed by the content section.
class _RenderCupertinoDialog extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
    RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  _RenderCupertinoDialog({
    RenderBox contentSection,
    RenderBox actionsSection,
    bool isStacked = false,
  }) {
    if (null != contentSection) {
      add(contentSection);
    }
    if (null != actionsSection) {
      add(actionsSection);
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData)
      child.parentData = new MultiChildLayoutParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _kCupertinoDialogWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _kCupertinoDialogWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    print('Dialog computeMinIntrinsicHeight(width: $width)');
    // Obtain references to the specific children we need lay out.
    final _DialogChildren dialogChildren = _findDialogChildren();
    final RenderBox content = dialogChildren.content;
    final RenderBox actions = dialogChildren.actions;

    final double contentHeight = content.getMinIntrinsicHeight(width);
    final double actionsHeight = actions.getMinIntrinsicHeight(width);
    final double height = contentHeight + actionsHeight;
    print('Computing overall dialog heights. Content: $contentHeight, Actions: $actionsHeight, Height: $height');

    if (height.isFinite)
      return height;
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    print('Dialog computeMaxIntrinsicHeight(width: $width)');
    // Obtain references to the specific children we need lay out.
    final _DialogChildren dialogChildren = _findDialogChildren();
    final RenderBox content = dialogChildren.content;
    final RenderBox actions = dialogChildren.actions;

    final double contentHeight = content.getMaxIntrinsicHeight(width);
    final double actionsHeight = actions.getMaxIntrinsicHeight(width);
    final double height = contentHeight + actionsHeight;
    print('Computing overall dialog heights. Content: $contentHeight, Actions: $actionsHeight, Height: $height');

    if (height.isFinite)
      return height;
    return 0.0;
  }

  @override
  void performLayout() {
    // Obtain references to the specific children we need lay out.
    final _DialogChildren dialogChildren = _findDialogChildren();
    final RenderBox content = dialogChildren.content;
    final RenderBox actions = dialogChildren.actions;

    final double minActionsHeight = actions.getMinIntrinsicHeight(constraints.maxWidth);

    final Size maxDialogSize = constraints.biggest;

    // Size alert dialog content.
    content.layout(
      constraints.deflate(new EdgeInsets.only(bottom: minActionsHeight)),
      parentUsesSize: true,
    );
    final Size contentSize = content.size;

    // Size alert dialog actions.
    actions.layout(
      constraints.deflate(new EdgeInsets.only(top: contentSize.height)),
      parentUsesSize: true,
    );
    final Size actionsSize = actions.size;

    // Calculate overall dialog height.
    final double dialogHeight = contentSize.height + actionsSize.height;

    // Set our size now that layout calculations are complete.
    size = new Size(maxDialogSize.width, dialogHeight);

    // Set the position of the actions box to sit at the bottom of the dialog.
    // The content box defaults to the top left, which is where we want it.
    assert(actions.parentData is MultiChildLayoutParentData);
    final MultiChildLayoutParentData actionParentData = actions.parentData;
    actionParentData.offset = new Offset(0.0, contentSize.height);
  }

  _DialogChildren _findDialogChildren() {
    RenderBox content;
    RenderBox actions;
    final List<RenderBox> children = getChildrenAsList();
    for (RenderBox child in children) {
      final MultiChildLayoutParentData parentData = child.parentData;
      if (parentData.id == _AlertDialogSections.contentSection) {
        content = child;
      } else if (parentData.id == _AlertDialogSections.actionsSection) {
        actions = child;
      }
    }
    assert(content != null);
    assert(actions != null);

    return new _DialogChildren(
      content: content,
      actions: actions,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(HitTestResult result, { Offset position }) {
    return defaultHitTestChildren(result, position: position);
  }
}

// Visual components of an alert dialog that need to be explicitly sized and
// laid out at runtime.
enum _AlertDialogSections {
  contentSection,
  actionsSection,
}

// Data structure used to pass around references to multiple dialog pieces for
// layout calculations.
class _DialogChildren {
  final RenderBox content;
  final RenderBox actions;

  _DialogChildren({
    this.content,
    this.actions,
  });
}

// The "content section" of a CupertinoAlertDialog.
//
// If title is missing, then only content is added.  If content is
// missing, then only title is added. If both are missing, then it returns
// a SingleChildScrollView with a zero-sized Container.
class _CupertinoAlertContentSection extends StatelessWidget {
  const _CupertinoAlertContentSection({
    Key key,
    this.title,
    this.content,
    this.scrollController,
  }) : super(key: key);

  // The (optional) title of the dialog is displayed in a large font at the top
  // of the dialog.
  //
  // Typically a Text widget.
  final Widget title;

  // The (optional) content of the dialog is displayed in the center of the
  // dialog in a lighter font.
  //
  // Typically a Text widget.
  final Widget content;

  // A scroll controller that can be used to control the scrolling of the
  // content in the dialog.
  //
  // Defaults to null, and is typically not needed, since most alert contents
  // are short.
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final List<Widget> titleContentGroup = <Widget>[];
    if (title != null) {
      titleContentGroup.add(new Padding(
        padding: new EdgeInsets.only(
          left: _kEdgePadding,
          right: _kEdgePadding,
          bottom: content == null ? _kEdgePadding : 1.0,
          top: _kEdgePadding,
        ),
        child: new DefaultTextStyle(
          style: _kCupertinoDialogTitleStyle,
          textAlign: TextAlign.center,
          child: title,
        ),
      ));
    }

    if (content != null) {
      titleContentGroup.add(
        new Padding(
          padding: new EdgeInsets.only(
            left: _kEdgePadding,
            right: _kEdgePadding,
            bottom: _kEdgePadding,
            top: title == null ? _kEdgePadding : 1.0,
          ),
          child: new DefaultTextStyle(
            style: _kCupertinoDialogContentStyle,
            textAlign: TextAlign.center,
            child: content,
          ),
        ),
      );
    }

    if (titleContentGroup.isEmpty) {
      return new SingleChildScrollView(
        controller: scrollController,
        child: new Container(width: 0.0, height: 0.0),
      );
    }

    // Add padding between the widgets if necessary.
    if (titleContentGroup.length > 1) {
      titleContentGroup.insert(1, const Padding(padding: const EdgeInsets.only(top: 8.0)));
    }

    return new CupertinoScrollbar(
      child: new SingleChildScrollView(
        controller: scrollController,
        child: new Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: titleContentGroup,
        ),
      ),
    );
  }
}

/// A button typically used in a [CupertinoAlertDialog].
///
/// See also:
///
///  * [CupertinoAlertDialog], a dialog that informs the user about situations
///    that require acknowledgement
class CupertinoDialogAction extends StatelessWidget {
  /// Creates an action for an iOS-style dialog.
  const CupertinoDialogAction({
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    @required this.child,
  }) : assert(child != null);

  /// The callback that is called when the button is tapped or otherwise
  /// activated.
  ///
  /// If this is set to null, the button will be disabled.
  final VoidCallback onPressed;

  /// Set to true if button is the default choice in the dialog.
  ///
  /// Default buttons are bold.
  final bool isDefaultAction;

  /// Whether this action destroys an object.
  ///
  /// For example, an action that deletes an email is destructive.
  final bool isDestructiveAction;

  /// The widget below this widget in the tree.
  ///
  /// Typically a [Text] widget.
  final Widget child;

  /// Whether the button is enabled or disabled. Buttons are disabled by
  /// default. To enable a button, set its [onPressed] property to a non-null
  /// value.
  bool get enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    TextStyle style = _kCupertinoDialogActionStyle;

    if (isDefaultAction) {
      style = style.copyWith(fontWeight: FontWeight.w600);
    }

    if (isDestructiveAction) {
      style = style.copyWith(color: CupertinoColors.destructiveRed);
    }

    if (!enabled) {
      style = style.copyWith(color: style.color.withOpacity(0.5));
    }

    final double textScaleFactor = MediaQuery.textScaleFactorOf(context);
    return new GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: new ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: _kButtonHeight,
        ),
        child: new Container(
          alignment: Alignment.center,
          padding: new EdgeInsets.all(8.0 * textScaleFactor),
          child: new DefaultTextStyle(
            style: style,
            child: child,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// The "actions section" of a [CupertinoAlertDialog].
//
// If _layoutActionsVertically is true, they are laid out vertically
// in a column; else they are laid out horizontally in a row. If there isn't
// enough room to show all the children vertically, they are wrapped in a
// CupertinoScrollbar widget. If children is null or empty, it returns null.
class _CupertinoAlertActionSection extends StatelessWidget {
  const _CupertinoAlertActionSection({
    Key key,
    @required this.children,
    this.scrollController,
  })  : assert(children != null),
        super(key: key);

  final List<Widget> children;

  // A scroll controller that can be used to control the scrolling of the
  // actions in the dialog.
  //
  // Defaults to null, and is typically not needed, since most alert dialogs
  // don't have many actions.
  final ScrollController scrollController;

  Widget _buildDialogButton(Widget buttonContent) {
    return Container(
      color: _kDialogColor,
      child: buttonContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    final List<Widget> buttons = children.map((Widget buttonContent) {
      return _buildDialogButton(buttonContent);
    }).toList();

    return new CupertinoScrollbar(
      child: new SingleChildScrollView(
        controller: scrollController,
        child: new _CupertinoDialogActionsRenderWidget(
          dividerWidth: 1.0 / devicePixelRatio,
          children: buttons,
        ),
      ),
    );
  }
}

// iOS style layout policy widget for sizing action buttons.
//
// The sizing policy is partially determined by whether or not action buttons
// are stacked vertically, or positioned horizontally. [isStacked] is used to
// indicate whether or not the buttons should be stacked vertically.
//
// See [_RenderCupertinoDialogActions] for specific layout policy details.
//
// Usage instructions:
//
// When stacked vertically:
// The entire actions section (all buttons and dividers) should be a single
// grandchild of this widget, and it should be wrapped with a
// [BaseLayoutId<_CupertinoDialogActionsRenderWidget, MultiChildLayoutParentData>]
// whose ID is [_AlertDialogPieces.actionsSection].
//
// Also, the entire list of buttons and dividers should also be passed as
// direct children of this widget in the order they appear: divider, button,
// divider, button. The order is critical and the layout will break if that
// exact order is not respected.
//
// Vertical example:
//
// ```
// new _CupertinoDialogActionsRenderWidget(
//   isStacked: true,
//   children: <Widget>[
//     new BaseLayoutId<_CupertinoDialogActionsRenderWidget, MultiChildLayoutParentData>(
//       id: _AlertDialogPieces.actionsSection,
//       child: actionsSection,
//     ),
//   ]..addAll(buttons),
// );
// ```
//
// When displayed horizontally:
// The entire actions section (all buttons, dividers, etc) should be a single
// grandchild of this widget, and it should be wrapped with a
// [BaseLayoutId<_CupertinoDialogActionsRenderWidget, MultiChildLayoutParentData>]
// whose ID is [_AlertDialogPieces.actionsSection].
//
// Also, the single actions section widget that is a child of [BaseLayoutId] should
// also be passed to this widget as a direct child. The reason to pass it a 2nd
// time is to allow this widget to explicitly measure the actions section.
//
// Horizontal example:
//
// ```
// new _CupertinoDialogActionsRenderWidget(
//   isStacked: false,
//   children: <Widget>[
//     new BaseLayoutId<_CupertinoDialogActionsRenderWidget, MultiChildLayoutParentData>(
//       id: _AlertDialogPieces.actionsSection,
//       child: actionsSection,
//     actionsSection,
//   ],
// );
// ```
class _CupertinoDialogActionsRenderWidget extends MultiChildRenderObjectWidget {
  _CupertinoDialogActionsRenderWidget({
    Key key,
    @required List<Widget> children,
    double dividerWidth = 0.0,
  }) : _dividerWidth = dividerWidth,
        super(key: key, children: children);

  final double _dividerWidth;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return new _RenderCupertinoDialogActions(
      dividerWidth: _dividerWidth,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderCupertinoDialogActions renderObject) {
    renderObject.dividerWidth = _dividerWidth;
  }
  
}

// iOS style layout policy for sizing an alert dialog's action buttons.
//
// The policy is as follows:
//
// If buttons are stacked (see [isStacked]), a minimum intrinsic height is
// reported that equals the height of the first button + 50% the height of
// the second button. The policy, more generally, is 1.5x button height, but
// it's possible that buttons are of different heights, so this policy measures
// the first 2 buttons directly. This policy reflects how iOS stacks buttons
// in an alert dialog. By exposing 50% of the 2nd button, the dialog makes it
// clear that there are more buttons "below the fold".
//
// If buttons are not stacked, then they appear in a horizontal row. In that
// case the minimum and maximum intrinsic height is set to the height of the
// button(s) in the row.
//
// [_RenderCupertinoDialogActions] has specific usage requirements. See
// [_CupertinoDialogActionsRenderWidget] for information about the type and
// order of expected child widgets.
class _RenderCupertinoDialogActions extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  _RenderCupertinoDialogActions({
    List<RenderBox> children,
    double dividerWidth = 0.0,
  }) : _dividerWidth = dividerWidth {
    addAll(children);
  }

  double _dividerWidth;

  double get dividerWidth => _dividerWidth;

  set dividerWidth(double newValue) {
    if (newValue == _dividerWidth) {
      return;
    }

    _dividerWidth = newValue;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData)
      child.parentData = new MultiChildLayoutParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _kCupertinoDialogWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _kCupertinoDialogWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    print('Dialog Actions: computeMinIntrinsicHeight(width: $width)');
    if (childCount == 0) {
      print(' - No children. Height: 0.0');
      return 0.0;
    } else if (childCount == 1) {
      // If only 1 child
      print(' - 1 child. Height: ${_computeMinIntrinsicHeightSideBySide(width)}');
      return _computeMinIntrinsicHeightSideBySide(width);
    } else {
      final List<RenderBox> children = getChildrenAsList();

      if (children.length == 2) {
        if (_isSingleButtonRow(width)) {
          // The first 2 buttons fit side-by-side. Display them horizontally.
          print(' - 2 children that fit side-by-side. Height: ${_computeMinIntrinsicHeightSideBySide(width)}');
          return _computeMinIntrinsicHeightSideBySide(width);
        } else {
          // The first 2 buttons do not fit side-by-side. Display them stacked.
          // The minimum height for 2 buttons when stacked is the minimum height
          // of both buttons + dividers (no scrolling for 2 buttons).
          print(' - 2 children that need to stack. Height: ${_computeMinIntrinsicHeightForTwoStackedButtons(width)}');
          return _computeMinIntrinsicHeightForTwoStackedButtons(width);
        }
      } else {
        // 3+ buttons are always stacked. The minimum height when stacked is
        // 1.5 buttons tall.
        print(' - 3+ children. Height: ${_computeMinIntrinsicHeightStacked(width)}');
        return _computeMinIntrinsicHeightStacked(width);
      }
    }
  }

  double _computeMinIntrinsicHeightSideBySide(double width) {
    assert(childCount <= 2);

    // Min intrinsic height is the larger of the button min intrinsic heights +
    // the width of a divider that appears above all buttons.
    if (childCount == 1) {
      return firstChild.computeMinIntrinsicHeight(width) + dividerWidth;
    } else {
      final double perButtonWidth = (width - dividerWidth) / 2.0;
      return max(
        firstChild.computeMinIntrinsicHeight(perButtonWidth) + dividerWidth,
        lastChild.computeMinIntrinsicHeight(perButtonWidth) + dividerWidth,
      );
    }
  }

  double _computeMinIntrinsicHeightForTwoStackedButtons(double width) {
    assert(childCount == 2);

    return (2 * dividerWidth)
        + firstChild.computeMinIntrinsicHeight(width)
        + lastChild.computeMinIntrinsicHeight(width);
  }

  double _computeMinIntrinsicHeightStacked(double width) {
    assert(childCount >= 3);

    final List<RenderBox> children = getChildrenAsList();
    return (2 * dividerWidth)
        + children[0].computeMinIntrinsicHeight(width)
        + (0.5 * children[1].computeMinIntrinsicHeight(width));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    print('Dialog Actions: computeMaxIntrinsicHeight(width: $width)');
    if (childCount == 0) {
      // No buttons. Zero height.
      print(' - No children. Height: 0.0');
      return 0.0;
    } else if (childCount == 1) {
      // One button. Our max intrinsic height is equal to the button's.
      print(' - 1 child. Height: ${firstChild.computeMaxIntrinsicHeight(width)}');
      return firstChild.computeMaxIntrinsicHeight(width) + dividerWidth;
    } else if (childCount == 2) {
      // Two buttons...
      if (_isSingleButtonRow(width)) {
        // The 2 buttons fit side by side so our max intrinsic height is equal
        // to the taller of the 2 buttons.
        final double perButtonWidth = (width - dividerWidth) / 2.0;
        print(' - 2 children that fit side-by-side. Height: ${max(
          firstChild.computeMaxIntrinsicHeight(perButtonWidth),
          lastChild.computeMaxIntrinsicHeight(perButtonWidth),
        )}');
        return max(
          firstChild.computeMaxIntrinsicHeight(perButtonWidth),
          lastChild.computeMaxIntrinsicHeight(perButtonWidth),
        ) + dividerWidth;
      } else {
        // The 2 buttons do not fit side by side. Measure total height as a
        // vertical stack.
        print(' - 2 children that need to stack. Height: ${_computeMaxIntrinsicHeightStacked(width)}');
        return _computeMaxIntrinsicHeightStacked(width);
      }
    } else {
      // Three+ buttons. Stack the buttons vertically with dividers and measure
      // the overall height.
      print(' - 3+ children. Height: ${_computeMaxIntrinsicHeightStacked(width)}');
      return _computeMaxIntrinsicHeightStacked(width);
    }
  }

  double _computeMaxIntrinsicHeightStacked(double width) {
    assert(childCount >= 2);

    final double allDividersHeight = childCount * dividerWidth;
    return getChildrenAsList().fold(allDividersHeight, (double heightAccum, RenderBox button) {
      return heightAccum + button.computeMaxIntrinsicHeight(width);
    });
  }

  bool _isSingleButtonRow(double width) {
    if (childCount == 1) {
      return true;
    } else if (childCount == 2) {
      // There are 2 buttons. If they can fit side-by-side then that's what
      // we want to do. Otherwise, stack them vertically.
      final double sideBySideWidth = firstChild.computeMaxIntrinsicWidth(double.infinity)
          + dividerWidth
          + lastChild.computeMaxIntrinsicWidth(double.infinity);
      return sideBySideWidth <= width;
    } else {
      return false;
    }
  }

  @override
  void performLayout() {
    if (_isSingleButtonRow(_kCupertinoDialogWidth)) {
      if (childCount == 1) {
        // We have 1 button. Our size is
        firstChild.layout(
          constraints,
          parentUsesSize: true,
        );

        size = new Size(_kCupertinoDialogWidth, firstChild.size.height + dividerWidth);
      } else {
        // Each button gets half the available width, minus a single divider.
        final BoxConstraints perButtonConstraints = constraints.copyWith(
          minWidth: (constraints.minWidth - dividerWidth) / 2.0,
          maxWidth: (constraints.maxWidth - dividerWidth) / 2.0,
        );

        // Layout the 2 buttons.
        for(RenderBox button in getChildrenAsList()) {
          button.layout(
            perButtonConstraints,
            parentUsesSize: true,
          );
        }

        // The 2nd button needs to be offset to the right.
        assert(lastChild.parentData is MultiChildLayoutParentData);
        final MultiChildLayoutParentData secondButtonParentData = lastChild.parentData;
        secondButtonParentData.offset = new Offset(firstChild.size.width + dividerWidth, 0.0);

        // Calculate our size based on the button sizes.
        size = new Size(
          _kCupertinoDialogWidth,
          max(
            firstChild.size.height,
            lastChild.size.height,
          ) + dividerWidth,
        );
      }
    } else {
      // We need to stack buttons vertically, plus dividers above each button.
      final BoxConstraints perButtonConstraints = constraints.copyWith(
        minHeight: 0.0,
        maxHeight: (constraints.maxHeight - (dividerWidth * childCount)) / childCount,
      );

      final List<RenderBox> children = getChildrenAsList();
      double verticalOffset = dividerWidth;
      print('Laying out buttons vertically.');
      for (int i = 0; i < children.length; ++i) {
        print(' - verticalOffset: $verticalOffset');
        final RenderBox child = children[i];

        child.layout(
          perButtonConstraints,
          parentUsesSize: true,
        );

        assert(child.parentData is MultiChildLayoutParentData);
        final MultiChildLayoutParentData parentData = child.parentData;
        parentData.offset = new Offset(0.0, verticalOffset);
        print(' - button height: ${child.size.height}');

        verticalOffset += child.size.height;
        if (i < children.length - 1) {
          // Add a gap for the next divider.
          verticalOffset += dividerWidth;
        }
      }

      // Our height is the accumulated height of all buttons and dividers.
      size = new Size(_kCupertinoDialogWidth, verticalOffset);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    Offset changingOffset = offset;
    final Offset dividerOffset = new Offset(0.0, dividerWidth);
    final Paint dividerPaint = new Paint()
      ..color = _kButtonDividerColor
      ..strokeWidth = dividerWidth
      ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.round;
    for (RenderBox child in getChildrenAsList()) {
      print(' - Divider offset y: ${changingOffset.dy}');
      final Canvas canvas = context.canvas;
      canvas.drawRect(
        new Rect.fromLTWH(
          changingOffset.dx,
          changingOffset.dy,
          size.width,
          dividerWidth,
        ),
        dividerPaint,
      );

      final MultiChildLayoutParentData childParentData = child.parentData;
      context.paintChild(child, childParentData.offset + offset);
      print(' - Painted button at y: ${childParentData.offset.dy + offset.dy}, height: ${child.size.height}');

      changingOffset += dividerOffset + new Offset(0.0, child.size.height);
    }
  }

  @override
  bool hitTestChildren(HitTestResult result, { Offset position }) {
    return defaultHitTestChildren(result, position: position);
  }
}