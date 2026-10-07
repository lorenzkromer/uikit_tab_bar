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
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(tintColor, selectedColor, titleFontAsset, titleFontSize,
      titleFontWeight, titleOffset, badgeColor, badgeTextColor, badgeOffset, brightness);
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
    this.barRect,
    this.accessoryRect,
    this.searchFieldRect,
    this.hitRects = const [],
    this.minimized = false,
    this.hidden = false,
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

  /// Frame of the tab bar view (full width, incl. home indicator area).
  final Rect? barRect;

  /// Frame of the accessory, if shown.
  final Rect? accessoryRect;

  /// Frame of the native search field, while shown.
  final Rect? searchFieldRect;

  /// Areas where the native bar draws and takes touches.
  final List<Rect> hitRects;

  /// Whether the bar is currently minimized.
  final bool minimized;

  /// Whether the bar is hidden.
  final bool hidden;

  /// Where the accessory currently sits.
  final UIKitTabAccessoryEnvironment accessoryEnvironment;

  @override
  bool operator ==(Object other) =>
      other is UIKitTabBarGeometry &&
      other.isNative == isNative &&
      other.bottomInset == bottomInset &&
      other.topInset == topInset &&
      other.barRect == barRect &&
      other.accessoryRect == accessoryRect &&
      other.searchFieldRect == searchFieldRect &&
      listEquals(other.hitRects, hitRects) &&
      other.minimized == minimized &&
      other.hidden == hidden &&
      other.accessoryEnvironment == accessoryEnvironment;

  @override
  int get hashCode => Object.hash(isNative, bottomInset, topInset, barRect, accessoryRect,
      searchFieldRect, Object.hashAll(hitRects), minimized, hidden, accessoryEnvironment);

  @override
  String toString() => 'UIKitTabBarGeometry(native: $isNative, bottomInset: $bottomInset, '
      'topInset: $topInset, '
      'bar: $barRect, accessory: $accessoryRect, minimized: $minimized, hidden: $hidden, '
      'accessory: ${accessoryEnvironment.name})';
}
