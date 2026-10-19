## 0.2.0

* Vertical bar (iOS 27.1+, iPhone Duo). On hardware with a vertical bar,
  UIKit moves the tab bar into a column at the leading or trailing edge,
  depending on the orientation. The native bar now follows it: the
  platform view spans the full height, touches reach the column, and the
  tint applies there too.
* `UIKitTabBarGeometry.verticalBarEdge`, `isVertical`, `leftInset`,
  `rightInset` and `insets`. `UIKitTabScaffold` pads the body on the side of
  the column (`MediaQuery.padding.left` / `right`).
* `UIKitTabBar.verticalBarBehavior`: `disabled` keeps the bar at the bottom
  and the status bar at the top, for the window or presentation the bar is
  shown in.
* The vertical bar APIs are used dynamically, so the package still builds
  with every supported Xcode; the feature works whenever the app runs on
  iOS 27.1 or later.
* `UIKitTabBarStyle.tintColor` is also applied to the tab bar controller's
  view (the vertical bar ignores `UITabBar.tintColor`).
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
