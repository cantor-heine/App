// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'edge_insets.dart';
import 'image_provider.dart';

// This group of classes is intended for painting in cartesian coordinates.

/// A description of a box decoration (a decoration applied to a [Rect]).
///
/// This class presents the abstract interface for all decorations.
/// See [BoxDecoration] for a concrete example.
///
/// To actually paint a [Decoration], use the [createBoxPainter]
/// method to obtain a [BoxPainter]. [Decoration] objects can be
/// shared between boxes; [BoxPainter] objects can cache resources to
/// make painting on a particular surface faster.
@immutable
abstract class Decoration extends Diagnosticable {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const Decoration();

  @override
  String toStringShort() => '$runtimeType';

  /// In checked mode, throws an exception if the object is not in a
  /// valid configuration. Otherwise, returns true.
  ///
  /// This is intended to be used as follows:
  /// ```dart
  /// assert(myDecoration.debugAssertIsValid());
  /// ```
  bool debugAssertIsValid() => true;

  /// Returns the insets to apply when using this decoration on a box
  /// that has contents, so that the contents do not overlap the edges
  /// of the decoration. For example, if the decoration draws a frame
  /// around its edge, the padding would return the distance by which
  /// to inset the children so as to not overlap the frame.
  ///
  /// This only works for decorations that have absolute sizes. If the padding
  /// needed would change based on the size at which the decoration is drawn,
  /// then this will return incorrect padding values.
  ///
  /// For example, when a [BoxDecoration] has [BoxShape.circle], the padding
  /// does not take into account that the circle is drawn in the center of the
  /// box regardless of the ratio of the box; it does not provide the extra
  /// padding that is implied by changing the ratio.
  ///
  /// The value returned by this getter must be resolved (using
  /// [EdgeInsetsGeometry.resolve] to obtain an absolute [EdgeInsets]. (For
  /// example, [BorderDirectional] will return an [EdgeInsetsDirectional] for
  /// its [padding].)
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  /// Whether this decoration is complex enough to benefit from caching its painting.
  bool get isComplex => false;

  /// Linearly interpolates from another [Decoration] (which may be of a
  /// different class) to `this`.
  ///
  /// When implementing this method in subclasses, return null if this class
  /// cannot interpolate from `a`. In that case, [lerp] will try `a`'s [lerpTo]
  /// method instead.
  ///
  /// Supporting interpolating from null is recommended as the [Decoration.lerp]
  /// method uses this as a fallback when two classes can't interpolate between
  /// each other.
  ///
  /// The `t` argument represents position on the timeline, with 0.0 meaning
  /// that the interpolation has not started, returning `a` (or something
  /// equivalent to `a`), 1.0 meaning that the interpolation has finished,
  /// returning `this` (or something equivalent to `this`), and values in
  /// between meaning that the interpolation is at the relevant point on the
  /// timeline between `a` and `this`. The interpolation can be extrapolated
  /// beyond 0.0 and 1.0, so negative values and values greater than 1.0 are
  /// valid (and can easily be generated by curves such as
  /// [Curves.elasticInOut]).
  ///
  /// Values for `t` are usually obtained from an [Animation<double>], such as
  /// an [AnimationController].
  ///
  /// Instead of calling this directly, use [Decoration.lerp].
  @protected
  Decoration lerpFrom(Decoration a, double t) => null;

  /// Linearly interpolates from `this` to another [Decoration] (which may be of
  /// a different class).
  ///
  /// This is called if `b`'s [lerpTo] did not know how to handle this class.
  ///
  /// When implementing this method in subclasses, return null if this class
  /// cannot interpolate from `b`. In that case, [lerp] will apply a default
  /// behavior instead.
  ///
  /// Supporting interpolating to null is recommended as the [Decoration.lerp]
  /// method uses this as a fallback when two classes can't interpolate between
  /// each other.
  ///
  /// The `t` argument represents position on the timeline, with 0.0 meaning
  /// that the interpolation has not started, returning `this` (or something
  /// equivalent to `this`), 1.0 meaning that the interpolation has finished,
  /// returning `b` (or something equivalent to `b`), and values in between
  /// meaning that the interpolation is at the relevant point on the timeline
  /// between `this` and `b`. The interpolation can be extrapolated beyond 0.0
  /// and 1.0, so negative values and values greater than 1.0 are valid (and can
  /// easily be generated by curves such as [Curves.elasticInOut]).
  ///
  /// Values for `t` are usually obtained from an [Animation<double>], such as
  /// an [AnimationController].
  ///
  /// Instead of calling this directly, use [Decoration.lerp].
  @protected
  Decoration lerpTo(Decoration b, double t) => null;

  /// Linearly interpolates between two [Decoration]s.
  ///
  /// This attempts to use [lerpFrom] and [lerpTo] on `b` and `a`
  /// respectively to find a solution. If the two values can't directly be
  /// interpolated, then the interpolation is done via null (at `t == 0.5`).
  ///
  /// {@macro dart.ui.shadow.lerp}
  static Decoration lerp(Decoration a, Decoration b, double t) {
    assert(t != null);
    if (a == null && b == null)
      return null;
    if (a == null)
      return b.lerpFrom(null, t) ?? b;
    if (b == null)
      return a.lerpTo(null, t) ?? a;
    if (t == 0.0)
      return a;
    if (t == 1.0)
      return b;
    return b.lerpFrom(a, t)
        ?? a.lerpTo(b, t)
        ?? (t < 0.5 ? (a.lerpTo(null, t * 2.0) ?? a) : (b.lerpFrom(null, (t - 0.5) * 2.0) ?? b));
  }

  /// Tests whether the given point, on a rectangle of a given size,
  /// would be considered to hit the decoration or not. For example,
  /// if the decoration only draws a circle, this function might
  /// return true if the point was inside the circle and false
  /// otherwise.
  ///
  /// The decoration may be sensitive to the [TextDirection]. The
  /// `textDirection` argument should therefore be provided. If it is known that
  /// the decoration is not affected by the text direction, then the argument
  /// may be omitted or set to null.
  ///
  /// When a [Decoration] is painted in a [Container] or [DecoratedBox] (which
  /// is what [Container] uses), the `textDirection` parameter will be populated
  /// based on the ambient [Directionality] (by way of the [RenderDecoratedBox]
  /// renderer).
  bool hitTest(Size size, Offset position, { TextDirection textDirection }) => true;

  /// Returns a [BoxPainter] that will paint this decoration.
  ///
  /// The `onChanged` argument configures [BoxPainter.onChanged]. It can be
  /// omitted if there is no chance that the painter will change (for example,
  /// if it is a [BoxDecoration] with definitely no [DecorationImage]).
  BoxPainter createBoxPainter([ VoidCallback onChanged ]);

  Path getClipPath(Rect rect, TextDirection textDirection) => null;
}

/// A stateful class that can paint a particular [Decoration].
///
/// [BoxPainter] objects can cache resources so that they can be used
/// multiple times.
///
/// Some resources used by [BoxPainter] may load asynchronously. When this
/// happens, the [onChanged] callback will be invoked. To stop this callback
/// from being called after the painter has been discarded, call [dispose].
abstract class BoxPainter {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const BoxPainter([this.onChanged]);

  /// Paints the [Decoration] for which this object was created on the
  /// given canvas using the given configuration.
  ///
  /// The [ImageConfiguration] object passed as the third argument must, at a
  /// minimum, have a non-null [Size].
  ///
  /// If this object caches resources for painting (e.g. [Paint] objects), the
  /// cache may be flushed when [paint] is called with a new configuration. For
  /// this reason, it may be more efficient to call
  /// [Decoration.createBoxPainter] for each different rectangle that is being
  /// painted in a particular frame.
  ///
  /// For example, if a decoration's owner wants to paint a particular
  /// decoration once for its whole size, and once just in the bottom
  /// right, it might get two [BoxPainter] instances, one for each.
  /// However, when its size changes, it could continue using those
  /// same instances, since the previous resources would no longer be
  /// relevant and thus losing them would not be an issue.
  ///
  /// Implementations should paint their decorations on the canvas in a
  /// rectangle whose top left corner is at the given `offset` and whose size is
  /// given by `configuration.size`.
  ///
  /// When a [Decoration] is painted in a [Container] or [DecoratedBox] (which
  /// is what [Container] uses), the [ImageConfiguration.textDirection] property
  /// will be populated based on the ambient [Directionality].
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration);

  /// Callback that is invoked if an asynchronously-loading resource used by the
  /// decoration finishes loading. For example, an image. When this is invoked,
  /// the [paint] method should be called again.
  ///
  /// Resources might not start to load until after [paint] has been called,
  /// because they might depend on the configuration.
  final VoidCallback onChanged;

  /// Discard any resources being held by the object.
  ///
  /// The [onChanged] callback will not be invoked after this method has been
  /// called.
  @mustCallSuper
  void dispose() { }
}