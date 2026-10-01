## Unreleased

- Add `ZoomPushPredictiveBackBuilder`: Android's zoom transition for pushes
  and pops, with its own predictive back animation on back swipes.
  `popFadeDuration` sets how long the fade after a committed swipe takes.
- Add `ZoomPushPredictiveBackFullscreenBuilder`: Android's zoom transition for
  pushes and pops, with the full-screen predictive back animation on back
  swipes.
- Add `FadeUpwardsPushPredictiveBackBuilder`,
  `FadeUpwardsPushPredictiveBackFullscreenBuilder`,
  `OpenUpwardsPushPredictiveBackBuilder` and
  `OpenUpwardsPushPredictiveBackFullscreenBuilder`: Android 8's fade upwards
  and Android 9's open upwards for pushes and pops, with either back swipe
  animation. A back swipe slides the page down; the full-screen versions slide
  it more slowly and fade it out during the gesture.
- Add `CupertinoPushPredictiveBackFullscreenBuilder`: the Cupertino slide for
  pushes and pops, with the full-screen predictive back animation on back
  swipes.

## 1.0.0

- Initial release: `CupertinoPushPredictiveBackBuilder`, a Cupertino slide for
  pushes and pops with Android's predictive back animation on back swipes.
