import 'package:cupertino_predictive_back/cupertino_predictive_back.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The Android builders to compare, with what their push and pop look like.
const List<(String, String, PageTransitionsBuilder)> _builders =
    <(String, String, PageTransitionsBuilder)>[
      (
        'CupertinoPushPredictiveBackBuilder',
        'Push and pop slide like iOS',
        CupertinoPushPredictiveBackBuilder(),
      ),
      (
        'CupertinoPushPredictiveBackFullscreenBuilder',
        'Push and pop slide like iOS; full-screen back swipe',
        CupertinoPushPredictiveBackFullscreenBuilder(),
      ),
      (
        'ZoomPushPredictiveBackBuilder',
        'Push and pop zoom like Android',
        ZoomPushPredictiveBackBuilder(),
      ),
      (
        'ZoomPushPredictiveBackFullscreenBuilder',
        'Push and pop zoom like Android; full-screen back swipe',
        ZoomPushPredictiveBackFullscreenBuilder(),
      ),
      (
        'PredictiveBackPageTransitionsBuilder',
        "Flutter's builder: push and pop fade",
        PredictiveBackPageTransitionsBuilder(),
      ),
    ];

/// Switches the Android builder so they can be compared.
final ValueNotifier<PageTransitionsBuilder> androidBuilder =
    ValueNotifier<PageTransitionsBuilder>(_builders.first.$3);

void main() => runApp(
  ValueListenableBuilder<PageTransitionsBuilder>(
    valueListenable: androidBuilder,
    builder: (_, builder, _) => MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: builder,
            TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const _Page(depth: 0),
    ),
  ),
);

class _Page extends StatelessWidget {
  const _Page({required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) {
    // Pages are deliberately not ColorScheme.surface, so the default builder's
    // fade shows up as a flash.
    final Color color =
        Colors.primaries[depth * 5 % Colors.primaries.length].shade100;
    final bool android = Theme.of(context).platform == TargetPlatform.android;
    return Scaffold(
      backgroundColor: color,
      appBar: AppBar(backgroundColor: color, title: Text('Page $depth')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // The picker only swaps the Android builder.
          if (android) ...<Widget>[
            ValueListenableBuilder<PageTransitionsBuilder>(
              valueListenable: androidBuilder,
              builder: (_, current, _) => Column(
                children: <Widget>[
                  for (final (title, subtitle, builder) in _builders)
                    ListTile(
                      leading: Icon(
                        builder == current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(title),
                      subtitle: Text(subtitle),
                      onTap: () => androidBuilder.value = builder,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            android
                ? 'Push, Pop and the app bar back button play the push/pop '
                      'transition. Swipe back from the screen edge (Android '
                      '14+) for the predictive back animation.'
                : 'iOS uses CupertinoPageTransitionsBuilder. Swipe from the '
                      'left edge to go back.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => _Page(depth: depth + 1)),
            ),
            child: const Text('Push'),
          ),
          if (depth > 0)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Pop'),
            ),
        ],
      ),
    );
  }
}
