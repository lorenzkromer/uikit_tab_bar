# uikit_tab_bar example

Every option of `UIKitTabBar`, switchable at runtime in the "Optionen" tab:
hiding, minimize behavior, accessory, prominent tab, search tab, badges,
disabled/hidden tabs, style (tint, selected color, app font, title offset,
badge colors), light/dark, and a switch that forces the Cupertino fallback.

The tabs use all icon kinds: SF Symbols (Home, Optionen), an asset image
(Entdecken, `assets/icons/star.png`) and a Flutter `IconData` (Events).

```sh
flutter run   # iOS 26+ simulator or device for the native bar
```

`ios/ExampleUITests` drives the app with real gestures (pans, typing), which
widget tests cannot do:

```sh
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme ExampleUITests \
  -destination 'platform=iOS Simulator,name=iPhone Air' test
```

The Roboto font in `assets/fonts` is licensed under the Apache License 2.0
(`assets/fonts/Roboto_LICENSE.txt`).
