import 'package:cupertino_predictive_back/cupertino_predictive_back.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Switches the Android builder so it can be compared with Flutter's default.
final ValueNotifier<bool> useCupertinoPush = ValueNotifier<bool>(true);

void main() => runApp(
  ValueListenableBuilder<bool>(
    valueListenable: useCupertinoPush,
    builder: (_, cupertinoPush, _) => MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: cupertinoPush
                ? const CupertinoPushPredictiveBackBuilder()
                : const PredictiveBackPageTransitionsBuilder(),
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
          // The switch only swaps the Android builder.
          if (android) ...<Widget>[
            ValueListenableBuilder<bool>(
              valueListenable: useCupertinoPush,
              builder: (_, cupertinoPush, _) => SwitchListTile(
                title: const Text('CupertinoPushPredictiveBackBuilder'),
                subtitle: Text(
                  cupertinoPush
                      ? 'Push and pop slide like iOS'
                      : "Off: Flutter's PredictiveBackPageTransitionsBuilder, "
                            'push and pop fade',
                ),
                value: cupertinoPush,
                onChanged: (value) => useCupertinoPush.value = value,
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
