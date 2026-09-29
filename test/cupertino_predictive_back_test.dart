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

Future<GlobalKey<NavigatorState>> _pumpAndPush(WidgetTester tester) async {
  final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: CupertinoPushPredictiveBackBuilder(),
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

  testWidgets('back swipe shrinks the page and pops on commit', (
    WidgetTester tester,
  ) async {
    await _pumpAndPush(tester);
    await tester.pumpAndSettle();
    final Size screen = tester.getSize(find.byType(MaterialApp));

    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 0.5);
    await tester.pump();
    final Rect page = _pageRect(tester, next);
    expect(page.width, lessThan(screen.width));
    expect(page.height, lessThan(screen.height));
    expect(home, findsOneWidget);

    await _backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(next, findsNothing);
    expect(home, findsOneWidget);
  });

  testWidgets('cancelled back swipe restores the page', (
    WidgetTester tester,
  ) async {
    await _pumpAndPush(tester);
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
