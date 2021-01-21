// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'material.dart';
import 'material_localizations.dart';

/// A list whose items the user can interactively reorder by dragging.
///
/// This class is appropriate for views with a small number of
/// children because constructing the [List] requires doing work for every
/// child that could possibly be displayed in the list view instead of just
/// those children that are actually visible.
///
/// All [children] must have a key.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=3fB1mxOsqJE}
///
/// This sample shows by dragging the user can reorder the items of the list.
/// The [onReorder] parameter is required and will be called when a child
/// widget is dragged to a new position.
///
/// {@tool dartpad --template=stateful_widget_scaffold}
///
/// ```dart
/// List<String> _list = List.generate(5, (i) => "${i}");
///
/// Widget build(BuildContext context){
///   return ReorderableListView(
///     padding : const EdgeInsets.symmetric(horizontal:40),
///     children:[
///       for(var i=0 ; i<_list.length ; i++)
///         ListTile(
///              key:Key('$i'),
///              title: Text(_list[i]),
///         ),
///     ],
///     onReorder: (oldIndex, newIndex){
///       setState((){
///         if(oldIndex < newIndex){
///           newIndex-=1;
///         }
///         final element = _list.removeAt(oldIndex);
///         _list.insert(newIndex, element);
///       });
///     },
///   );
/// }
///
/// ```
///
///{@end-tool}
///
class ReorderableListView extends StatefulWidget {

  /// Creates a reorderable list.
  ReorderableListView({
    Key? key,
    this.header,
    required this.children,
    required this.onReorder,
    this.scrollController,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.reverse = false,
  }) : assert(scrollDirection != null),
       assert(onReorder != null),
       assert(children != null),
       assert(
         children.every((Widget w) => w.key != null),
         'All children of this widget must have a key.',
       ),
       super(key: key);

  /// A non-reorderable header widget to show before the list.
  ///
  /// If null, no header will appear before the list.
  final Widget? header;

  /// The widgets to display.
  final List<Widget> children;

  /// The [Axis] along which the list scrolls.
  ///
  /// List [children] can only drag along this [Axis].
  final Axis scrollDirection;

  /// Creates a [ScrollPosition] to manage and determine which portion
  /// of the content is visible in the scroll view.
  ///
  /// This can be used in many ways, such as setting an initial scroll offset,
  /// (via [ScrollController.initialScrollOffset]), reading the current scroll position
  /// (via [ScrollController.offset]), or changing it (via [ScrollController.jumpTo] or
  /// [ScrollController.animateTo]).
  final ScrollController? scrollController;

  /// The amount of space by which to inset the [children].
  final EdgeInsets? padding;

  /// Whether the scroll view scrolls in the reading direction.
  ///
  /// For example, if the reading direction is left-to-right and
  /// [scrollDirection] is [Axis.horizontal], then the scroll view scrolls from
  /// left to right when [reverse] is false and from right to left when
  /// [reverse] is true.
  ///
  /// Similarly, if [scrollDirection] is [Axis.vertical], then the scroll view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  final bool reverse;

  /// Called when a list child is dropped into a new position to shuffle the
  /// underlying list.
  ///
  /// This [ReorderableListView] calls [onReorder] after a list child is dropped
  /// into a new position.
  final ReorderCallback onReorder;

  @override
  _ReorderableListViewState createState() => _ReorderableListViewState();
}

class _ReorderableListViewState extends State<ReorderableListView> {

  Widget _wrapWithSemantics(Widget child, int index) {

    void reorder(int startIndex, int endIndex) {
      setState(() {
        if (startIndex != endIndex)
          widget.onReorder(startIndex, endIndex);
      });
    }

    // First, determine which semantics actions apply.
    final Map<CustomSemanticsAction, VoidCallback> semanticsActions = <CustomSemanticsAction, VoidCallback>{};

    // Create the appropriate semantics actions.
    void moveToStart() => reorder(index, 0);
    void moveToEnd() => reorder(index, widget.children.length);
    void moveBefore() => reorder(index, index - 1);
    // To move after, we go to index+2 because we are moving it to the space
    // before index+2, which is after the space at index+1.
    void moveAfter() => reorder(index, index + 2);

    final MaterialLocalizations localizations = MaterialLocalizations.of(context);

    // If the item can move to before its current position in the list.
    if (index > 0) {
      semanticsActions[CustomSemanticsAction(label: localizations.reorderItemToStart)] = moveToStart;
      String reorderItemBefore = localizations.reorderItemUp;
      if (widget.scrollDirection == Axis.horizontal) {
        reorderItemBefore = Directionality.of(context) == TextDirection.ltr
            ? localizations.reorderItemLeft
            : localizations.reorderItemRight;
      }
      semanticsActions[CustomSemanticsAction(label: reorderItemBefore)] = moveBefore;
    }

    // If the item can move to after its current position in the list.
    if (index < widget.children.length - 1) {
      String reorderItemAfter = localizations.reorderItemDown;
      if (widget.scrollDirection == Axis.horizontal) {
        reorderItemAfter = Directionality.of(context) == TextDirection.ltr
            ? localizations.reorderItemRight
            : localizations.reorderItemLeft;
      }
      semanticsActions[CustomSemanticsAction(label: reorderItemAfter)] = moveAfter;
      semanticsActions[CustomSemanticsAction(label: localizations.reorderItemToEnd)] = moveToEnd;
    }

    // We pass toWrap with a GlobalKey into the Draggable so that when a list
    // item gets dragged, the accessibility framework can preserve the selected
    // state of the dragging item.
    //
    // We also apply the relevant custom accessibility actions for moving the item
    // up, down, to the start, and to the end of the list.
    return MergeSemantics(
      child: Semantics(
        customSemanticsActions: semanticsActions,
        child: child,
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    final Widget item = widget.children[index];
    assert(item.key != null);

    return ReorderableDelayedDragStartListener(
      key: _ReorderableListViewChildGlobalKey(item.key!, this),
      child: _wrapWithSemantics(item, index),
      index: index
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(0, 6, animValue)!;
          return Material(
          child: child,
          elevation: elevation,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));

    // If there is a header we can't just apply the padding to the list,
    // so we wrap the CustomScrollView in the padding for the top, left and right
    // and only add the padding from the bottom to the sliver list (or the equivalent
    // for horizontal scrolling).
    final EdgeInsets padding = widget.padding ?? const EdgeInsets.all(0);
    late EdgeInsets outerPadding;
    late EdgeInsets listPadding;
    if (widget.scrollDirection == Axis.vertical) {
      if (widget.reverse) {
        outerPadding = EdgeInsets.fromLTRB(padding.left, 0, padding.right, padding.bottom);
        listPadding = EdgeInsets.fromLTRB(0, padding.top, 0, 0);
      } else {
        outerPadding = EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0);
        listPadding = EdgeInsets.fromLTRB(0, 0, 0, padding.bottom);
      }
    } else {
      if (widget.reverse) {
        outerPadding = EdgeInsets.fromLTRB(0, padding.top, padding.right, padding.bottom);
        listPadding = EdgeInsets.fromLTRB(padding.left, 0, 0, 0);
      } else {
        outerPadding = EdgeInsets.fromLTRB(padding.left, padding.top, 0, padding.bottom);
        listPadding = EdgeInsets.fromLTRB(0, 0, padding.right, 0);
      }
    }

    return Padding(
      padding: outerPadding,
      child: CustomScrollView(
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        controller: widget.scrollController,
        slivers: <Widget>[
          if (widget.header != null)
            SliverToBoxAdapter(child: widget.header!),
          SliverPadding(
            padding: listPadding,
            sliver: SliverReorderableList(
              // key: _sliverReorderableListKey,
              itemBuilder: _itemBuilder,
              itemCount: widget.children.length,
              onReorder: widget.onReorder,
              proxyDecorator: _proxyDecorator,
            ),
          ),
        ],
      ),
    );
  }
}

// A global key that takes its identity from the object and uses a value of a
// particular type to identify itself.
//
// The difference with GlobalObjectKey is that it uses [==] instead of [identical]
// of the objects used to generate widgets.
@optionalTypeArgs
class _ReorderableListViewChildGlobalKey extends GlobalObjectKey {

  const _ReorderableListViewChildGlobalKey(this.subKey, this.state) : super(subKey);

  final Key subKey;

  final _ReorderableListViewState state;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is _ReorderableListViewChildGlobalKey
        && other.subKey == subKey
        && other.state == state;
  }

  @override
  int get hashCode => hashValues(subKey, state);
}
