// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:math' show max, min;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'events.dart';

/// An object that can hit-test pointers.
abstract class HitTestable {
  // This class is intended to be used as an interface, and should not be
  // extended directly; this constructor prevents instantiation and extension.
  // ignore: unused_element
  factory HitTestable._() => null;

  /// Check whether the given position hits this object.
  ///
  /// If this given position hits this object, consider adding a [HitTestEntry]
  /// to the given hit test result.
  void hitTest(HitTestResult result, Offset position);
}

/// An object that can dispatch events.
abstract class HitTestDispatcher {
  // This class is intended to be used as an interface, and should not be
  // extended directly; this constructor prevents instantiation and extension.
  // ignore: unused_element
  factory HitTestDispatcher._() => null;

  /// Override this method to dispatch events.
  void dispatchEvent(PointerEvent event, HitTestResult result);
}

/// An object that can handle events.
abstract class HitTestTarget {
  // This class is intended to be used as an interface, and should not be
  // extended directly; this constructor prevents instantiation and extension.
  // ignore: unused_element
  factory HitTestTarget._() => null;

  /// Override this method to receive events.
  void handleEvent(PointerEvent event, HitTestEntry entry);
}

/// Data collected during a hit test about a specific [HitTestTarget].
///
/// Subclass this object to pass additional information from the hit test phase
/// to the event propagation phase.
class HitTestEntry {
  /// Creates a hit test entry.
  HitTestEntry(this.target);

  /// The [HitTestTarget] encountered during the hit test.
  final HitTestTarget target;

  @override
  String toString() => '${describeIdentity(this)}($target)';

  /// Returns a matrix describing how [PointerEvent]s delivered to this
  /// [HitTestEntry] should be transformed from the global coordinate space of
  /// the screen to the local coordinate space of [target].
  ///
  /// See also:
  ///
  ///  * [HitTestResult.addWithPaintTransform], which is used during hit testing
  ///    to build up this transform.
  Matrix4 get transform => _transform;
  Matrix4 _transform;
}

class _Ref<T> {
  _Ref(this.value);

  T value;
}

@immutable
abstract class TransformPart {
  const TransformPart();

  factory TransformPart.matrix(Matrix4 matrix) => _MatrixTransformPart(matrix);

  Matrix4 _assertMatrix() {
    assert(false, '$this is not a Matrix transform part.');
    throw UnimplementedError('$this is not a Matrix transform part.');
  }

  TransformPart multiply(Matrix4 rhs);
}

class _MatrixTransformPart extends TransformPart {
  const _MatrixTransformPart(this.matrix);

  final Matrix4 matrix;

  @override
  Matrix4 _assertMatrix() => matrix;

  @override
  TransformPart multiply(Matrix4 rhs) {
    return TransformPart.matrix(matrix * rhs as Matrix4);
  }
}

class OffsetTransformPart extends TransformPart {
  const OffsetTransformPart(this.offset);

  final Offset offset;

  @override
  TransformPart multiply(Matrix4 rhs) {
    return TransformPart.matrix(rhs.clone()..leftTranslate(offset.dx, offset.dy));
  }
}

/// The result of performing a hit test.
class HitTestResult {
  /// Creates an empty hit test result.
  HitTestResult()
     : _path = <HitTestEntry>[],
       _transforms = <TransformPart>[TransformPart.matrix(Matrix4.identity())],
       _globalizedTransforms = _Ref<int>(1);

  /// Wraps `result` (usually a subtype of [HitTestResult]) to create a
  /// generic [HitTestResult].
  ///
  /// The [HitTestEntry]s added to the returned [HitTestResult] are also
  /// added to the wrapped `result` (both share the same underlying data
  /// structure to store [HitTestEntry]s).
  HitTestResult.wrap(HitTestResult result)
     : _path = result._path,
       _transforms = result._transforms,
       _globalizedTransforms = result._globalizedTransforms;

  /// An unmodifiable list of [HitTestEntry] objects recorded during the hit test.
  ///
  /// The first entry in the path is the most specific, typically the one at
  /// the leaf of tree being hit tested. Event propagation starts with the most
  /// specific (i.e., first) entry and proceeds in order through the path.
  Iterable<HitTestEntry> get path => _path;
  final List<HitTestEntry> _path;

  final List<TransformPart> _transforms;
  // The number of elements (from the head) in `_transforms` that has been
  // globalized.
  //
  // An globalized matrix has been multiplied by the ancesters and is thus a
  // global transform matrix, while a matrix that has not been globalized is
  // only the local transform matrix to its parent.
  //
  // The `_globalizedTransforms` is a reference of int, instead of a direct int,
  // because a new instance created by [HitTestResult.wrap] needs to have
  // up-to-date properties automatically.
  final _Ref<int> _globalizedTransforms;

  void _globalizeTransforms() {
    int globalizedTransforms = _globalizedTransforms.value;
    if (globalizedTransforms >= _transforms.length) {
      assert(globalizedTransforms == _transforms.length);
      return;
    }
    for (TransformPart last = _transforms[globalizedTransforms - 1]; globalizedTransforms < _transforms.length; globalizedTransforms += 1) {
      last = _transforms[globalizedTransforms].multiply(last._assertMatrix());
      _transforms[globalizedTransforms] = last;
    }
    _globalizedTransforms.value = globalizedTransforms;
  }

  Matrix4 get _lastTransform {
    _globalizeTransforms();
    return _transforms.last._assertMatrix();
  }

  /// Add a [HitTestEntry] to the path.
  ///
  /// The new entry is added at the end of the path, which means entries should
  /// be added in order from most specific to least specific, typically during an
  /// upward walk of the tree being hit tested.
  void add(HitTestEntry entry) {
    assert(entry._transform == null);
    entry._transform = _transforms.isEmpty ? null : _lastTransform;
    _path.add(entry);
  }

  /// Pushes a new transform matrix that is to be applied to all future
  /// [HitTestEntry]s added via [add] until it is removed via [popTransform].
  ///
  /// This method is only to be used by subclasses, which must provide
  /// coordinate space specific public wrappers around this function for their
  /// users (see [BoxHitTestResult.addWithPaintTransform] for such an example).
  ///
  /// The provided `transform` matrix should describe how to transform
  /// [PointerEvent]s from the coordinate space of the method caller to the
  /// coordinate space of its children. In most cases `transform` is derived
  /// from running the inverted result of [RenderObject.applyPaintTransform]
  /// through [PointerEvent.removePerspectiveTransform] to remove
  /// the perspective component.
  ///
  /// [HitTestable]s need to call this method indirectly through a convenience
  /// method defined on a subclass before hit testing a child that does not
  /// have the same origin as the parent. After hit testing the child,
  /// [popTransform] has to be called to remove the child-specific `transform`.
  ///
  /// See also:
  ///
  ///  * [BoxHitTestResult.addWithPaintTransform], which is a public wrapper
  ///    around this function for hit testing on [RenderBox]s.
  ///  * [SliverHitTestResult.addWithAxisOffset], which is a public wrapper
  ///    around this function for hit testing on [RenderSliver]s.
  @protected
  void pushTransform(Matrix4 transform) {
    pushTransformPart(TransformPart.matrix(transform));
  }

  @protected
  void pushTransformPart(TransformPart transform) {
    assert(transform != null);
    assert(() {
      if (transform is _MatrixTransformPart) {
        final Matrix4 matrix = transform.matrix;
        assert(
          _debugVectorMoreOrLessEquals(matrix.getRow(2), Vector4(0, 0, 1, 0)) &&
          _debugVectorMoreOrLessEquals(matrix.getColumn(2), Vector4(0, 0, 1, 0)),
          'The third row and third column of a transform matrix for pointer '
          'events must be Vector4(0, 0, 1, 0) to ensure that a transformed '
          'point is directly under the pointing device. Did you forget to run the paint '
          'matrix through PointerEvent.removePerspectiveTransform? '
          'The provided matrix is:\n$matrix'
        );
      }
      return true;
    }());
    _transforms.add(transform);
  }

  /// Removes the last transform added via [pushTransform].
  ///
  /// This method is only to be used by subclasses, which must provide
  /// coordinate space specific public wrappers around this function for their
  /// users (see [BoxHitTestResult.addWithPaintTransform] for such an example).
  ///
  /// This method must be called after hit testing is done on a child that
  /// required a call to [pushTransform].
  ///
  /// See also:
  ///
  ///  * [pushTransform], which describes the use case of this function pair in
  ///    more details.
  @protected
  void popTransform() {
    assert(_transforms.isNotEmpty);
    assert(_globalizedTransforms.value <= _transforms.length);
    _transforms.removeLast();
    _globalizedTransforms.value = min(_transforms.length, _globalizedTransforms.value);
  }

  bool _debugVectorMoreOrLessEquals(Vector4 a, Vector4 b, { double epsilon = precisionErrorTolerance }) {
    bool result = true;
    assert(() {
      final Vector4 difference = a - b;
      result = difference.storage.every((double component) => component.abs() < epsilon);
      return true;
    }());
    return result;
  }

  @override
  String toString() => 'HitTestResult(${_path.isEmpty ? "<empty path>" : _path.join(", ")})';
}
