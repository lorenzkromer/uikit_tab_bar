import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The icon of a tab.
///
/// On the native bar, every icon is a template image tinted by UIKit.
/// SF Symbols only exist on Apple platforms; tabs that use
/// [UIKitTabIcon.symbol] therefore need a [UIKitTab.fallbackIcon] for the
/// Cupertino fallback.
@immutable
sealed class UIKitTabIcon {
  const UIKitTabIcon();

  /// An SF Symbol by name, e.g. `house` / `house.fill`.
  const factory UIKitTabIcon.symbol(String name) = UIKitSymbolIcon;

  /// A Flutter [IconData] (Material, Cupertino or an app icon font),
  /// rendered to a template image at device scale.
  const factory UIKitTabIcon.icon(IconData icon) = UIKitIconDataIcon;

  /// Any [ImageProvider] (e.g. `AssetImage`), used as a template image.
  ///
  /// [size] is the logical size the image is drawn at; tab bar icons are
  /// usually about 25 to 28 points.
  const factory UIKitTabIcon.image(ImageProvider image, {Size size}) = UIKitImageIcon;
}

/// An SF Symbol.
final class UIKitSymbolIcon extends UIKitTabIcon {
  /// Creates an SF Symbol icon.
  const UIKitSymbolIcon(this.name);

  /// The symbol name.
  final String name;

  @override
  bool operator ==(Object other) => other is UIKitSymbolIcon && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// A Flutter [IconData].
final class UIKitIconDataIcon extends UIKitTabIcon {
  /// Creates an icon from [IconData].
  const UIKitIconDataIcon(this.icon);

  /// The icon glyph.
  final IconData icon;

  @override
  bool operator ==(Object other) => other is UIKitIconDataIcon && other.icon == icon;

  @override
  int get hashCode => icon.hashCode;
}

/// An image icon.
final class UIKitImageIcon extends UIKitTabIcon {
  /// Creates an icon from an [ImageProvider].
  const UIKitImageIcon(this.image, {this.size = const Size.square(26)});

  /// The image.
  final ImageProvider image;

  /// The logical size the image is drawn at.
  final Size size;

  @override
  bool operator ==(Object other) =>
      other is UIKitImageIcon && other.image == image && other.size == size;

  @override
  int get hashCode => Object.hash(image, size);
}

/// One tab of a [UIKitTabBar].
@immutable
class UIKitTab {
  /// Creates a tab.
  const UIKitTab({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.fallbackIcon,
    this.fallbackSelectedIcon,
    this.badge,
    this.subtitle,
    this.enabled = true,
    this.hidden = false,
  });

  /// Stable identifier, used for selection and diffing.
  final String id;

  /// The title shown below (or next to) the icon.
  final String label;

  /// The icon in the native bar.
  final UIKitTabIcon icon;

  /// The icon while the tab is selected (native: iOS 26.1+).
  final UIKitTabIcon? selectedIcon;

  /// The icon used by the Cupertino fallback.
  ///
  /// Required when [icon] is an SF Symbol; otherwise derived from [icon].
  final Widget? fallbackIcon;

  /// The selected icon used by the Cupertino fallback.
  final Widget? fallbackSelectedIcon;

  /// Badge text; an empty string shows a dot-sized badge, `null` none.
  final String? badge;

  /// Secondary text. UIKit only shows it in the iPad sidebar, not in the
  /// tab bar.
  final String? subtitle;

  /// Whether the tab can be selected.
  final bool enabled;

  /// Removes the tab from the bar while keeping its native state, e.g.
  /// for tabs that depend on a login.
  ///
  /// With every tab hidden (and no search tab) the bar shows no tabs, like
  /// [UIKitTabsVisibility.hidden]. To hide all tabs for a screen, prefer
  /// [UIKitTabBar.tabsVisibility].
  final bool hidden;

  @override
  bool operator ==(Object other) =>
      other is UIKitTab &&
      other.id == id &&
      other.label == label &&
      other.icon == icon &&
      other.selectedIcon == selectedIcon &&
      other.fallbackIcon == fallbackIcon &&
      other.fallbackSelectedIcon == fallbackSelectedIcon &&
      other.badge == badge &&
      other.subtitle == subtitle &&
      other.enabled == enabled &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(id, label, icon, selectedIcon, fallbackIcon,
      fallbackSelectedIcon, badge, subtitle, enabled, hidden);
}

/// The system search tab (`UISearchTab`), shown separated from the other
/// tabs. Its search field is native; the text is reported to Dart.
///
/// In the Cupertino fallback it is a regular tab; render your own search
/// field there (see [UIKitTabBarGeometry.isNative]).
@immutable
class UIKitSearchTab {
  /// Creates a search tab.
  const UIKitSearchTab({
    this.id = 'search',
    this.label,
    this.placeholder,
    this.automaticallyActivatesSearch = false,
    this.fallbackIcon,
    this.onChanged,
    this.onSubmitted,
    this.onActiveChanged,
  });

  /// Identifier used for selection.
  final String id;

  /// Title; `null` uses the system's localized "Search".
  final String? label;

  /// Placeholder of the search field.
  final String? placeholder;

  /// Activates the search field (and keyboard) as soon as the tab is
  /// selected; cancelling returns to the previous tab (iOS 26+).
  final bool automaticallyActivatesSearch;

  /// Fallback icon; defaults to a built-in magnifier glyph.
  final Widget? fallbackIcon;

  /// Called on every change of the search text.
  final ValueChanged<String>? onChanged;

  /// Called when the user taps the keyboard's search key.
  final ValueChanged<String>? onSubmitted;

  /// Called when the search field becomes active or inactive.
  final ValueChanged<bool>? onActiveChanged;

  @override
  bool operator ==(Object other) =>
      other is UIKitSearchTab &&
      other.id == id &&
      other.label == label &&
      other.placeholder == placeholder &&
      other.automaticallyActivatesSearch == automaticallyActivatesSearch &&
      other.fallbackIcon == fallbackIcon;

  @override
  int get hashCode =>
      Object.hash(id, label, placeholder, automaticallyActivatesSearch, fallbackIcon);
}

/// A button on the trailing side of a [UIKitTabAccessory].
@immutable
class UIKitAccessoryAction {
  /// Creates an accessory action.
  const UIKitAccessoryAction({required this.id, required this.icon, this.semanticLabel});

  /// Identifier passed to [UIKitTabAccessory.onAction].
  final String id;

  /// Icon of the button.
  final UIKitTabIcon icon;

  /// Accessibility label.
  final String? semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is UIKitAccessoryAction &&
      other.id == id &&
      other.icon == icon &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(id, icon, semanticLabel);
}

/// Where the accessory currently sits (`UITabAccessory.Environment`).
enum UIKitTabAccessoryEnvironment {
  /// Not shown.
  none,

  /// Full width above the tab bar.
  regular,

  /// Inline next to the minimized tab bar.
  inline,
}

/// The bottom accessory above the tab bar (iOS 26+, e.g. "now playing").
///
/// The content is native, described by these fields. It is not shown in
/// the Cupertino fallback.
@immutable
class UIKitTabAccessory {
  /// Creates an accessory.
  const UIKitTabAccessory({
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.onTap,
    this.onAction,
  });

  /// Main text.
  final String title;

  /// Secondary text; hidden when the accessory is inline.
  final String? subtitle;

  /// Leading icon.
  final UIKitTabIcon? icon;

  /// Trailing buttons; only the first one is shown inline.
  final List<UIKitAccessoryAction> actions;

  /// Called when the accessory itself is tapped.
  final VoidCallback? onTap;

  /// Called with [UIKitAccessoryAction.id] when an action is tapped.
  final ValueChanged<String>? onAction;

  @override
  bool operator ==(Object other) =>
      other is UIKitTabAccessory &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.icon == icon &&
      listEquals(other.actions, actions);

  @override
  int get hashCode => Object.hash(title, subtitle, icon, Object.hashAll(actions));
}

/// When the tab bar minimizes (`UITabBarController.MinimizeBehavior`).
enum UIKitTabBarMinimizeBehavior {
  /// The system decides (currently: never on iPhone).
  automatic,

  /// Never minimize.
  never,

  /// Minimize while scrolling down, expand when scrolling back up.
  onScrollDown,

  /// Minimize while scrolling up.
  onScrollUp,
}

/// Whether the system may show the vertical bar (iOS 27.1+).
///
/// On hardware with a vertical bar (iPhone Duo), UIKit moves the tab bar
/// into a column at the leading or trailing edge of the screen, together
/// with the status bar. Apple's guidance: disable it only for screens that
/// are better served by horizontal bars, and treat it as a stable choice.
enum UIKitVerticalBarBehavior {
  /// The system decides (vertical on supporting hardware).
  automatic,

  /// The bar stays at the bottom and the status bar at the top. Applies to
  /// the whole window (or presentation) the bar is shown in.
  disabled,
}

/// Where the vertical bar is shown (`UIVerticalBarEdge`, iOS 27.1+).
enum UIKitVerticalBarEdge {
  /// No vertical bar: the bar sits at the bottom.
  none,

  /// At the leading edge (left in left-to-right layouts and in the usual
  /// orientations; UIKit decides per device orientation).
  leading,

  /// At the trailing edge.
  trailing,
}

/// Whether the bar shows its tabs.
///
/// The tabs stay part of the bar: selection, badges and order are kept, and
/// showing them again restores them as they were. Use this for screens that
/// only want the [UIKitToolbar] in the vertical bar, e.g. a pushed detail
/// page with just Back at the top of the column.
///
/// To hide everything, tabs and toolbar, use [UIKitTabBar.hidden].
enum UIKitTabsVisibility {
  /// The tabs are shown.
  visible,

  /// The tabs are not shown while the bar is vertical (iOS 27.1+, e.g.
  /// iPhone Duo); the column then holds only the toolbar. The horizontal bar
  /// and the fallback bar keep their tabs.
  hiddenInVerticalBar,

  /// The tabs are not shown at all. The vertical bar keeps the toolbar; the
  /// horizontal bar and the fallback bar are hidden as with
  /// [UIKitTabBar.hidden].
  hidden,
}

/// How long a [UIKitToolbarItem] stays visible when the vertical bar runs
/// out of space (`UIBarButtonItem.visibilityPriority`, iOS 27+).
///
/// Items overflow from bottom to top by default. Apple's guidance: keep
/// frequently used actions and items that convey status (badges) longer.
enum UIKitToolbarItemPriority {
  /// Moves into the system overflow menu first.
  low,

  /// The system's default order.
  standard,

  /// Stays visible longest.
  high,
}

/// Appearance of a [UIKitToolbarItem].
enum UIKitToolbarItemStyle {
  /// A regular glass button.
  plain,

  /// The tinted, prominent treatment for the main action of a screen
  /// (e.g. Done).
  prominent,
}

/// What gives way first when tabs and toolbar items share the vertical bar
/// and space is tight (`UINavigationItem.verticalBarCompressionBehavior`,
/// iOS 27.1+).
enum UIKitVerticalBarCompression {
  /// The system decides; on iOS that is [prefersTabBar].
  automatic,

  /// Navigation-focused screens: toolbar items move into the overflow menu,
  /// all tabs stay reachable.
  prefersTabBar,

  /// Task-focused screens: the tab bar collapses into a single control,
  /// the toolbar items stay.
  prefersToolbar,
}

/// A button of the [UIKitToolbar].
///
/// Give every item an [icon] and a [label]: the vertical bar shows the icon,
/// the system overflow menu and accessibility use the label.
@immutable
class UIKitToolbarItem {
  /// Creates a toolbar item.
  const UIKitToolbarItem({
    required this.id,
    required this.icon,
    required this.label,
    this.badge,
    this.priority = UIKitToolbarItemPriority.standard,
    this.style = UIKitToolbarItemStyle.plain,
    this.enabled = true,
  });

  /// Identifier passed to [UIKitToolbar.onPressed].
  final String id;

  /// Icon of the button. Prefer an SF Symbol; images are template images.
  final UIKitTabIcon icon;

  /// Title of the item, shown in the overflow menu and read by VoiceOver.
  final String label;

  /// Badge text; an empty string shows a dot. `null` for no badge.
  final String? badge;

  /// How long the item stays visible when space is tight.
  final UIKitToolbarItemPriority priority;

  /// Plain or prominent.
  final UIKitToolbarItemStyle style;

  /// Whether the item can be pressed.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is UIKitToolbarItem &&
      other.id == id &&
      other.icon == icon &&
      other.label == label &&
      other.badge == badge &&
      other.priority == priority &&
      other.style == style &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, icon, label, badge, priority, style, enabled);
}

/// An entry of the system overflow menu of the [UIKitToolbar].
@immutable
class UIKitToolbarMenuItem {
  /// Creates a menu entry.
  const UIKitToolbarMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  /// Identifier passed to [UIKitToolbar.onPressed].
  final String id;

  /// Title of the entry.
  final String label;

  /// Optional icon.
  final UIKitTabIcon? icon;

  /// Shown in red, for actions that delete something.
  final bool destructive;

  /// Whether the entry can be chosen.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is UIKitToolbarMenuItem &&
      other.id == id &&
      other.label == label &&
      other.icon == icon &&
      other.destructive == destructive &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, label, icon, destructive, enabled);
}

/// The app's toolbar in the vertical bar (iOS 27.1+, iPhone Duo).
///
/// On hardware with a vertical bar, the system moves toolbar and navigation
/// buttons into the same column as the tabs, above them. This describes
/// those buttons; UIKit lays them out, groups them and moves what does not
/// fit into its overflow menu.
///
/// Order in the column, following Apple's guidance: [navigation] (Back,
/// Close) at the top, then [groups] in the given order, prominent actions
/// first.
///
/// Nothing is shown while the bar is horizontal (other iPhones, the inner
/// display held upright, [UIKitVerticalBarBehavior.disabled]) and with the
/// fallback bar: show your own bar there.
/// [UIKitTabBarGeometry.toolbarRect] is `null` then.
@immutable
class UIKitToolbar {
  /// Creates a toolbar.
  const UIKitToolbar({
    this.navigation = const [],
    this.groups = const [],
    this.menu = const [],
    this.compression = UIKitVerticalBarCompression.automatic,
    this.onPressed,
  });

  /// Primary navigation controls such as Back or Close, at the top of the
  /// column.
  final List<UIKitToolbarItem> navigation;

  /// The actions, in groups of related items. The system keeps a group
  /// together on one glass background and spaces the groups.
  final List<List<UIKitToolbarItem>> groups;

  /// Additional entries of the system overflow menu (the ellipsis button).
  /// Items that do not fit are added to the same menu by the system.
  final List<UIKitToolbarMenuItem> menu;

  /// What gives way first when space is tight. Without tabs
  /// ([UIKitTabBar.tabsVisibility]) there is nothing to weigh up.
  final UIKitVerticalBarCompression compression;

  /// Called with the id of the pressed item or chosen menu entry.
  final ValueChanged<String>? onPressed;

  /// Whether there is nothing to show.
  bool get isEmpty => navigation.isEmpty && groups.every((g) => g.isEmpty) && menu.isEmpty;
}

/// Visual options of the native bar.
///
/// Only properties that measurably take effect under Liquid Glass are
/// offered (see the README). Unselected colors and the bar background are
/// controlled by the system.
@immutable
class UIKitTabBarStyle {
  /// Creates a style.
  const UIKitTabBarStyle({
    this.tintColor,
    this.selectedColor,
    this.titleFontAsset,
    this.titleFontSize,
    this.titleFontWeight,
    this.titleOffset,
    this.badgeColor,
    this.badgeTextColor,
    this.badgeOffset,
    this.badgeFontSize,
    this.badgeFontWeight,
    this.brightness,
  });

  /// Tint of the selected tab (`UITabBar.tintColor`). Also the active color
  /// of the fallback bar.
  final Color? tintColor;

  /// Icon and title color of the selected tab; overrides [tintColor]
  /// natively.
  final Color? selectedColor;

  /// Font file in the app's assets (as listed in `pubspec.yaml`) used for
  /// tab titles, e.g. `assets/fonts/Brand-Bold.ttf`.
  final String? titleFontAsset;

  /// Title font size in points.
  final double? titleFontSize;

  /// Title weight when no [titleFontAsset] is given.
  final FontWeight? titleFontWeight;

  /// Moves the titles; negative values move them up.
  final Offset? titleOffset;

  /// Badge background color.
  final Color? badgeColor;

  /// Badge text color.
  final Color? badgeTextColor;

  /// Moves all badges, e.g. to keep a wide badge on the last tab inside the
  /// bar. `dx` follows the text direction: positive moves toward the end
  /// (right in left-to-right layouts), negative toward the start. Positive
  /// `dy` moves down.
  ///
  /// UIKit applies one offset to every tab of the bar; a per-tab offset has
  /// no effect under Liquid Glass.
  final Offset? badgeOffset;

  /// Font size of the badge text in points; the badge resizes with it.
  /// Applies to all badges of the bar.
  final double? badgeFontSize;

  /// Font weight of the badge text (with [badgeFontSize], or the system's
  /// default badge size of 13 pt).
  final FontWeight? badgeFontWeight;

  /// Light or dark bar. `null` follows the app (`CupertinoTheme`, then the
  /// platform brightness), not only the system setting.
  final Brightness? brightness;

  @override
  bool operator ==(Object other) =>
      other is UIKitTabBarStyle &&
      other.tintColor == tintColor &&
      other.selectedColor == selectedColor &&
      other.titleFontAsset == titleFontAsset &&
      other.titleFontSize == titleFontSize &&
      other.titleFontWeight == titleFontWeight &&
      other.titleOffset == titleOffset &&
      other.badgeColor == badgeColor &&
      other.badgeTextColor == badgeTextColor &&
      other.badgeOffset == badgeOffset &&
      other.badgeFontSize == badgeFontSize &&
      other.badgeFontWeight == badgeFontWeight &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(tintColor, selectedColor, titleFontAsset, titleFontSize,
      titleFontWeight, titleOffset, badgeColor, badgeTextColor, badgeOffset, badgeFontSize, badgeFontWeight, brightness);
}

/// Layout of the bar as last reported by UIKit, in the coordinates of the
/// bar's own widget (its bottom edge is the screen's bottom edge).
@immutable
class UIKitTabBarGeometry {
  /// Creates a geometry snapshot.
  const UIKitTabBarGeometry({
    required this.isNative,
    required this.bottomInset,
    this.topInset = 0,
    this.leftInset = 0,
    this.rightInset = 0,
    this.verticalBarEdge = UIKitVerticalBarEdge.none,
    this.barRect,
    this.accessoryRect,
    this.searchFieldRect,
    this.toolbarRect,
    this.hitRects = const [],
    this.minimized = false,
    this.hidden = false,
    this.tabsHidden = false,
    this.accessoryEnvironment = UIKitTabAccessoryEnvironment.none,
  });

  /// Placeholder until the first layout report arrives.
  static const UIKitTabBarGeometry initial = UIKitTabBarGeometry(isNative: false, bottomInset: 0);

  /// `true` for the native UIKit bar, `false` for the Cupertino fallback.
  final bool isNative;

  /// Height at the bottom of the screen that content should keep clear of
  /// (bar, accessory and home indicator); UIKit's `contentLayoutGuide`.
  /// Apps use this as bottom padding.
  final double bottomInset;

  /// Height at the top of the screen that content should keep clear of
  /// while the native search field is active: like in a native app, UIKit
  /// then shows the field at the top, below the status bar. `0` otherwise.
  final double topInset;

  /// Width at the left edge of the screen that content should keep clear
  /// of: the vertical bar column (with the status bar) when it sits on the
  /// left, otherwise the safe area. Physical, not text direction.
  final double leftInset;

  /// Width at the right edge of the screen that content should keep clear
  /// of, like [leftInset].
  final double rightInset;

  /// Where the vertical bar is shown (iOS 27.1+, e.g. iPhone Duo);
  /// [UIKitVerticalBarEdge.none] for the regular bottom bar.
  final UIKitVerticalBarEdge verticalBarEdge;

  /// Whether the bar is shown as a vertical column instead of at the
  /// bottom.
  bool get isVertical => verticalBarEdge != UIKitVerticalBarEdge.none;

  /// Insets content should keep clear of on all four sides.
  EdgeInsets get insets =>
      EdgeInsets.fromLTRB(leftInset, topInset, rightInset, bottomInset);

  /// Frame of the tab bar view (full width, incl. home indicator area; with
  /// a vertical bar, the full-height column).
  final Rect? barRect;

  /// Frame of the accessory, if shown.
  final Rect? accessoryRect;

  /// Frame of the native search field, while shown.
  final Rect? searchFieldRect;

  /// Frame around the buttons of the [UIKitToolbar] in the vertical bar;
  /// `null` while they are not shown (no toolbar, or the bar is
  /// horizontal).
  final Rect? toolbarRect;

  /// Areas where the native bar draws and takes touches.
  final List<Rect> hitRects;

  /// Whether the bar is currently minimized.
  final bool minimized;

  /// Whether the bar shows nothing: neither tabs nor toolbar.
  final bool hidden;

  /// Whether the tabs are not shown ([UIKitTabBar.hidden],
  /// [UIKitTabBar.tabsVisibility], or every tab is [UIKitTab.hidden]).
  /// `true` with [hidden] `false` means the vertical bar holds only the
  /// toolbar, at [toolbarRect]; the rest of the column is free and lets
  /// touches through.
  final bool tabsHidden;

  /// Where the accessory currently sits.
  final UIKitTabAccessoryEnvironment accessoryEnvironment;

  @override
  bool operator ==(Object other) =>
      other is UIKitTabBarGeometry &&
      other.isNative == isNative &&
      other.bottomInset == bottomInset &&
      other.topInset == topInset &&
      other.leftInset == leftInset &&
      other.rightInset == rightInset &&
      other.verticalBarEdge == verticalBarEdge &&
      other.barRect == barRect &&
      other.accessoryRect == accessoryRect &&
      other.searchFieldRect == searchFieldRect &&
      other.toolbarRect == toolbarRect &&
      listEquals(other.hitRects, hitRects) &&
      other.minimized == minimized &&
      other.hidden == hidden &&
      other.tabsHidden == tabsHidden &&
      other.accessoryEnvironment == accessoryEnvironment;

  @override
  int get hashCode => Object.hash(isNative, bottomInset, topInset, leftInset, rightInset,
      verticalBarEdge, barRect, accessoryRect, searchFieldRect, toolbarRect, Object.hashAll(hitRects),
      minimized, hidden, tabsHidden, accessoryEnvironment);

  @override
  String toString() => 'UIKitTabBarGeometry(native: $isNative, bottomInset: $bottomInset, '
      'topInset: $topInset, leftInset: $leftInset, rightInset: $rightInset, '
      'verticalBarEdge: ${verticalBarEdge.name}, '
      'bar: $barRect, accessory: $accessoryRect, toolbar: $toolbarRect, minimized: $minimized, hidden: $hidden, tabsHidden: $tabsHidden, '
      'accessory: ${accessoryEnvironment.name})';
}
