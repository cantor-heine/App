// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'scroll_independent_position.dart';
import 'scroll_interfaces.dart';
import 'scroll_physics.dart';
import 'scroll_position.dart';

class ScrollController extends ChangeNotifier {
  ScrollController({
    this.initialScrollOffset: 0.0,
  }) {
    assert(initialScrollOffset != null);
  }

  /// The initial value to use for [offset].
  ///
  /// New [ScrollPosition] objects that are created and attached to this
  /// controller will have their offset initialized to this value.
  final double initialScrollOffset;

  /// The currently attached positions.
  ///
  /// This should not be mutated directly. [ScrollPosition] objects can be added
  /// and removed using [attach] and [detach].
  @protected
  Iterable<ScrollPosition> get positions => _positions;
  final List<ScrollPosition> _positions = <ScrollPosition>[];

  /// Whether any [ScrollPosition] objects have attached themselves to the
  /// [ScrollController] using the [attach] method.
  ///
  /// If this is false, then members that interact with the [ScrollPosition],
  /// such as [position], [offset], [animateTo], and [jumpTo], must not be
  /// called.
  bool get hasClients => _positions.isNotEmpty;

  /// Returns the attached [ScrollPosition], from which the actual scroll offset
  /// of the [ScrollView] can be obtained.
  ///
  /// Calling this is only valid when only a single position is attached.
  ScrollPosition get position {
    assert(_positions.isNotEmpty, 'ScrollController not attached to any scroll views.');
    assert(_positions.length == 1, 'ScrollController attached to multiple scroll views.');
    return _positions.single;
  }

  double get offset => position.pixels;

  /// Animates the position from its current value to the given value.
  ///
  /// Any active animation is canceled. If the user is currently scrolling, that
  /// action is canceled.
  ///
  /// The returned [Future] will complete when the animation ends, whether it
  /// completed successfully or whether it was interrupted prematurely.
  ///
  /// An animation will be interrupted whenever the user attempts to scroll
  /// manually, or whenever another activity is started, or whenever the
  /// animation reaches the edge of the viewport and attempts to overscroll. (If
  /// the [ScrollPosition] does not overscroll but instead allows scrolling
  /// beyond the extents, then going beyond the extents will not interrupt the
  /// animation.)
  ///
  /// The animation is indifferent to changes to the viewport or content
  /// dimensions.
  ///
  /// Once the animation has completed, the scroll position will attempt to
  /// begin a ballistic activity in case its value is not stable (for example,
  /// if it is scrolled beyond the extents and in that situation the scroll
  /// position would normally bounce back).
  ///
  /// The duration must not be zero. To jump to a particular value without an
  /// animation, use [jumpTo].
  Future<Null> animateTo(double offset, {
    @required Duration duration,
    @required Curve curve,
  }) {
    assert(_positions.isNotEmpty, 'ScrollController not attached to any scroll views.');
    final List<Future<Null>> animations = new List<Future<Null>>(_positions.length);
    for (int i = 0; i < _positions.length; i += 1)
      animations[i] = _positions[i].animateTo(offset, duration: duration, curve: curve);
    return Future.wait<Null>(animations).then((List<Null> _) => null);
  }

  /// Jumps the scroll position from its current value to the given value,
  /// without animation, and without checking if the new value is in range.
  ///
  /// Any active animation is canceled. If the user is currently scrolling, that
  /// action is canceled.
  ///
  /// If this method changes the scroll position, a sequence of start/update/end
  /// scroll notifications will be dispatched. No overscroll notifications can
  /// be generated by this method.
  ///
  /// Immediately after the jump, a ballistic activity is started, in case the
  /// value was out of range.
  void jumpTo(double value) {
    assert(_positions.isNotEmpty, 'ScrollController not attached to any scroll views.');
    for (ScrollPosition position in new List<ScrollPosition>.from(_positions))
      position.jumpTo(value);
  }

  /// Register the given position with this controller.
  ///
  /// After this function returns, the [animateTo] and [jumpTo] methods on this
  /// controller will manipulate the given position.
  void attach(ScrollPosition position) {
    assert(!_positions.contains(position));
    _positions.add(position);
    position.addListener(notifyListeners);
  }

  /// Unregister the given position with this controller.
  ///
  /// After this function returns, the [animateTo] and [jumpTo] methods on this
  /// controller will not manipulate the given position.
  void detach(ScrollPosition position) {
    assert(_positions.contains(position));
    position.removeListener(notifyListeners);
    _positions.remove(position);
  }

  @override
  void dispose() {
    for (ScrollPosition position in _positions)
      position.removeListener(notifyListeners);
    super.dispose();
  }

  static ScrollPosition createDefaultScrollPosition(ScrollPhysics physics, ScrollWidgetInterface state, ScrollPosition oldPosition) {
    return new ScrollIndependentPosition(
      physics: physics,
      state: state,
      oldPosition: oldPosition,
    );
  }

  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollWidgetInterface state,
    ScrollPosition oldPosition,
  ) {
    return new ScrollIndependentPosition(
      physics: physics,
      state: state,
      initialPixels: initialScrollOffset,
      oldPosition: oldPosition,
    );
  }

  @override
  String toString() {
    final List<String> description = <String>[];
    debugFillDescription(description);
    return '$runtimeType#$hashCode(${description.join(", ")})';
  }

  @mustCallSuper
  void debugFillDescription(List<String> description) {
    if (initialScrollOffset != 0.0)
      description.add('initialScrollOffset: ${initialScrollOffset.toStringAsFixed(1)}, ');
    if (_positions.isEmpty) {
      description.add('no clients');
    } else if (_positions.length == 1) {
      // Don't actually list the client itself, since its toString may refer to us.
      description.add('one client, offset ${offset.toStringAsFixed(1)}');
    } else {
      description.add('${_positions.length} clients');
    }
  }
}
