import 'dart:async';

import 'package:cupertino_predictive_back/cupertino_predictive_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Android sends predictive back events over this channel.
Future<void> _backGesture(
  WidgetTester tester,
  String method, [
  double progress = 0,
]) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
  'flutter/backgesture',
  const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, <String, dynamic>{
      'touchOffset': const <double>[5, 300],
      'progress': progress,
      'swipeEdge': 0, // left
    }),
  ),
  (ByteData? _) {},
);

Iterable<double> _opacities(WidgetTester tester, Finder page) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: page, matching: find.byType(FadeTransition)),
    )
    .map((FadeTransition f) => f.opacity.value);

Rect _pageRect(WidgetTester tester, Finder page) =>
    tester.getRect(find.ancestor(of: page, matching: find.byType(Scaffold)));

Future<GlobalKey<NavigatorState>> _pumpAndPush(
  WidgetTester tester, [
  PageTransitionsBuilder builder = const CupertinoPushPredictiveBackBuilder(),
]) async {
  final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      theme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: builder,
          },
        ),
      ),
      home: const Scaffold(body: Text('home')),
    ),
  );
  unawaited(
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('next')),
      ),
    ),
  );
  return nav;
}

void main() {
  final Finder home = find.text('home');
  final Finder next = find.text('next');

  testWidgets('push slides in from the right without fading', (
    WidgetTester tester,
  ) async {
    await _pumpAndPush(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(next).dx, greaterThan(0));
    // The previous page moves left underneath, like on iOS.
    expect(tester.getTopLeft(home).dx, lessThan(0));
    expect(_opacities(tester, next), everyElement(1.0));
    expect(_opacities(tester, home), everyElement(1.0));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(next).dx, 0);
  });

  testWidgets('button pop slides back out without fading', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> nav = await _pumpAndPush(tester);
    await tester.pumpAndSettle();

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(next).dx, greaterThan(0));
    expect(_opacities(tester, next), everyElement(1.0));

    await tester.pumpAndSettle();
    expect(next, findsNothing);
  });

  testWidgets('zoom push zooms instead of sliding', (
    WidgetTester tester,
  ) async {
    // The zoom paints a scaled snapshot, so the layout rect doesn't change;
    // check that the zoom's snapshot is active instead.
    bool zooming() => tester
        .widgetList<SnapshotWidget>(
          find.ancestor(of: next, matching: find.byType(SnapshotWidget)),
        )
        .any((SnapshotWidget s) => s.controller.allowSnapshotting);

    await _pumpAndPush(tester, const ZoomPushPredictiveBackBuilder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(zooming(), isTrue);
    expect(tester.getTopLeft(next).dx, 0);

    await tester.pumpAndSettle();
    expect(zooming(), isFalse);
  });

  testWidgets('zoom back swipe does not also play the zoom pop', (
    WidgetTester tester,
  ) async {
    await _pumpAndPush(tester, const ZoomPushPredictiveBackBuilder());
    await tester.pumpAndSettle();

    await _backGesture(tester, 'startBackGesture');
    await tester.pump();
    await _backGesture(tester, 'updateBackGestureProgress', 0.3);
    await tester.pump();

    // The zoom exit only paints (fades and scales a snapshot), so the page's
    // rect can't show it; read its animation instead. Flutter's zoom widgets
    // are private, hence the type name.
    final Iterable<double> exits = tester
        .widgetList(
          find.ancestor(
            of: next,
            matching: find.byWidgetPredicate(
              (Widget w) => w.runtimeType.toString() == '_ZoomExitTransition',
            ),
          ),
        )
        .map(
          (Widget w) => ((w as dynamic).animation as Animation<double>).value,
        );
    expect(exits, isNotEmpty);
    expect(exits, everyElement(0.0));
  });

  testWidgets('zoom commitDuration sets how long the commit fade takes', (
    WidgetTester tester,
  ) async {
    Future<double> opacityAfterCommit(Duration commitDuration) async {
      await _pumpAndPush(
        tester,
        ZoomPushPredictiveBackBuilder(popFadeDuration: commitDuration),
      );
      await tester.pumpAndSettle();
      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', 0.5);
      await tester.pump();
      await _backGesture(tester, 'commitBackGesture');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final double opacity = tester
          .widget<Opacity>(
            find.ancestor(of: next, matching: find.byType(Opacity)).first,
          )
          .opacity;
      await tester.pumpAndSettle();
      return opacity;
    }

    expect(await opacityAfterCommit(const Duration(milliseconds: 100)), 0);
    expect(
      await opacityAfterCommit(const Duration(milliseconds: 300)),
      greaterThan(0),
    );
  });

  // The default swipe shrinks the top page; the fullscreen one keeps it
  // full size and moves the page underneath instead.
  for (final (String name, PageTransitionsBuilder builder, Finder moving)
      in <(String, PageTransitionsBuilder, Finder)>[
        ('cupertino', const CupertinoPushPredictiveBackBuilder(), next),
        ('zoom', const ZoomPushPredictiveBackBuilder(), next),
        (
          'cupertino fullscreen',
          const CupertinoPushPredictiveBackFullscreenBuilder(),
          home,
        ),
        (
          'zoom fullscreen',
          const ZoomPushPredictiveBackFullscreenBuilder(),
          home,
        ),
      ]) {
    testWidgets('$name back swipe follows the gesture and pops on commit', (
      WidgetTester tester,
    ) async {
      await _pumpAndPush(tester, builder);
      await tester.pumpAndSettle();
      final Size screen = tester.getSize(find.byType(MaterialApp));

      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', 0.5);
      await tester.pump();
      expect(_pageRect(tester, moving), isNot(Offset.zero & screen));
      expect(home, findsOneWidget);

      await _backGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(next, findsNothing);
      expect(home, findsOneWidget);
    });

    testWidgets('$name cancelled back swipe restores the page', (
      WidgetTester tester,
    ) async {
      await _pumpAndPush(tester, builder);
      await tester.pumpAndSettle();
      final Size screen = tester.getSize(find.byType(MaterialApp));

      await _backGesture(tester, 'startBackGesture');
      await _backGesture(tester, 'updateBackGestureProgress', 0.5);
      await tester.pump();
      await _backGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();

      expect(_pageRect(tester, next), Offset.zero & screen);
    });
  }
}
