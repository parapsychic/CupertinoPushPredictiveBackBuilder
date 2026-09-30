/// An Android page transition that slides like iOS on push and follows the
/// predictive back gesture on a back swipe.
library;

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Slides pages in and out like iOS ([CupertinoPageTransition]) on push and
/// pop, and plays Android's predictive back animation while the user swipes
/// back.
///
/// [PredictiveBackPageTransitionsBuilder] only animates the swipe itself. Every
/// other push or pop gets a fixed fade-forwards transition that can't be
/// changed. This builder keeps the predictive swipe and uses the Cupertino
/// slide for everything else:
///
/// * Push, back button, `Navigator.pop`: Cupertino slide from the right, with
///   the previous page moving left underneath. No fade.
/// * Back swipe (Android 14+): the predictive back animation, driven by the
///   gesture.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     pageTransitionsTheme: const PageTransitionsTheme(
///       builders: <TargetPlatform, PageTransitionsBuilder>{
///         TargetPlatform.android: CupertinoPushPredictiveBackBuilder(),
///         TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
///       },
///     ),
///   ),
/// )
/// ```
///
/// Use it for Android. On iOS keep [CupertinoPageTransitionsBuilder], which
/// adds the iOS edge swipe to go back. This builder leaves that swipe out
/// because it competes with Android's back gesture.
class CupertinoPushPredictiveBackBuilder extends PageTransitionsBuilder {
  /// Creates a [CupertinoPushPredictiveBackBuilder].
  const CupertinoPushPredictiveBackBuilder();

  @override
  Duration get transitionDuration =>
      CupertinoRouteTransitionMixin.kTransitionDuration;

  PageTransitionsBuilder get _swipe =>
      const PredictiveBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _withPredictiveBack(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
      _swipe,
      (Animation<double> primary, Animation<double> secondary, Widget child) =>
          CupertinoPageTransition(
            primaryRouteAnimation: primary,
            secondaryRouteAnimation: secondary,
            linearTransition: false,
            child: child,
          ),
    );
  }
}

/// Like [CupertinoPushPredictiveBackBuilder], but a back swipe plays Android's
/// full-screen predictive back animation
/// ([PredictiveBackFullscreenPageTransitionsBuilder]) instead of the default
/// one, where the page shrinks away from the swipe.
class CupertinoPushPredictiveBackFullscreenBuilder
    extends CupertinoPushPredictiveBackBuilder {
  /// Creates a [CupertinoPushPredictiveBackFullscreenBuilder].
  const CupertinoPushPredictiveBackFullscreenBuilder();

  @override
  PageTransitionsBuilder get _swipe =>
      const PredictiveBackFullscreenPageTransitionsBuilder();
}

/// Zooms pages in and out like Android ([ZoomPageTransitionsBuilder]) on push
/// and pop, and plays a predictive back animation while the user swipes back:
/// the page shrinks and moves away from the swiped edge, then fades and zooms
/// out when the swipe commits.
///
/// For zoom with the full-screen predictive back animation instead, use
/// Flutter's [PredictiveBackFullscreenPageTransitionsBuilder].
///
/// * Push, back button, `Navigator.pop`: Android's zoom transition.
/// * Back swipe (Android 14+): the predictive back animation, driven by the
///   gesture. The page underneath stays still.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     pageTransitionsTheme: const PageTransitionsTheme(
///       builders: <TargetPlatform, PageTransitionsBuilder>{
///         TargetPlatform.android: ZoomPushPredictiveBackBuilder(),
///       },
///     ),
///   ),
/// )
/// ```
class ZoomPushPredictiveBackBuilder extends PageTransitionsBuilder {
  /// Creates a [ZoomPushPredictiveBackBuilder].
  const ZoomPushPredictiveBackBuilder({
    this.popFadeDuration = const Duration(milliseconds: 150),
  });

  /// How long the page takes to fade and zoom out after a back swipe commits.
  ///
  /// It can't be longer than the pop transition (300 ms); longer values are
  /// treated as 300 ms.
  final Duration popFadeDuration;

  static const ZoomPageTransitionsBuilder _zoom = ZoomPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _zoom.transitionDuration;

  PageTransitionsBuilder get _swipe => _ZoomSwipeBuilder(popFadeDuration);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _withPredictiveBack(
    route,
    context,
    animation,
    secondaryAnimation,
    child,
    _swipe,
    (Animation<double> primary, Animation<double> secondary, Widget child) =>
        _zoom.buildTransitions<T>(route, context, primary, secondary, child),
  );
}

/// Like [ZoomPushPredictiveBackBuilder], but a back swipe plays Android's
/// full-screen predictive back animation
/// ([PredictiveBackFullscreenPageTransitionsBuilder]): the page stays full size
/// and the page underneath moves into place.
///
/// [popFadeDuration] has no effect here; the full-screen animation has its own
/// fixed fade.
class ZoomPushPredictiveBackFullscreenBuilder
    extends ZoomPushPredictiveBackBuilder {
  /// Creates a [ZoomPushPredictiveBackFullscreenBuilder].
  const ZoomPushPredictiveBackFullscreenBuilder();

  @override
  PageTransitionsBuilder get _swipe =>
      const PredictiveBackFullscreenPageTransitionsBuilder();
}

/// Wraps [child] in the [swipe] transition, inside the [push] transition used
/// for everything but a back swipe.
Widget _withPredictiveBack<T>(
  PageRoute<T> route,
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
  PageTransitionsBuilder swipe,
  Widget Function(
    Animation<double> primary,
    Animation<double> secondary,
    Widget child,
  )
  push,
) {
  // The predictive back builder's gesture detector has to stay mounted to
  // catch a swipe starting, so both transitions are always built and only
  // one gets the real route animations; the other gets inert ones.
  //
  // This runs every animation frame, and popGestureInProgress stays true
  // until a committed or cancelled swipe has finished animating, so the
  // switch never happens mid-animation.
  //
  // The push transition gets gated animations instead of swapped ones: the
  // zoom transition keeps the first animation it was given in places, so a
  // swapped-out route animation would go on driving it during the swipe.
  final bool swiping = route.popGestureInProgress;
  return push(
    _NotWhileSwiping(animation, route, AnimationStatus.completed),
    _NotWhileSwiping(secondaryAnimation, route, AnimationStatus.dismissed),
    swipe.buildTransitions<T>(
      route,
      context,
      swiping ? animation : kAlwaysCompleteAnimation,
      swiping ? secondaryAnimation : kAlwaysDismissedAnimation,
      child,
    ),
  );
}

/// Follows [parent], but holds at the end given by [swipingStatus] while a
/// back swipe is in progress.
class _NotWhileSwiping extends Animation<double>
    with AnimationWithParentMixin<double> {
  _NotWhileSwiping(this.parent, this.route, this.swipingStatus);

  @override
  final Animation<double> parent;
  final PageRoute<dynamic> route;
  final AnimationStatus swipingStatus;

  @override
  double get value => route.popGestureInProgress
      ? (swipingStatus == AnimationStatus.completed ? 1 : 0)
      : parent.value;

  @override
  AnimationStatus get status =>
      route.popGestureInProgress ? swipingStatus : parent.status;
}

/// [ZoomPushPredictiveBackBuilder]'s back swipe.
class _ZoomSwipeBuilder extends PageTransitionsBuilder {
  const _ZoomSwipeBuilder(this.commitDuration);

  final Duration commitDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _ZoomSwipe(
    route: route,
    animation: animation,
    commitDuration: commitDuration,
    child: child,
  );
}

class _ZoomSwipe extends StatefulWidget {
  const _ZoomSwipe({
    required this.route,
    required this.animation,
    required this.commitDuration,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Duration commitDuration;
  final Widget child;

  @override
  State<_ZoomSwipe> createState() => _ZoomSwipeState();
}

class _ZoomSwipeState extends State<_ZoomSwipe> with WidgetsBindingObserver {
  // Whether this route is the one being swiped away.
  bool _swiped = false;
  SwipeEdge _edge = SwipeEdge.left;
  // Gesture progress when the swipe committed, or null before that. The route
  // animation restarts from 1 on commit, so the page holds this pose and only
  // fades and zooms out from there.
  double? _committedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final PageRoute<dynamic> route = widget.route;
    if (backEvent.isButtonEvent ||
        !route.isCurrent ||
        !route.popGestureEnabled) {
      return false;
    }
    setState(() {
      _swiped = true;
      _edge = backEvent.swipeEdge;
      _committedAt = null;
    });
    route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    setState(() => _committedAt = 1 - widget.animation.value);
    widget.route.handleCommitBackGesture();
  }

  double get _commitFraction {
    final int pop = widget.route.reverseTransitionDuration.inMicroseconds;
    final int commit = widget.commitDuration.inMicroseconds;
    return pop <= 0 || commit >= pop ? 1 : max(commit, 1) / pop;
  }

  @override
  Widget build(BuildContext context) {
    if (!_swiped || !widget.route.popGestureInProgress) {
      return widget.child;
    }
    final double width = MediaQuery.widthOf(context);
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (BuildContext context, Widget? child) {
        final double value = widget.animation.value;
        final double progress = _committedAt ?? 1 - value;
        // After a commit the route animation runs 1 -> 0 over the pop
        // duration; the fade and zoom-out use only its first commitDuration.
        final double committed = _committedAt == null
            ? 1
            : clampDouble(1 - (1 - value) / _commitFraction, 0, 1);
        // Scale, shift and corner radius follow Android's predictive back
        // motion spec.
        // ponytail: ignores vertical drag, add a y shift if it's missed.
        final double shift = (width / 20 - 8) * progress;
        return Opacity(
          opacity: committed,
          child: Transform.translate(
            offset: Offset(_edge == SwipeEdge.left ? shift : -shift, 0),
            child: Transform.scale(
              scale: (1 - 0.1 * progress) * (0.9 + 0.1 * committed),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32 * progress),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
