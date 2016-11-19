// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' show lerpDouble;

/// The base type for [MaterialSlice] and [MaterialGap].
///
/// All [MergeableMaterialItem] objects need a [LocalKey].
abstract class MergeableMaterialItem {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  ///
  /// The argument is the [key], which must not be null.
  const MergeableMaterialItem(this.key);

  /// The key for this item of the list.
  ///
  /// The key is used to match parts of the mergeable material from frame to
  /// frame so that state is maintained appropriately even as slices are added
  /// or removed.
  final LocalKey key;
}

/// A class that can be used as a child to [MergeableMaterial]. It is a slice
/// of [Material] that animates merging with other slices.
///
/// All [MaterialSlice] objects need a [LocalKey].
class MaterialSlice extends MergeableMaterialItem {
  /// Creates a slice of [Material] that's mergeable within a
  /// [MergeableMaterial].
  MaterialSlice({
    @required LocalKey key,
    this.child
  }) : super(key) {
    assert(key != null);
  }

  /// The contents of this slice.
  final Widget child;

  @override
  String toString() {
    return 'MergeableSlice(key: $key, child: $child)';
  }
}

/// A class that represents a gap within [MergeableMaterial].
///
/// All [MaterialGap] objects need a [LocalKey].
class MaterialGap extends MergeableMaterialItem {
  /// Creates a Material gap with a given size.
  MaterialGap({
    @required LocalKey key,
    this.size: 16.0
  }) : super(key) {
    assert(key != null);
  }

  /// The main axis extent of this gap. For example, if the [MergableMaterial]
  /// is vertical, then this is the height of the gap.
  final double size;

  @override
  String toString() {
    return 'MaterialGap(key: $key, child: $size)';
  }
}

/// Displays a list of [MergeableMaterialItem] children. The list contains
/// [MaterialSlice] items whose boundaries are either "merged" with adjacent
/// items or separated by a [MaterialGap]. The [children] are distributed along
/// the given [mainAxis] in the same way as the children of a [BlockBody]. When
/// the list of children changes, gaps are automatically animated open or closed
/// as needed.
///
/// To enable this widget to correlate its list of children with the previous
/// one, each child must specify a key.
///
/// When a new gap is added to the list of children the adjacent items are
/// animated apart. Similarly when a gap is removed the adjacent items are
/// brought back together.
///
/// When a new slice is added or removed, the app is responsible for animating
/// the transition of the slices, while the gaps will be animated automatically.
///
/// See also:
///
///  * [Card], a piece of material that does not support splitting and merging
///    but otherwise looks the same.
class MergeableMaterial extends StatefulWidget {
  /// Creates a mergeable Material list of items.
  MergeableMaterial({
    Key key,
    this.mainAxis: Axis.vertical,
    this.elevation: 2,
    this.hasDividers: false,
    this.children: const <MergeableMaterialItem>[]
  }) : super(key: key);

  /// The children of the [MergeableMaterial].
  final List<MergeableMaterialItem> children;

  /// The main layout axis.
  final Axis mainAxis;

  /// The z-coordinate at which to place all the [Material] slices.
  ///
  /// The following elevations have defined shadows: 1, 2, 3, 4, 6, 8, 9, 12, 16, 24
  ///
  /// Defaults to 2, the appropriate elevation for cards.
  final int elevation;

  /// Whether connected pieces of [MaterialSlice] have dividers between them.
  final bool hasDividers;

  @override
  String toString() {
    return 'MergeableMaterial('
      'key: $key, mainAxis: $mainAxis, elevation: $elevation'
    ')';
  }

  @override
  _MergeableMaterialState createState() => new _MergeableMaterialState();
}

class _AnimationTuple {
  _AnimationTuple({
    this.controller,
    this.startAnimation,
    this.endAnimation,
    this.gapAnimation,
    this.gapStart: 0.0
  });

  final AnimationController controller;
  final CurvedAnimation startAnimation;
  final CurvedAnimation endAnimation;
  final CurvedAnimation gapAnimation;
  double gapStart;
}

class _MergeableMaterialState extends State<MergeableMaterial> with TickerProviderStateMixin {
  List<MergeableMaterialItem> _children;
  final Map<LocalKey, _AnimationTuple> _animationTuples =
      <LocalKey, _AnimationTuple>{};

  @override
  void initState() {
    super.initState();
    _children = new List<MergeableMaterialItem>.from(config.children);

    for (int i = 0; i < _children.length; i += 1) {
      if (_children[i] is MaterialGap) {
        _initGap(_children[i]);
        _animationTuples[_children[i].key].controller.value = 1.0; // Gaps are initially full-sized.
      }
    }
    assert(_debugGapsAreValid(_children));
  }

  void _initGap(MaterialGap gap) {
    final AnimationController controller = new AnimationController(
      duration: kThemeAnimationDuration,
      vsync: this,
    );

    final CurvedAnimation startAnimation = new CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn
    );
    final CurvedAnimation endAnimation = new CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn
    );

    startAnimation.addListener(_handleTick);
    endAnimation.addListener(_handleTick);

    final CurvedAnimation gapAnimation = new CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn
    );

    gapAnimation.addListener(_handleTick);

    _animationTuples[gap.key] = new _AnimationTuple(
      controller: controller,
      startAnimation: startAnimation,
      endAnimation: endAnimation,
      gapAnimation: gapAnimation
    );
  }

  @override
  void dispose() {
    for (MergeableMaterialItem child in _children) {
      if (child is MaterialGap)
        _animationTuples[child.key].controller.dispose();
    }
    super.dispose();
  }

  void _handleTick() {
    setState(() {
      // The animation's state is our build state, and it changed already.
    });
  }

  bool _debugHasConsecutiveGaps(List<MergeableMaterialItem> children) {
    for (int i = 0; i < config.children.length - 1; i += 1) {
      if (config.children[i] is MaterialGap &&
          config.children[i + 1] is MaterialGap)
        return true;
    }
    return false;
  }

  bool _debugGapsAreValid(List<MergeableMaterialItem> children) {
    // Check for consecutive gaps.
    if (_debugHasConsecutiveGaps(children))
      return false;

    // First and last children must not be gaps.
    if (children.isNotEmpty) {
      if (children.first is MaterialGap || children.last is MaterialGap)
        return false;
    }

    return true;
  }

  void _insertChild(int index, MergeableMaterialItem child) {
    _children.insert(index, child);

    if (child is MaterialGap)
      _initGap(child);
  }

  void _removeChild(int index) {
    MergeableMaterialItem child = _children.removeAt(index);

    if (child is MaterialGap)
      _animationTuples[child.key] = null;
  }

  bool _isClosingGap(int index) {
    if (index < _children.length - 1 && _children[index] is MaterialGap) {
      return _animationTuples[_children[index].key].controller.status ==
          AnimationStatus.reverse;
    }

    return false;
  }

  void _removeEmptyGaps() {
    int j = 0;

    while (j < _children.length) {
      if (
        _children[j] is MaterialGap &&
        _animationTuples[_children[j].key].controller.status == AnimationStatus.dismissed
      ) {
        _removeChild(j);
      } else {
        j += 1;
      }
    }
  }

  @override
  void didUpdateConfig(MergeableMaterial oldConfig) {
    super.didUpdateConfig(oldConfig);

    final Set<LocalKey> oldKeys = oldConfig.children.map(
      (MergeableMaterialItem child) => child.key
    ).toSet();
    final Set<LocalKey> newKeys = config.children.map(
      (MergeableMaterialItem child) => child.key
    ).toSet();
    final Set<LocalKey> newOnly = newKeys.difference(oldKeys);
    final Set<LocalKey> oldOnly = oldKeys.difference(newKeys);

    final List<MergeableMaterialItem> newChildren = config.children;
    int i = 0;
    int j = 0;

    assert(_debugGapsAreValid(newChildren));

    _removeEmptyGaps();

    while (i < newChildren.length && j < _children.length) {
      if (newOnly.contains(newChildren[i].key) ||
          oldOnly.contains(_children[j].key)) {
        final int startNew = i;
        final int startOld = j;

        // Skip new keys.
        while (newOnly.contains(newChildren[i].key))
          i += 1;

        // Skip old keys.
        while (oldOnly.contains(_children[j].key) || _isClosingGap(j))
          j += 1;

        final int newLength = i - startNew;
        final int oldLength = j - startOld;

        if (newLength > 0) {
          if (oldLength > 1 ||
              oldLength == 1 && _children[startOld] is MaterialSlice) {
            if (newLength == 1 && newChildren[startNew] is MaterialGap) {
              // Shrink all gaps into the size of the new one.
              double gapSizeSum = 0.0;

              while (startOld < j) {
                if (_children[startOld] is MaterialGap) {
                  MaterialGap gap = _children[startOld];
                  gapSizeSum += gap.size;
                }

                _removeChild(startOld);
                j -= 1;
              }

              _insertChild(startOld, newChildren[startNew]);
              _animationTuples[newChildren[startNew].key]
                ..gapStart = gapSizeSum
                ..controller.forward();

              j += 1;
            } else {
              // No animation if replaced items are more than one.
              for (int k = 0; k < oldLength; k += 1)
                _removeChild(startOld);
              for (int k = 0; k < newLength; k += 1)
                _insertChild(startOld + k, newChildren[startNew + k]);

              j += newLength - oldLength;
            }
          } else if (oldLength == 1) {
            if (newLength == 1 && newChildren[startNew] is MaterialGap &&
                _children[startOld].key == newChildren[startNew].key) {
              /// Special case: gap added back.
              _animationTuples[newChildren[startNew].key].controller.forward();
            } else {
              final double gapSize = _getGapSize(startOld);

              _removeChild(startOld);

              for (int k = 0; k < newLength; k += 1)
                _insertChild(startOld + k, newChildren[startNew + k]);

              j += newLength - 1;
              double gapSizeSum = 0.0;

              for (int k = startNew; k < i; k += 1) {
                if (newChildren[k] is MaterialGap) {
                  MaterialGap gap = newChildren[k];
                  gapSizeSum += gap.size;
                }
              }

              // All gaps get proportional sizes of the original gap and they will
              // animate to their actual size.
              for (int k = startNew; k < i; k += 1) {
                if (newChildren[k] is MaterialGap) {
                  MaterialGap gap = newChildren[k];

                  _animationTuples[gap.key].gapStart = gapSize * gap.size /
                      gapSizeSum;
                  _animationTuples[gap.key].controller
                    ..value = 0.0
                    ..forward();
                }
              }
            }
          } else {
            // Grow gaps.
            for (int k = 0; k < newLength; k += 1) {
              _insertChild(startOld + k, newChildren[startNew + k]);

              if (newChildren[startNew + k] is MaterialGap) {
                MaterialGap gap = newChildren[startNew + k];
                _animationTuples[gap.key].controller.forward();
              }
            }

            j += newLength;
          }
        } else {
          // If more than a gap disappeared, just remove slices and shrink gaps.
          if (oldLength > 1 ||
              oldLength == 1 && _children[startOld] is MaterialSlice) {
            double gapSizeSum = 0.0;

            while (startOld < j) {
              if (_children[startOld] is MaterialGap) {
                MaterialGap gap = _children[startOld];
                gapSizeSum += gap.size;
              }

              _removeChild(startOld);
              j -= 1;
            }

            if (gapSizeSum != 0.0) {
              MaterialGap gap = new MaterialGap(
                key: new UniqueKey(),
                size: gapSizeSum
              );
              _insertChild(startOld, gap);
              _animationTuples[gap.key].gapStart = 0.0;
              _animationTuples[gap.key].controller
                ..value = 1.0
                ..reverse();

              j += 1;
            }
          } else if (oldLength == 1) {
            // Shrink gap.
            MaterialGap gap = _children[startOld];
            _animationTuples[gap.key].gapStart = 0.0;
            _animationTuples[gap.key].controller.reverse();
          }
        }
      } else {
        // Check whether the items are the same type. If they are, it means that
        // their places have been swaped.
        if ((_children[j] is MaterialGap) == (newChildren[i] is MaterialGap)) {
          _children[j] = newChildren[i];

          i += 1;
          j += 1;
        } else {
          // This is a closing gap which we need to skip.
          assert(_children[j] is MaterialGap);
          j += 1;
        }
      }
    }

    // Handle remaining items.
    while (j < _children.length)
      _removeChild(j);
    while (i < newChildren.length) {
      _insertChild(j, newChildren[i]);

      i += 1;
      j += 1;
    }
  }

  BorderRadius _borderRadius(int index, bool start, bool end) {
    final Radius cardRadius = kMaterialEdges[MaterialType.card].topLeft;

    Radius startRadius = Radius.zero;
    Radius endRadius = Radius.zero;

    if (index > 0 && _children[index - 1] is MaterialGap) {
      startRadius = Radius.lerp(
        Radius.zero,
        cardRadius,
        _animationTuples[_children[index - 1].key].startAnimation.value
      );
    }
    if (index < _children.length - 2 && _children[index + 1] is MaterialGap) {
      endRadius = Radius.lerp(
        Radius.zero,
        cardRadius,
        _animationTuples[_children[index + 1].key].endAnimation.value
      );
    }

    if (config.mainAxis == Axis.vertical) {
      return new BorderRadius.vertical(
        top: start ? cardRadius : startRadius,
        bottom: end ? cardRadius : endRadius
      );
    } else {
      return new BorderRadius.horizontal(
        left: start ? cardRadius : startRadius,
        right: end ? cardRadius : endRadius
      );
    }
  }

  double _getGapSize(int index) {
    MaterialGap gap = _children[index];

    return lerpDouble(
      _animationTuples[gap.key].gapStart,
      gap.size,
      _animationTuples[gap.key].gapAnimation.value
    );
  }

  bool _willNeedDivider(int index) {
    if (index < 0)
      return false;
    if (index >= _children.length)
      return false;
    return _children[index] is MaterialSlice || _isClosingGap(index);
  }

  @override
  Widget build(BuildContext context) {
    _removeEmptyGaps();

    final List<Widget> widgets = <Widget>[];
    List<Widget> slices = <Widget>[];
    int i;

    for (i = 0; i < _children.length; i += 1) {
      if (_children[i] is MaterialGap) {
        assert(slices.isNotEmpty);
        widgets.add(
          new Container(
            decoration: new BoxDecoration(
              backgroundColor: Theme.of(context).cardColor,
              borderRadius: _borderRadius(i - 1, widgets.isEmpty, false),
              shape: BoxShape.rectangle
            ),
            child: new BlockBody(
              mainAxis: config.mainAxis,
              children: slices
            )
          )
        );
        slices = <Widget>[];

        widgets.add(
          new SizedBox(
            width: config.mainAxis == Axis.horizontal ? _getGapSize(i) : null,
            height: config.mainAxis == Axis.vertical ? _getGapSize(i) : null
          )
        );
      } else {
        MaterialSlice slice = _children[i];
        Widget child = slice.child;

        if (config.hasDividers) {
          final bool hasTopDivider = _willNeedDivider(i - 1);
          final bool hasBottomDivider = _willNeedDivider(i + 1);

          Border border;
          final BorderSide divider = new BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5
          );

          if (i == 0) {
            border = new Border(
              bottom: hasBottomDivider ? divider : BorderSide.none
            );
          } else if (i == _children.length - 1) {
            border = new Border(
              top: hasTopDivider ? divider : BorderSide.none
            );
          } else {
            border = new Border(
              top: hasTopDivider ? divider : BorderSide.none,
              bottom: hasBottomDivider ? divider : BorderSide.none
            );
          }

          assert(border != null);

          child = new AnimatedContainer(
            key: new _MergeableMaterialSliceKey(_children[i].key),
            decoration: new BoxDecoration(border: border),
            duration: kThemeAnimationDuration,
            curve: Curves.fastOutSlowIn,
            child: child
          );
        }

        slices.add(
          new Material(
            type: MaterialType.transparency,
            child: child
          )
        );
      }
    }

    if (slices.isNotEmpty) {
      widgets.add(
        new Container(
          decoration: new BoxDecoration(
            backgroundColor: Theme.of(context).cardColor,
            borderRadius: _borderRadius(i - 1, widgets.isEmpty, true),
            shape: BoxShape.rectangle
          ),
          child: new BlockBody(
            mainAxis: config.mainAxis,
            children: slices
          )
        )
      );
      slices = <Widget>[];
    }

    return new _MergeableMaterialBlockBody(
      mainAxis: config.mainAxis,
      boxShadows: kElevationToShadow[config.elevation],
      items: _children,
      children: widgets
    );
  }
}

// The parent hierarchy can change and lead to the slice being
// rebuilt. Using a global key solves the issue.
class _MergeableMaterialSliceKey extends GlobalKey {
  const _MergeableMaterialSliceKey(this.value) : super.constructor();

  final LocalKey value;

  @override
  bool operator ==(dynamic other) {
    if (other is! _MergeableMaterialSliceKey)
      return false;
    final _MergeableMaterialSliceKey typedOther = other;
    return value == typedOther.value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return '_MergeableMaterialSliceKey($value)';
  }
}

class _MergeableMaterialBlockBody extends BlockBody {
  _MergeableMaterialBlockBody({
    List<Widget> children,
    Axis mainAxis: Axis.vertical,
    this.items,
    this.boxShadows
  }) : super(children: children, mainAxis: mainAxis);

  List<MergeableMaterialItem> items;
  List<BoxShadow> boxShadows;

  @override
  RenderBlock createRenderObject(BuildContext context) {
    return new _MergeableMaterialRenderBlock(
      mainAxis: mainAxis,
      boxShadows: boxShadows
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlock renderObject) {
    _MergeableMaterialRenderBlock materialRenderBlock = renderObject;
    materialRenderBlock
      ..mainAxis = mainAxis
      ..boxShadows = boxShadows;
  }
}

class _MergeableMaterialRenderBlock extends RenderBlock {
  _MergeableMaterialRenderBlock({
    List<RenderBox> children,
    Axis mainAxis: Axis.vertical,
    this.boxShadows
  }) : super(children: children, mainAxis: mainAxis);

  List<BoxShadow> boxShadows;

  void _paintShadows(Canvas canvas, Rect rect) {
    for (BoxShadow boxShadow in boxShadows) {
      final Paint paint = new Paint()
        ..color = boxShadow.color
        ..maskFilter = new MaskFilter.blur(BlurStyle.normal, boxShadow.blurSigma);
      // TODO(dragostis): Right now, we are only interpolating the border radii
      // of the visible Material slices, not the shadows; they are not getting
      // interpolated and always have the same rounded radii. Once shadow
      // performance is better, shadows should be redrawn every single time the
      // slices' radii get interpolated and use those radii not the defaults.
      canvas.drawRRect(kMaterialEdges[MaterialType.card].toRRect(rect), paint);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox child = firstChild;
    int i = 0;

    while (child != null) {
      final BlockParentData childParentData = child.parentData;
      final Rect rect = (childParentData.offset + offset) & child.size;
      if (i % 2 == 0)
        _paintShadows(context.canvas, rect);
      child = childParentData.nextSibling;

      i += 1;
    }

    defaultPaint(context, offset);
  }
}
