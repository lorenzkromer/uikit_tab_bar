import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'fallback_bar.dart';
import 'model.dart';
import 'native_bar.dart';
import 'platform_support.dart';

/// The native iOS tab bar (`UITabBarController`, Liquid Glass) on iOS 26+,
/// and a [CupertinoTabBar] built from the same tabs everywhere else.
///
/// Selection is controlled: the bar always shows [selectedId]. A tap calls
/// [onSelected]; to veto, simply don't change [selectedId]. A tap on the
/// already selected tab calls [onReselect] instead (e.g. scroll to top).
///
/// The native bar floats over the content, so the content must extend
/// behind it. [UIKitTabScaffold] does that, injects the bar's height as
/// bottom `MediaQuery` padding and wires up scrolling for minimizing.
class UIKitTabBar extends StatefulWidget {
  /// Creates a tab bar.
  const UIKitTabBar({
    super.key,
    required this.tabs,
    required this.selectedId,
    required this.onSelected,
    this.onReselect,
    this.searchTab,
    this.prominentTabId,
    this.minimizeBehavior = UIKitTabBarMinimizeBehavior.automatic,
    this.hidden = false,
    this.accessory,
    this.style = const UIKitTabBarStyle(),
    this.controller,
    this.onGeometryChanged,
  });

  /// The regular tabs (at most 5 including [searchTab]).
  final List<UIKitTab> tabs;

  /// The selected tab's id; may be [UIKitSearchTab.id].
  final String selectedId;

  /// Called when the user taps a tab other than the selected one.
  final ValueChanged<String> onSelected;

  /// Called when the user taps the already selected tab.
  final ValueChanged<String>? onReselect;

  /// Optional system search tab.
  final UIKitSearchTab? searchTab;

  /// Tab that gets the prominent, separated treatment (iOS 27+). `null`
  /// lets UIKit decide (a search tab with
  /// [UIKitSearchTab.automaticallyActivatesSearch] becomes prominent).
  final String? prominentTabId;

  /// Whether the bar minimizes while scrolling (iOS 26).
  final UIKitTabBarMinimizeBehavior minimizeBehavior;

  /// Hides the bar with the system animation.
  final bool hidden;

  /// Optional bottom accessory above the bar (iOS 26).
  final UIKitTabAccessory? accessory;

  /// Visual options.
  final UIKitTabBarStyle style;

  /// Connects the bar with the content; provided by [UIKitTabScaffold].
  final UIKitTabBarController? controller;

  /// Called whenever the bar's layout changes.
  final ValueChanged<UIKitTabBarGeometry>? onGeometryChanged;

  /// Whether this device shows the native bar (iOS 26+).
  static bool get isNativeSupported => nativeTabBarSupported;

  @override
  State<UIKitTabBar> createState() => _UIKitTabBarState();
}

class _UIKitTabBarState extends State<UIKitTabBar> {
  UIKitTabBarController? _own;

  UIKitTabBarController get _controller =>
      widget.controller ?? UIKitTabBarScope.maybeOf(context) ?? (_own ??= UIKitTabBarController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return nativeTabBarSupported
        ? NativeTabBar(config: widget, controller: controller)
        : FallbackTabBar(config: widget, controller: controller);
  }
}

/// Provides a [UIKitTabBarController] to a [UIKitTabBar] below it.
class UIKitTabBarScope extends InheritedWidget {
  /// Creates a scope.
  const UIKitTabBarScope({super.key, required this.controller, required super.child});

  /// The provided controller.
  final UIKitTabBarController controller;

  /// The nearest controller, if any.
  static UIKitTabBarController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UIKitTabBarScope>()?.controller;

  @override
  bool updateShouldNotify(UIKitTabBarScope oldWidget) => controller != oldWidget.controller;
}
