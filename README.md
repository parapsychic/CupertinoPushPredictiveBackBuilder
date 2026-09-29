# cupertino_predictive_back

iOS-style page transitions on both Android and iOS. Pages slide in like iOS on
push, and Android keeps its predictive back animation when the user swipes
back.

<img src="https://raw.githubusercontent.com/parapsychic/CupertinoPushPredictiveBackBuilder/main/doc/demo.gif" alt="Push slides in like iOS; a back swipe plays Android's predictive back animation" width="320">

Flutter's `PredictiveBackPageTransitionsBuilder` only animates the back swipe
itself. Every other navigation (push, back button, `Navigator.pop`) gets a
fixed fade-forwards transition that can't be changed. On apps whose screens
don't match `ColorScheme.surface`, that fade shows up as a flash.
`CupertinoPushPredictiveBackBuilder` keeps the predictive swipe and uses the
Cupertino slide for everything else, so Android navigation looks like iOS.

| Navigation | Android | iOS |
| --- | --- | --- |
| Push | Cupertino slide from the right; previous page shifts left | Same |
| Back button / `Navigator.pop` | Cupertino slide back out | Same |
| Back swipe | Predictive back, following the gesture (Android 14+) | iOS edge swipe |

Neither page fades, so no background color shows through.

## Usage

Map Android to `CupertinoPushPredictiveBackBuilder` and iOS to Flutter's
`CupertinoPageTransitionsBuilder`:

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
- **iOS uses `CupertinoPageTransitionsBuilder`.** It has the same slide and
  adds the iOS edge swipe to go back. `CupertinoPushPredictiveBackBuilder`
  leaves that swipe out because it competes with Android's back gesture, so
  don't map it to iOS.
- Transitions take 500 ms, the standard Cupertino duration.
