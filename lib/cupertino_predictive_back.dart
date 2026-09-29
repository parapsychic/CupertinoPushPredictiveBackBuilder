/// An Android page transition that slides like iOS on push and follows the
/// predictive back gesture on a back swipe.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The predictive back builder's gesture detector has to stay mounted to
    // catch a swipe starting, so both transitions are always built and only
    // one gets the real route animations; the other gets inert ones.
    //
    // This runs every animation frame, and popGestureInProgress stays true
    // until a committed or cancelled swipe has finished animating, so the
    // switch never happens mid-animation.
    final bool swiping = route.popGestureInProgress;
    return CupertinoPageTransition(
      primaryRouteAnimation: swiping ? kAlwaysCompleteAnimation : animation,
      secondaryRouteAnimation: swiping
          ? kAlwaysDismissedAnimation
          : secondaryAnimation,
      linearTransition: false,
      child: const PredictiveBackPageTransitionsBuilder().buildTransitions<T>(
        route,
        context,
        swiping ? animation : kAlwaysCompleteAnimation,
        swiping ? secondaryAnimation : kAlwaysDismissedAnimation,
        child,
      ),
    );
  }
}
