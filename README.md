# cupertino_predictive_back

An Android page transition that slides pages in like iOS on push and plays
Android's predictive back animation when the user swipes back.

Flutter's `PredictiveBackPageTransitionsBuilder` only animates the back swipe
itself. Every other navigation (push, back button, `Navigator.pop`) gets a
fixed fade-forwards transition that can't be changed. On apps whose screens
don't match `ColorScheme.surface`, that fade shows up as a flash.
`CupertinoPushPredictiveBackBuilder` keeps the predictive swipe and uses the
Cupertino slide for everything else.

| Navigation | Transition |
| --- | --- |
| Push | Cupertino slide from the right; previous page shifts left |
| Back button / `Navigator.pop` | Cupertino slide back out |
| Back swipe (Android 14+) | Predictive back, following the gesture |

Neither page fades, so no background color shows through.

## Usage

```dart
import 'package:cupertino_predictive_back/cupertino_predictive_back.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

MaterialApp(
  theme: ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPushPredictiveBackBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  ),
  // ...
);
```

It applies to every `MaterialPageRoute` / `MaterialPage`, including pages
built by routers such as go_router.

## Notes

- **Predictive back needs opting in on Android.** Add
  `android:enableOnBackInvokedCallback="true"` to the `<application>` tag in
  `AndroidManifest.xml`. Without it, or below Android 14, a back swipe pops
  with the Cupertino slide.
- **Use it on Android only.** On iOS keep `CupertinoPageTransitionsBuilder`,
  which adds the iOS edge swipe to go back. This builder leaves that swipe out
  because it competes with Android's back gesture.
- Transitions take 500 ms, the standard Cupertino duration.
