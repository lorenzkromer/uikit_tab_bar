# uikit_tab_bar

The original iOS tab bar for Flutter: a real `UITabBarController` with
Liquid Glass on iOS 26+, made controllable from Dart. It does not imitate
the bar. Everywhere else (iOS < 26, Android, web, desktop) the same
configuration renders a standard `CupertinoTabBar`.

## Features

| Feature | Native bar | Fallback |
| --- | --- | --- |
| Tabs with SF Symbol, Flutter `IconData` or any `ImageProvider` icon, selected icon | ✓ (selected icon: iOS 26.1+) | ✓ (`fallbackIcon` for SF Symbols) |
| Badges, disabled tabs, hidden tabs | ✓ | ✓ |
| Controlled selection, `onReselect` (scroll to top) | ✓ | ✓ |
| Minimize on scroll (`onScrollDown` / `onScrollUp`) | ✓ | – |
| Bottom accessory with icon, title, subtitle, action buttons | ✓ (regular and inline) | – |
| System search tab with native search field, text to Dart | ✓ | regular tab (bring your own field) |
| Prominent tab | ✓ iOS 27+ | – |
| Hide with the system animation | ✓ | ✓ (without animation) |
| Tint, selected color, title font from app assets, title offset, badge colors | ✓ | tint, badge colors |
| Light/dark following the app theme (not only the system) | ✓ | ✓ |
| Reported geometry (bottom inset, frames, minimized state) | ✓ | ✓ |

## Usage

```dart
UIKitTabScaffold(
  tabBar: UIKitTabBar(
    tabs: const [
      UIKitTab(
        id: 'home',
        label: 'Home',
        icon: UIKitTabIcon.symbol('house'),
        selectedIcon: UIKitTabIcon.symbol('house.fill'),
        fallbackIcon: Icon(CupertinoIcons.house),
      ),
      UIKitTab(id: 'events', label: 'Events', icon: UIKitTabIcon.icon(Icons.event), badge: '3'),
    ],
    selectedId: selected,
    onSelected: (id) => setState(() => selected = id),
    onReselect: (id) => scrollToTop(id),
    minimizeBehavior: UIKitTabBarMinimizeBehavior.onScrollDown,
    searchTab: UIKitSearchTab(onChanged: (text) => setState(() => query = text)),
    accessory: UIKitTabAccessory(title: 'Now playing', onTap: openPlayer),
    style: UIKitTabBarStyle(tintColor: Theme.of(context).colorScheme.primary),
  ),
  body: IndexedStack(index: indexOf(selected), children: pages),
)
```

* The native bar floats over the content. `UIKitTabScaffold` lets the body
  extend behind it and sets `MediaQuery.padding.bottom` of the body to the
  bar's reported height (83 pt on an iPhone Air, 139 pt with an accessory),
  so `SafeArea` and list paddings keep content clear of the bar.
* Selection is controlled. A tap calls `onSelected`. If you don't change
  `selectedId`, the bar goes back, which is how you veto a tap. A tap on the
  selected tab calls `onReselect` instead.
* For minimizing, the scaffold forwards scroll notifications of the body's
  primary vertical scrollable (`depth == 0`). Tabs kept alive offstage, for
  example in an `IndexedStack`, are ignored. If you place the bar yourself,
  pass a `UIKitTabBarController` and wrap the content in
  `UIKitTabBarScrollListener`.
* Read `UIKitTabBarController.geometry` (or `onGeometryChanged`) for the
  bar's height, frames and minimized state.
* Put `UIKitTabScaffold` outside any widget that resizes for the keyboard
  (or set `resizeToAvoidBottomInset: false` there), so the bar stays at the
  bottom edge like a native one.
* At most 5 tabs including the search tab. More would open UIKit's "More"
  screen inside the bar.

`example/` shows every option, switchable at runtime.

## What works under Liquid Glass

Measured on iOS 27 (iPhone Air simulator). Only what takes effect is
offered in `UIKitTabBarStyle`.

| UIKit property | Under Liquid Glass | In the API |
| --- | --- | --- |
| `UITabBar.tintColor` | works (selected tab) | `tintColor` |
| Item appearance, selected: `iconColor`, title color | works | `selectedColor` |
| Item appearance: title font (size, weight, custom font) | works | `titleFontSize`, `titleFontWeight`, `titleFontAsset` |
| Item appearance: `titlePositionAdjustment` | works | `titleOffset` |
| Item appearance: `badgeBackgroundColor`, `badgeTextAttributes` | works | `badgeColor`, `badgeTextColor` |
| `overrideUserInterfaceStyle` | works | `brightness` (default: app theme) |
| `UITab.isEnabled` | works (dimmed) | `UIKitTab.enabled` |
| `unselectedItemTintColor`, item appearance normal `iconColor` / title color | no effect (the system picks legible colors) | – |
| `UITabBarAppearance.backgroundColor`, `barTintColor`, shadow | no effect (glass) | – |
| `selectionIndicatorTintColor` | no visible effect | – |
| `UITab.subtitle` | sidebar only, not shown in the bar | `UIKitTab.subtitle` (passed through) |
| `UITab.isHidden` | sidebar customization only | `UIKitTab.hidden` is implemented by removing the tab |

## How it works

* A `UITabBarController` is a child view controller inside a platform view
  that covers the bottom 200 pt of the screen. Its tab content controllers
  are transparent placeholders; the content is Flutter, behind them.
* UIKit reports the frames of the glass pills, accessory and search field
  after every layout change and during animations. A render object lets
  only touches inside those frames reach the platform view. Everything
  else goes to Flutter.
* UIKit only minimizes for real pans of the content scroll view. An
  invisible proxy `UIScrollView` stands in for the Flutter scrollable: its
  pan recognizer is moved onto the FlutterView, so the user's finger drives
  it while Flutter scrolls from the same touches. Outside a drag it mirrors
  Flutter's position. Behavior was verified against a pure UIKit reference
  app with the same gestures.
* Dart sends the complete state on every change; Swift diffs it and applies
  the changes in one batch (`performBatchUpdates` on iOS 27). Hot reload just
  works.
* Non-symbol icons are rendered in Dart at device scale and sent once as
  template images. Fonts from the app's assets are registered natively.

## Limits

* **Minimize gating.** While minimizing is on and the selected tab is
  scrollable, any vertical pan on the Flutter view counts, also on a sheet
  or dialog covering the content. Set `minimizeBehavior` to `never` (or hide
  the bar) while such overlays are open.
* **Expand at the top** after a Flutter fling is triggered explicitly by
  re-applying the minimize behavior, because UIKit ignores the programmatic
  scroll position. A scroll back up during a drag expands natively.
* **Accessory content** is native, described by its fields. Arbitrary
  Flutter widgets inside it would need a second Flutter engine.
* **Search with keyboard.** While the native search field is active, the
  platform view grows behind the keyboard so UIKit can place the field
  above it.
* **iPad.** The phone-style bottom bar is shown (compact size class). The
  top tab bar, sidebar, tab groups and drag and drop are not supported.
* **Overlays.** Flutter content painted above the bar region (dialogs,
  sheets, snack bars) is composited in separate layers, as with every
  platform view.

## Platform support

* iOS 26+: native bar. iOS 15.6 to 25: `CupertinoTabBar`. The plugin's
  minimum iOS version is 15.6; newer APIs are behind `#available`.
* Swift Package Manager and CocoaPods.
* All other platforms: `CupertinoTabBar` (the plugin has no native part
  there).
