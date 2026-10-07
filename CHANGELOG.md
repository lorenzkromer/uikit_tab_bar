## 0.1.1

* Builds with Xcode versions older than 27 (iOS 26.x SDKs) and older than
  Xcode 26.1.1 (iOS 26.0 SDK). APIs newer than the iOS 26.0 SDK are now also
  guarded at compile time; without the newer SDK the related features are
  left out: prominent tab and batched tab updates need Xcode 27 (iOS 27 SDK),
  the selected tab icon needs Xcode 26.1.1 (iOS 26.1 SDK).

## 0.1.0

* Initial release.
* Native `UITabBarController` (iOS 26+, Liquid Glass) in a platform view:
  tabs with SF Symbols, Flutter `IconData` or images, badges, enabled and
  hidden state; controlled selection with `onReselect`.
* Minimize on scroll (`onScrollDown` / `onScrollUp`) driven by the Flutter
  scrollable, bottom accessory, system search tab, prominent tab (iOS 27+),
  hiding with the system animation.
* Styling: tint, selected color, title font from app assets, title offset,
  badge colors, offset and font, light/dark from the app theme.
* Geometry reporting and `UIKitTabScaffold` for bottom padding.
* `CupertinoTabBar` fallback on iOS < 26 and all other platforms.
* Swift Package Manager and CocoaPods; minimum iOS 15.6.
