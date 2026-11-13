## 0.4.0

* `UIKitTabBar.tabsVisibility` (`visible`, `hiddenInVerticalBar`, `hidden`):
  shows the toolbar without the tabs in the vertical bar, e.g. only Back on
  a pushed page. The tabs stay part of the bar, so selection, badges and
  order survive, and the change can come in the same update as new toolbar
  contents. In the horizontal bar and the fallback bar, `hidden` hides the
  bar like `UIKitTabBar.hidden`.
* `UIKitTabBarGeometry.tabsHidden`. `hidden` now means that nothing is shown:
  it stays `false` while the vertical bar still shows the toolbar. Without
  the tabs, `hitRects` only holds the toolbar's buttons.
* `UIKitTabBar.hidden` hides the toolbar together with the tabs.
* Fixed: with every tab marked `UIKitTab.hidden`, an empty piece of glass
  stayed in the vertical bar and the tabs did not come back correctly. The
  bar now hides its tabs instead and restores them.

## 0.3.0

* Toolbar in the vertical bar (iOS 27.1+, iPhone Duo): `UIKitTabBar.toolbar`
  takes a `UIKitToolbar` with navigation controls, groups of actions and
  entries for the system overflow menu. UIKit shows them in the column above
  the tabs, as glass buttons with the bar's tint, and moves what does not
  fit into its overflow menu.
  * `UIKitToolbarItem`: icon, label, badge, `priority` (what stays visible
    longest) and `style` (`prominent` for the main action).
  * `UIKitToolbar.compression`: whether the toolbar or the tab bar gives way
    first when space is tight.
  * `UIKitToolbar.onPressed` reports the pressed item or menu entry.
  * `UIKitTabBarGeometry.toolbarRect`; the buttons are part of `hitRects`.
* The toolbar is only shown in the vertical bar; nothing changes while the
  bar is horizontal, and nothing changes for apps without a toolbar.

## 0.2.2

* Vertical bar on the inner display of iPhone Duo (iOS 27.2): when the app
  starts unfolded, UIKit switches to the vertical layout without building
  the column of tabs. The bar is now shown again once in that case, which
  builds it.
* While the vertical bar has no column, its empty strip is no longer part
  of `UIKitTabBarGeometry.hitRects`, so it does not swallow touches.

## 0.2.1

* Report geometry after a touch on the bar and while the content scrolls.
  Minimizing on scroll and expanding on tap animate without a callback, so
  `UIKitTabBarGeometry.minimized` stayed `false` and the hit region kept the
  frames of the expanded bar until another trigger measured again.

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
