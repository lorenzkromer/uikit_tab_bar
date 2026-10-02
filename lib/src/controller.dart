import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'model.dart';

/// Connects a [UIKitTabBar] with the content behind it.
///
/// [UIKitTabScaffold] creates one automatically. Use your own when placing
/// the bar yourself: feed scroll notifications of the selected tab's
/// primary scrollable to [handleScrollNotification] (or wrap the content in
/// [UIKitTabBarScrollListener]) so the native bar can minimize, and read
/// [geometry] for bottom padding.
class UIKitTabBarController {
  final ValueNotifier<UIKitTabBarGeometry> _geometry = ValueNotifier(UIKitTabBarGeometry.initial);
  final ValueNotifier<bool> _searchActive = ValueNotifier(false);
  UIKitTabBarConnection? _connection;

  /// The bar's last reported layout.
  ValueListenable<UIKitTabBarGeometry> get geometry => _geometry;

  /// Whether the native search field is active.
  ValueListenable<bool> get searchActive => _searchActive;

  /// Forwards a scroll notification. Only vertical notifications of
  /// `depth == 0` (the tab's primary scrollable) are used.
  ///
  /// Returns `false` so it can be used directly as a
  /// `NotificationListener` callback.
  bool handleScrollNotification(ScrollNotification notification) {
    _handle(notification.depth, notification.metrics, notification.context);
    return false;
  }

  /// Like [handleScrollNotification], for metrics-only changes (content
  /// size changes without scrolling).
  bool handleScrollMetricsNotification(ScrollMetricsNotification notification) {
    _handle(notification.depth, notification.metrics, notification.context);
    return false;
  }

  /// Last metrics per scrollable, to re-send after the selection changes.
  final Map<BuildContext, ScrollMetrics> _latest = {};

  void _handle(int depth, ScrollMetrics metrics, BuildContext? context) {
    if (depth != 0 || metrics.axis != Axis.vertical) return;
    if (context != null) {
      _latest.removeWhere((c, _) => !c.mounted);
      _latest[context] = metrics;
      // Tabs kept alive offstage (IndexedStack) report too; only the
      // visible one belongs to the selected tab.
      if (!TickerMode.getValuesNotifier(context).value.enabled) return;
    }
    _connection?.reportScroll(metrics);
  }

  /// Activates the native search field (selects the search tab).
  Future<void> activateSearch() async => _connection?.searchCommand('activate');

  /// Ends the search and hides the keyboard.
  Future<void> dismissSearch() async => _connection?.searchCommand('dismiss');

  /// Replaces the text of the native search field.
  Future<void> setSearchText(String text) async => _connection?.searchCommand('setText', text);

  /// Releases resources.
  void dispose() {
    _geometry.dispose();
    _searchActive.dispose();
  }
}

/// Internal link between a controller and the bar that uses it.
abstract interface class UIKitTabBarConnection {
  /// Mirrors the primary scrollable onto the native proxy.
  void reportScroll(ScrollMetrics metrics);

  /// Sends a search command.
  Future<void> searchCommand(String action, [String? text]);
}

/// Library-private access for the bar implementation.
extension UIKitTabBarControllerInternals on UIKitTabBarController {
  /// Attaches the bar implementation.
  void attach(UIKitTabBarConnection connection) => _connection = connection;

  /// Detaches if [connection] is the attached one.
  void detach(UIKitTabBarConnection connection) {
    if (identical(_connection, connection)) _connection = null;
  }

  /// Publishes a new geometry.
  void setGeometry(UIKitTabBarGeometry value) => _geometry.value = value;

  /// Re-sends the metrics of the visible primary scrollable (after a tab
  /// change, before the new tab scrolls).
  void resendVisibleScroll() {
    _latest.removeWhere((c, _) => !c.mounted);
    for (final MapEntry(key: context, value: metrics) in _latest.entries) {
      if (TickerMode.getValuesNotifier(context).value.enabled) _connection?.reportScroll(metrics);
    }
  }

  /// Publishes the search field state.
  void setSearchActive(bool value) => _searchActive.value = value;
}

/// Forwards scroll notifications of [child] to [controller].
class UIKitTabBarScrollListener extends StatelessWidget {
  /// Creates a listener.
  const UIKitTabBarScrollListener({super.key, required this.controller, required this.child});

  /// The bar's controller.
  final UIKitTabBarController controller;

  /// The tab content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: controller.handleScrollMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: controller.handleScrollNotification,
        child: child,
      ),
    );
  }
}
