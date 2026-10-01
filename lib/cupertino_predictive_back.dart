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

/// Shared by the builders below: [_push] for pushes and pops, and a
/// predictive back animation for back swipes.
abstract class _PushPredictiveBackBuilder extends PageTransitionsBuilder {
  const _PushPredictiveBackBuilder({
    this.popFadeDuration = const Duration(milliseconds: 150),
  });

  /// How long the page takes to fade and zoom out after a back swipe commits.
  ///
  /// It can't be longer than the pop transition (300 ms); longer values are
  /// treated as 300 ms. [ZoomPushPredictiveBackFullscreenBuilder] ignores it;
  /// Flutter's full-screen animation has its own fixed fade.
  final Duration popFadeDuration;

  PageTransitionsBuilder get _push;

  // Whether the swipe wraps the push transition rather than sitting inside it.
  bool get _swipeOutside => false;

  PageTransitionsBuilder get _swipe => _SwipeBuilder(popFadeDuration);

  @override
  Duration get transitionDuration => _push.transitionDuration;

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
        _push.buildTransitions<T>(route, context, primary, secondary, child),
    swipeOutside: _swipeOutside,
  );
}

/// Zooms pages in and out like Android ([ZoomPageTransitionsBuilder]) on push and pop, and plays a predictive back animation while
/// the user swipes back: the page shrinks and moves away from the swiped edge,
/// then fades and zooms out when the swipe commits.
///
/// * Push, back button, `Navigator.pop`: Android's zoom transition.
/// * Back swipe (Android 14+): the predictive back animation, driven by the
///   gesture. The page underneath stays still.
///
/// For the full-screen predictive back animation instead, use
/// [ZoomPushPredictiveBackFullscreenBuilder].
class ZoomPushPredictiveBackBuilder extends _PushPredictiveBackBuilder {
  /// Creates a [ZoomPushPredictiveBackBuilder].
  const ZoomPushPredictiveBackBuilder({super.popFadeDuration});

  @override
  PageTransitionsBuilder get _push => const ZoomPageTransitionsBuilder();
}

/// Like [ZoomPushPredictiveBackBuilder], but a back swipe plays Android's full-screen
/// predictive back animation ([PredictiveBackFullscreenPageTransitionsBuilder]):
/// the page stays full size and the page underneath moves into place.
class ZoomPushPredictiveBackFullscreenBuilder
    extends ZoomPushPredictiveBackBuilder {
  /// Creates a [ZoomPushPredictiveBackFullscreenBuilder].
  const ZoomPushPredictiveBackFullscreenBuilder();

  @override
  PageTransitionsBuilder get _swipe =>
      const PredictiveBackFullscreenPageTransitionsBuilder();
}

/// Fades pages in and out upwards like Android 8 ([FadeUpwardsPageTransitionsBuilder]) on push
/// and pop, and plays a predictive back animation while the user swipes back:
/// the page slides down with the gesture, then carries on down and fades out
/// when the swipe commits.
///
/// * Push, back button, `Navigator.pop`: Android 8's fade upwards.
/// * Back swipe (Android 14+): the predictive back animation, driven by the
///   gesture. The page underneath stays still.
///
/// For the full-screen version, use [FadeUpwardsPushPredictiveBackFullscreenBuilder].
class FadeUpwardsPushPredictiveBackBuilder extends _PushPredictiveBackBuilder {
  /// Creates a [FadeUpwardsPushPredictiveBackBuilder].
  const FadeUpwardsPushPredictiveBackBuilder({super.popFadeDuration});

  @override
  PageTransitionsBuilder get _push => const FadeUpwardsPageTransitionsBuilder();

  @override
  bool get _swipeOutside => true;

  @override
  PageTransitionsBuilder get _swipe =>
      _SwipeBuilder(popFadeDuration, downwards: true);
}

/// Like [FadeUpwardsPushPredictiveBackBuilder], but in the full-screen style: during a back swipe the
/// page slides down more slowly and fades out as the gesture goes on, rather
/// than staying opaque until the swipe commits.
class FadeUpwardsPushPredictiveBackFullscreenBuilder
    extends FadeUpwardsPushPredictiveBackBuilder {
  /// Creates a [FadeUpwardsPushPredictiveBackFullscreenBuilder].
  const FadeUpwardsPushPredictiveBackFullscreenBuilder({super.popFadeDuration});

  @override
  PageTransitionsBuilder get _swipe =>
      _SwipeBuilder(popFadeDuration, downwards: true, fullscreen: true);
}

/// Opens pages upwards like Android 9 ([OpenUpwardsPageTransitionsBuilder]) on push
/// and pop, and plays a predictive back animation while the user swipes back:
/// the page slides down with the gesture, then carries on down and fades out
/// when the swipe commits.
///
/// * Push, back button, `Navigator.pop`: Android 9's open upwards.
/// * Back swipe (Android 14+): the predictive back animation, driven by the
///   gesture. The page underneath stays still.
///
/// For the full-screen version, use [OpenUpwardsPushPredictiveBackFullscreenBuilder].
class OpenUpwardsPushPredictiveBackBuilder extends _PushPredictiveBackBuilder {
  /// Creates a [OpenUpwardsPushPredictiveBackBuilder].
  const OpenUpwardsPushPredictiveBackBuilder({super.popFadeDuration});

  @override
  PageTransitionsBuilder get _push => const OpenUpwardsPageTransitionsBuilder();

  @override
  bool get _swipeOutside => true;

  @override
  PageTransitionsBuilder get _swipe =>
      _SwipeBuilder(popFadeDuration, downwards: true);
}

/// Like [OpenUpwardsPushPredictiveBackBuilder], but in the full-screen style: during a back swipe the
/// page slides down more slowly and fades out as the gesture goes on, rather
/// than staying opaque until the swipe commits.
class OpenUpwardsPushPredictiveBackFullscreenBuilder
    extends OpenUpwardsPushPredictiveBackBuilder {
  /// Creates a [OpenUpwardsPushPredictiveBackFullscreenBuilder].
  const OpenUpwardsPushPredictiveBackFullscreenBuilder({super.popFadeDuration});

  @override
  PageTransitionsBuilder get _swipe =>
      _SwipeBuilder(popFadeDuration, downwards: true, fullscreen: true);
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
  push, {
  bool swipeOutside = false,
}) {
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
  //
  // With swipeOutside, the swipe wraps the push transition instead, so it also
  // moves and fades whatever the push transition paints around the page, such
  // as OpenUpwards' scrim.
  final bool swiping = route.popGestureInProgress;
  Widget swiped(Widget child) => swipe.buildTransitions<T>(
    route,
    context,
    swiping ? animation : kAlwaysCompleteAnimation,
    swiping ? secondaryAnimation : kAlwaysDismissedAnimation,
    child,
  );
  Widget pushed(Widget child) => push(
    _NotWhileSwiping(animation, route, AnimationStatus.completed),
    _NotWhileSwiping(secondaryAnimation, route, AnimationStatus.dismissed),
    child,
  );
  return swipeOutside ? swiped(pushed(child)) : pushed(swiped(child));
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

// Gesture progress at which the full-screen downwards swipe has faded the page
// out completely. Android reports about 0.3 for a swipe across a third of the
// screen, so 0.4 is roughly a half-screen swipe.
// ponytail: fixed; make it a builder option if apps want to tune it.
const double _kFullscreenFadedAt = 0.4;

/// The default back swipe of the builders built on [_PushPredictiveBackBuilder].
class _SwipeBuilder extends PageTransitionsBuilder {
  const _SwipeBuilder(
    this.commitDuration, {
    this.downwards = false,
    this.fullscreen = false,
  });

  final Duration commitDuration;

  /// Slide the page down instead of shrinking it, for the upwards push
  /// transitions.
  final bool downwards;

  /// With [downwards], slide more slowly and fade out during the gesture.
  final bool fullscreen;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _Swipe(
    route: route,
    animation: animation,
    commitDuration: commitDuration,
    downwards: downwards,
    fullscreen: fullscreen,
    child: child,
  );
}

class _Swipe extends StatefulWidget {
  const _Swipe({
    required this.route,
    required this.animation,
    required this.commitDuration,
    required this.downwards,
    required this.fullscreen,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Duration commitDuration;
  final bool downwards;

  /// With [downwards], slide more slowly and fade out during the gesture.
  final bool fullscreen;
  final Widget child;

  @override
  State<_Swipe> createState() => _SwipeState();
}

class _SwipeState extends State<_Swipe> with WidgetsBindingObserver {
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
    final Size size = MediaQuery.sizeOf(context);
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
        if (widget.downwards) {
          // The page follows the gesture down (half as fast in the
          // full-screen style, which also fades it as the gesture goes on),
          // then carries on to a quarter of the screen height while it fades,
          // the reverse of the upwards push.
          final double end = size.height / 4;
          final double dragged = end * progress * (widget.fullscreen ? 0.5 : 1);
          final double fade = widget.fullscreen
              ? clampDouble(1 - progress / _kFullscreenFadedAt, 0, 1)
              : 1;
          return Opacity(
            opacity: clampDouble(fade * committed, 0, 1),
            child: Transform.translate(
              offset: Offset(0, end + (dragged - end) * committed),
              child: child,
            ),
          );
        }
        // Scale, shift and corner radius follow Android's predictive back
        // motion spec.
        // ponytail: ignores vertical drag, add a y shift if it's missed.
        final double shift = (size.width / 20 - 8) * progress;
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
