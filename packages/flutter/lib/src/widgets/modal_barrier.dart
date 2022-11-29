// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'navigator.dart';
import 'transitions.dart';

/// A widget that modifies the size of the [SemanticsNode.rect] (focus) of its 
/// child widget. It clips the focus in possibily four directions based on the
/// specified [EdgeInsets].
/// 
/// If a [ValueNotifier] is provided, the size of the focus is adjusted based on
/// value changes inside the [ValueNotifier].
/// 
/// If no [ValueNotifier] is provided, the [SemanticsClipper] applies a default
/// value of [EdgeInsets.zero], which preserves the default size of the focus.
/// 
/// See also:
///
///  * [ModalBarrier], which utilizes thi widget to adjust the barrier focus
/// size based on the size of the content layer rendered on top of it.
class SemanticsClipper extends SingleChildRenderObjectWidget{
  /// creates a [SemanticsClipper] that updates the size of the
  /// [SemanticsNode.rect] of its child based on the value inside the provided
  /// [ValueNotifier], or a default value of [EdgeInsets.zero].
  const SemanticsClipper({
    super.key,
    super.child,
    this.clipDetailsNotifier,
  });

  /// The [ValueNotifier] whose value determines how the child's
  /// [SemanticsNode.rect] should be clipped in four directions.
  final ValueNotifier<EdgeInsets>? clipDetailsNotifier;

  @override
  RenderSemanticsClipper createRenderObject(BuildContext context) {
    return RenderSemanticsClipper(clipDetailsNotifier: clipDetailsNotifier,);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSemanticsClipper renderObject) {
    renderObject.clipDetailsNotifier = clipDetailsNotifier;
  }
}
/// Updates the [SemanticsNode.rect] of its child based on the value inside
/// provided [ValueNotifier].
/// If no [ValueNotifier] is provided a value of [EdgeInsets.zero] is used
/// to clip the [SemanticsNode.rect], which essentially uses its default size.
class RenderSemanticsClipper extends RenderProxyBox {
/// Creats a [RenderProxyBox] that Updates the [SemanticsNode.rect] of its child
/// based on the value inside provided [ValueNotifier].
  RenderSemanticsClipper({
    ValueNotifier<EdgeInsets>? clipDetailsNotifier,
    RenderBox? child,
  }) : _clipDetailsNotifier = clipDetailsNotifier,
       super(child);

  ValueNotifier<EdgeInsets>? _clipDetailsNotifier;
  /// The getter and setter retrieves / updates the [ValueNotifier] associated
  /// with this clipper.
  ValueNotifier<EdgeInsets>? get clipDetailsNotifier => _clipDetailsNotifier;
  set clipDetailsNotifier (ValueNotifier<EdgeInsets>? newNotifier) {
    if (_clipDetailsNotifier == newNotifier) {
      return;
    }
    _clipDetailsNotifier = newNotifier;
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    clipDetailsNotifier?.addListener(markNeedsSemanticsUpdate);
  }

  @override
  void detach() {
    clipDetailsNotifier?.removeListener(markNeedsSemanticsUpdate);
    super.detach();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {

    final EdgeInsets clipDetails = _clipDetailsNotifier == null ? EdgeInsets.zero :_clipDetailsNotifier!.value;
    final Rect oldRect = node.rect;
    node.rect = Rect.fromLTRB(oldRect.left - clipDetails.left, oldRect.top - clipDetails.top, oldRect.right - clipDetails.right, oldRect.bottom - clipDetails.bottom);

    super.assembleSemanticsNode(node, config, children);
  }
}

/// A widget that prevents the user from interacting with widgets behind itself.
///
/// The modal barrier is the scrim that is rendered behind each route, which
/// generally prevents the user from interacting with the route below the
/// current route, and normally partially obscures such routes.
///
/// For example, when a dialog is on the screen, the page below the dialog is
/// usually darkened by the modal barrier.
///
/// See also:
///
///  * [ModalRoute], which indirectly uses this widget.
///  * [AnimatedModalBarrier], which is similar but takes an animated [color]
///    instead of a single color value.
class ModalBarrier extends StatelessWidget {
  /// Creates a widget that blocks user interaction.
  const ModalBarrier({
    super.key,
    this.color,
    this.dismissible = true,
    this.onDismiss,
    this.semanticsLabel,
    this.barrierSemanticsDismissible = true,
    this.clipDetailsNotifier,
    this.semanticsOnTapHint,
  });

  /// If non-null, fill the barrier with this color.
  ///
  /// See also:
  ///
  ///  * [ModalRoute.barrierColor], which controls this property for the
  ///    [ModalBarrier] built by [ModalRoute] pages.
  final Color? color;

  /// Specifies if the barrier will be dismissed when the user taps on it.
  ///
  /// If true, and [onDismiss] is non-null, [onDismiss] will be called,
  /// otherwise the current route will be popped from the ambient [Navigator].
  ///
  /// If false, tapping on the barrier will do nothing.
  ///
  /// See also:
  ///
  ///  * [ModalRoute.barrierDismissible], which controls this property for the
  ///    [ModalBarrier] built by [ModalRoute] pages.
  final bool dismissible;

  /// {@template flutter.widgets.ModalBarrier.onDismiss}
  /// Called when the barrier is being dismissed.
  ///
  /// If non-null [onDismiss] will be called in place of popping the current
  /// route. It is up to the callback to handle dismissing the barrier.
  ///
  /// If null, the ambient [Navigator]'s current route will be popped.
  ///
  /// This field is ignored if [dismissible] is false.
  /// {@endtemplate}
  final VoidCallback? onDismiss;

  /// Whether the modal barrier semantics are included in the semantics tree.
  ///
  /// See also:
  ///
  ///  * [ModalRoute.semanticsDismissible], which controls this property for
  ///    the [ModalBarrier] built by [ModalRoute] pages.
  final bool? barrierSemanticsDismissible;

  /// Semantics label used for the barrier if it is [dismissible].
  ///
  /// The semantics label is read out by accessibility tools (e.g. TalkBack
  /// on Android and VoiceOver on iOS) when the barrier is focused.
  ///
  /// See also:
  ///
  ///  * [ModalRoute.barrierLabel], which controls this property for the
  ///    [ModalBarrier] built by [ModalRoute] pages.
  final String? semanticsLabel;

  /// This [ValueNotifier] contains a value of type [EdgeInsets] that specifies
  /// how the [SemanticsNode.rect] of the barrier should be clipped (so that
  /// it does not overlap with the content rendered on top of it).
  /// 
  /// See also"
  ///
  ///  * [SemanticsClipper], which utilizes the value inside this [ValueNotifier]
  /// to update the [SemanticsNode.rect] for its child.
  final ValueNotifier<EdgeInsets>? clipDetailsNotifier;

  /// This hint text instructs user what they are able to do when they tap on
  /// the [ModalBarrier], annouced in the format of 'Double tap to
  /// $[semanticsOnTapHint].' 
  /// 
  /// If this value is null, the default onTapHint will be applied, resulting
  /// in the annoucement of 'Double tap to activate'.
  final String? semanticsOnTapHint;

  @override
  Widget build(BuildContext context) {
    assert(!dismissible || semanticsLabel == null || debugCheckHasDirectionality(context));
    final bool platformSupportsDismissingBarrier;
    switch (defaultTargetPlatform) {
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        platformSupportsDismissingBarrier = false;
        break;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        platformSupportsDismissingBarrier = true;
        break;
    }
    assert(platformSupportsDismissingBarrier != null);
    final bool semanticsDismissible = dismissible && platformSupportsDismissingBarrier;
    final bool modalBarrierSemanticsDismissible = barrierSemanticsDismissible ?? semanticsDismissible;

    void handleDismiss() {
      if (dismissible) {
        if (onDismiss != null) {
          onDismiss!();
        } else {
          Navigator.maybePop(context);
        }
      } else {
        SystemSound.play(SystemSoundType.alert);
      }
    }

    return BlockSemantics(
      child: ExcludeSemantics(
        // On Android, the back button is used to dismiss a modal. On iOS, some
        // modal barriers are not dismissible in accessibility mode.
        excluding: !semanticsDismissible || !modalBarrierSemanticsDismissible,
        child: _ModalBarrierGestureDetector(
          onDismiss: handleDismiss,
          child: SemanticsClipper(
            clipDetailsNotifier: clipDetailsNotifier,
            child: Semantics(
              onTapHint: semanticsOnTapHint,
              onTap: handleDismiss,
              label: semanticsDismissible ? semanticsLabel : null,
              onDismiss: semanticsDismissible ? handleDismiss : null,
              textDirection: semanticsDismissible && semanticsLabel != null ? Directionality.of(context) : null,
              child: MouseRegion(
                cursor: SystemMouseCursors.basic,
                child: ConstrainedBox(
                constraints: const BoxConstraints.expand(),
                child: color == null ? null : ColoredBox(
                  color: color!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A widget that prevents the user from interacting with widgets behind itself,
/// and can be configured with an animated color value.
///
/// The modal barrier is the scrim that is rendered behind each route, which
/// generally prevents the user from interacting with the route below the
/// current route, and normally partially obscures such routes.
///
/// For example, when a dialog is on the screen, the page below the dialog is
/// usually darkened by the modal barrier.
///
/// This widget is similar to [ModalBarrier] except that it takes an animated
/// [color] instead of a single color.
///
/// See also:
///
///  * [ModalRoute], which uses this widget.
class AnimatedModalBarrier extends AnimatedWidget {
  /// Creates a widget that blocks user interaction.
  const AnimatedModalBarrier({
    super.key,
    required Animation<Color?> color,
    this.dismissible = true,
    this.semanticsLabel,
    this.barrierSemanticsDismissible,
    this.onDismiss,
    this.clipDetailsNotifier,
    this.semanticsOnTapHint,
  }) : super(listenable: color);

  /// If non-null, fill the barrier with this color.
  ///
  /// See also:
  ///
  ///  * [ModalRoute.barrierColor], which controls this property for the
  ///    [AnimatedModalBarrier] built by [ModalRoute] pages.
  Animation<Color?> get color => listenable as Animation<Color?>;

  /// Whether touching the barrier will pop the current route off the [Navigator].
  ///
  /// See also:
  ///
  ///  * [ModalRoute.barrierDismissible], which controls this property for the
  ///    [AnimatedModalBarrier] built by [ModalRoute] pages.
  final bool dismissible;

  /// Semantics label used for the barrier if it is [dismissible].
  ///
  /// The semantics label is read out by accessibility tools (e.g. TalkBack
  /// on Android and VoiceOver on iOS) when the barrier is focused.
  /// See also:
  ///
  ///  * [ModalRoute.barrierLabel], which controls this property for the
  ///    [ModalBarrier] built by [ModalRoute] pages.
  final String? semanticsLabel;

  /// Whether the modal barrier semantics are included in the semantics tree.
  ///
  /// See also:
  ///
  ///  * [ModalRoute.semanticsDismissible], which controls this property for
  ///    the [ModalBarrier] built by [ModalRoute] pages.
  final bool? barrierSemanticsDismissible;

  /// {@macro flutter.widgets.ModalBarrier.onDismiss}
  final VoidCallback? onDismiss;

  /// This [ValueNotifier] contains a value of type [EdgeInsets] that specifies
  /// how the [SemanticsNode.rect] of the barrier should be clipped (so that
  /// it does not overlap with the content rendered on top of it).
  /// 
  /// See also"
  ///
  ///  * [SemanticsClipper], which utilizes the value inside this [ValueNotifier]
  /// to update the [SemanticsNode.rect] for its child.
  final ValueNotifier<EdgeInsets>? clipDetailsNotifier;

  /// This hint text instructs user what they are able to do when they tap on
  /// the [ModalBarrier], annouced in the format of 'Double tap to
  /// $[semanticsOnTapHint].' 
  /// 
  /// If this value is null, the default onTapHint will be applied, resulting
  /// in the annoucement of 'Double tap to activate'.
  final String? semanticsOnTapHint;

  @override
  Widget build(BuildContext context) {
    return ModalBarrier(
      color: color.value,
      dismissible: dismissible,
      semanticsLabel: semanticsLabel,
      barrierSemanticsDismissible: barrierSemanticsDismissible,
      onDismiss: onDismiss,
      clipDetailsNotifier: clipDetailsNotifier,
      semanticsOnTapHint: semanticsOnTapHint,
    );
  }
}

// Recognizes tap down by any pointer button.
//
// It is similar to [TapGestureRecognizer.onTapDown], but accepts any single
// button, which means the gesture also takes parts in gesture arenas.
class _AnyTapGestureRecognizer extends BaseTapGestureRecognizer {
  _AnyTapGestureRecognizer();

  VoidCallback? onAnyTapUp;

  @protected
  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (onAnyTapUp == null) {
      return false;
    }
    return super.isPointerAllowed(event);
  }

  @protected
  @override
  void handleTapDown({PointerDownEvent? down}) {
    // Do nothing.
  }

  @protected
  @override
  void handleTapUp({PointerDownEvent? down, PointerUpEvent? up}) {
    onAnyTapUp?.call();
  }

  @protected
  @override
  void handleTapCancel({PointerDownEvent? down, PointerCancelEvent? cancel, String? reason}) {
    // Do nothing.
  }

  @override
  String get debugDescription => 'any tap';
}

class _ModalBarrierSemanticsDelegate extends SemanticsGestureDelegate {
  const _ModalBarrierSemanticsDelegate({this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    renderObject.onTap = onDismiss;
  }
}

class _AnyTapGestureRecognizerFactory extends GestureRecognizerFactory<_AnyTapGestureRecognizer> {
  const _AnyTapGestureRecognizerFactory({this.onAnyTapUp});

  final VoidCallback? onAnyTapUp;

  @override
  _AnyTapGestureRecognizer constructor() => _AnyTapGestureRecognizer();

  @override
  void initializer(_AnyTapGestureRecognizer instance) {
    instance.onAnyTapUp = onAnyTapUp;
  }
}

// A GestureDetector used by ModalBarrier. It only has one callback,
// [onAnyTapDown], which recognizes tap down unconditionally.
class _ModalBarrierGestureDetector extends StatelessWidget {
  const _ModalBarrierGestureDetector({
    required this.child,
    required this.onDismiss,
  }) : assert(child != null),
       assert(onDismiss != null);

  /// The widget below this widget in the tree.
  /// See [RawGestureDetector.child].
  final Widget child;

  /// Immediately called when an event that should dismiss the modal barrier
  /// has happened.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{
      _AnyTapGestureRecognizer: _AnyTapGestureRecognizerFactory(onAnyTapUp: onDismiss),
    };

    return RawGestureDetector(
      gestures: gestures,
      behavior: HitTestBehavior.opaque,
      semantics: _ModalBarrierSemanticsDelegate(onDismiss: onDismiss),
      child: child,
    );
  }
}
