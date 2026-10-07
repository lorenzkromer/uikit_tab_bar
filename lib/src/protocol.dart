// Wire format between Dart and the native view. Dart always sends the full
// state; native diffs it against the previous one.
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'model.dart';

/// Name of the platform view type registered by the iOS plugin.
const String kViewType = 'uikit_tab_bar/view';

/// Method channel of one native view.
String channelName(int viewId) => 'uikit_tab_bar/view_$viewId';

/// Maximum number of root tabs (incl. the search tab). More would make
/// UIKit show its "More" screen inside the platform view.
const int kMaxTabs = 5;

/// A rendered template image, identified by [key] on the native side.
@immutable
class RenderedIcon {
  /// Creates a rendered icon.
  const RenderedIcon({required this.key, required this.png, required this.scale});

  /// Stable cache key.
  final String key;

  /// PNG bytes.
  final Uint8List png;

  /// Device pixel ratio the PNG was rendered at.
  final double scale;
}

/// Looks up an already rendered image for a non-symbol icon; returns `null`
/// while it is still being rendered.
typedef IconLookup = RenderedIcon? Function(UIKitTabIcon icon);

/// Everything the native bar needs, as plain values.
@immutable
class TabBarState {
  /// Creates a state snapshot.
  const TabBarState({
    required this.tabs,
    required this.selectedId,
    this.searchTab,
    this.prominentTabId,
    this.minimizeBehavior = UIKitTabBarMinimizeBehavior.automatic,
    this.hidden = false,
    this.accessory,
    this.style = const UIKitTabBarStyle(),
    this.brightness = Brightness.light,
    this.rtl = false,
  });

  /// Regular tabs.
  final List<UIKitTab> tabs;

  /// Selected tab id (may be the search tab's id).
  final String selectedId;

  /// Optional search tab.
  final UIKitSearchTab? searchTab;

  /// Prominent tab id (iOS 27+).
  final String? prominentTabId;

  /// Minimize behavior.
  final UIKitTabBarMinimizeBehavior minimizeBehavior;

  /// Whether the bar is hidden.
  final bool hidden;

  /// Optional accessory.
  final UIKitTabAccessory? accessory;

  /// Style.
  final UIKitTabBarStyle style;

  /// Effective brightness.
  final Brightness brightness;

  /// Right-to-left layout.
  final bool rtl;

  /// All icons that need rendering before they can be shown natively.
  Iterable<UIKitTabIcon> get imageIcons sync* {
    for (final tab in tabs) {
      if (tab.icon is! UIKitSymbolIcon) yield tab.icon;
      final selected = tab.selectedIcon;
      if (selected != null && selected is! UIKitSymbolIcon) yield selected;
    }
    final accessory = this.accessory;
    if (accessory != null) {
      final icon = accessory.icon;
      if (icon != null && icon is! UIKitSymbolIcon) yield icon;
      for (final action in accessory.actions) {
        if (action.icon is! UIKitSymbolIcon) yield action.icon;
      }
    }
  }
}

/// Encodes [state] for the `update` call. Icons that are not rendered yet
/// are sent as `null` and filled in by a later update.
Map<String, Object?> encodeState(TabBarState state, IconLookup lookup) {
  assert(
    state.tabs.length + (state.searchTab == null ? 0 : 1) <= kMaxTabs,
    'UIKitTabBar supports at most $kMaxTabs tabs including the search tab; '
    'more would open UIKit\'s "More" screen inside the platform view.',
  );
  assert(
    state.tabs.map((t) => t.id).toSet().length == state.tabs.length &&
        !state.tabs.any((t) => t.id == state.searchTab?.id),
    'Tab ids must be unique.',
  );
  final style = state.style;
  final search = state.searchTab;
  final accessory = state.accessory;
  return {
    'tabs': [
      for (final tab in state.tabs)
        {
          'id': tab.id,
          'title': tab.label,
          'icon': encodeIcon(tab.icon, lookup),
          'selectedIcon': tab.selectedIcon == null ? null : encodeIcon(tab.selectedIcon!, lookup),
          'badge': tab.badge,
          'subtitle': tab.subtitle,
          'enabled': tab.enabled,
          'hidden': tab.hidden,
        },
    ],
    'search': search == null
        ? null
        : {
            'id': search.id,
            'title': search.label,
            'placeholder': search.placeholder,
            'automaticallyActivatesSearch': search.automaticallyActivatesSearch,
          },
    'selectedId': state.selectedId,
    'prominentId': state.prominentTabId,
    'minimizeBehavior': state.minimizeBehavior.name,
    'hidden': state.hidden,
    'accessory': accessory == null
        ? null
        : {
            'title': accessory.title,
            'subtitle': accessory.subtitle,
            'icon': accessory.icon == null ? null : encodeIcon(accessory.icon!, lookup),
            'actions': [
              for (final action in accessory.actions)
                {
                  'id': action.id,
                  'icon': encodeIcon(action.icon, lookup),
                  'label': action.semanticLabel,
                },
            ],
          },
    'style': {
      'tint': encodeColor(style.tintColor),
      'selected': encodeColor(style.selectedColor),
      'fontAsset': style.titleFontAsset,
      'fontSize': style.titleFontSize,
      'fontWeight': style.titleFontWeight?.value,
      'titleOffset': style.titleOffset == null ? null : [style.titleOffset!.dx, style.titleOffset!.dy],
      'badge': encodeColor(style.badgeColor),
      'badgeText': encodeColor(style.badgeTextColor),
      'badgeOffset': style.badgeOffset == null ? null : [style.badgeOffset!.dx, style.badgeOffset!.dy],
      'badgeFontSize': style.badgeFontSize,
      'badgeFontWeight': style.badgeFontWeight?.value,
    },
    'brightness': state.brightness.name,
    'rtl': state.rtl,
  };
}

/// `{'symbol': name}` or `{'image': key, 'scale': s}`; `null` if pending.
Map<String, Object?>? encodeIcon(UIKitTabIcon icon, IconLookup lookup) {
  if (icon is UIKitSymbolIcon) return {'symbol': icon.name};
  final rendered = lookup(icon);
  if (rendered == null) return null;
  return {'image': rendered.key, 'scale': rendered.scale};
}

/// ARGB32 as int, or `null`.
int? encodeColor(Color? color) => color?.toARGB32();

/// Image keys referenced by an encoded state.
Set<String> referencedImageKeys(Map<String, Object?> encoded) {
  final keys = <String>{};
  void visit(Object? v) {
    if (v is Map) {
      final key = v['image'];
      if (key is String) keys.add(key);
      v.values.forEach(visit);
    } else if (v is List) {
      v.forEach(visit);
    }
  }

  visit(encoded);
  return keys;
}

/// Deep equality for encoded states (maps, lists, scalars).
bool encodedEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !encodedEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!encodedEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

Rect? _rect(Object? v) {
  if (v is! List || v.length != 4) return null;
  final n = v.cast<num>();
  return Rect.fromLTWH(n[0].toDouble(), n[1].toDouble(), n[2].toDouble(), n[3].toDouble());
}

/// Parses a `geometry` event.
UIKitTabBarGeometry decodeGeometry(Map<Object?, Object?> m) {
  return UIKitTabBarGeometry(
    isNative: true,
    bottomInset: (m['bottomInset'] as num?)?.toDouble() ?? 0,
    topInset: (m['topInset'] as num?)?.toDouble() ?? 0,
    barRect: _rect(m['bar']),
    accessoryRect: _rect(m['accessory']),
    searchFieldRect: _rect(m['search']),
    hitRects: [
      for (final r in (m['hitRects'] as List? ?? const [])) ?_rect(r),
    ],
    minimized: m['minimized'] == true,
    hidden: m['hidden'] == true,
    accessoryEnvironment: UIKitTabAccessoryEnvironment.values.firstWhere(
      (e) => e.name == m['accessoryEnvironment'],
      orElse: () => UIKitTabAccessoryEnvironment.none,
    ),
  );
}

/// Arguments of the `scroll` call: the primary scrollable of the selected
/// tab, mirrored on the native proxy scroll view.
Map<String, Object?> encodeScroll({
  required String tabId,
  required double pixels,
  required double minScrollExtent,
  required double maxScrollExtent,
  required double viewportDimension,
}) =>
    {
      'tabId': tabId,
      'pixels': pixels,
      'min': minScrollExtent,
      'max': maxScrollExtent,
      'viewport': viewportDimension,
    };
