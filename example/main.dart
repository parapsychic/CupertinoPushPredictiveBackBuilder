import 'package:cupertino_predictive_back/cupertino_predictive_back.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() => runApp(
  MaterialApp(
    theme: ThemeData(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPushPredictiveBackBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    ),
    home: const _Page(depth: 0),
  ),
);

class _Page extends StatelessWidget {
  const _Page({required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Page $depth')),
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _Page(depth: depth + 1)),
        ),
        child: const Text('Push'),
      ),
    ),
  );
}
