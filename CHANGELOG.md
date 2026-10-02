## 0.1.0

* Initial release.
* Native `UITabBarController` (iOS 26+, Liquid Glass) in a platform view:
  tabs with SF Symbols, Flutter `IconData` or images, badges, enabled and
  hidden state; controlled selection with `onReselect`.
* Minimize on scroll (`onScrollDown` / `onScrollUp`) driven by the Flutter
  scrollable, bottom accessory, system search tab, prominent tab (iOS 27),
  hiding with the system animation.
* Styling: tint, selected color, title font from app assets, title offset,
  badge colors, light/dark from the app theme.
* Geometry reporting and `UIKitTabScaffold` for bottom padding.
* `CupertinoTabBar` fallback on iOS < 26 and all other platforms.
* Swift Package Manager and CocoaPods; minimum iOS 15.6.
