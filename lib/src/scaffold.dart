import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'model.dart';
import 'platform_support.dart';
import 'tab_bar.dart';

/// Lays out [body] behind a floating [tabBar] and wires them together:
///
/// * the body extends to the bottom edge (the glass bar shows it through),
/// * `MediaQuery.padding.bottom` of the body is the bar's reported
///   [UIKitTabBarGeometry.bottomInset], so `SafeArea`, `ListView` etc. keep
///   their content clear of the bar; while the native search field is
///   active at the top, `padding.top` covers it ([UIKitTabBarGeometry.topInset]),
/// * vertical scrolling of the body's primary scrollable is forwarded so
///   the native bar can minimize.
///
/// Place it outside any widget that resizes for the keyboard (or set
/// `resizeToAvoidBottomInset: false` there) so the bar stays at the bottom
/// edge like a native one.
class UIKitTabScaffold extends StatefulWidget {
  /// Creates a scaffold.
  const UIKitTabScaffold({super.key, required this.tabBar, required this.body, this.controller});

  /// The bar, usually a [UIKitTabBar].
  final Widget tabBar;

  /// Content of the selected tab.
  final Widget body;

  /// Optional controller; one is created otherwise.
  final UIKitTabBarController? controller;

  @override
  State<UIKitTabScaffold> createState() => _UIKitTabScaffoldState();
}

class _UIKitTabScaffoldState extends State<UIKitTabScaffold> {
  UIKitTabBarController? _own;

  UIKitTabBarController get _controller => widget.controller ?? (_own ??= UIKitTabBarController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return UIKitTabBarScope(
      controller: controller,
      child: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<UIKitTabBarGeometry>(
              valueListenable: controller.geometry,
              builder: (context, geometry, child) {
                final media = MediaQuery.of(context);
                final inset = geometry == UIKitTabBarGeometry.initial
                    ? estimatedBottomInset(media.padding.bottom)
                    : geometry.bottomInset;
                final top = geometry.topInset;
                return MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(
                      top: math.max(media.padding.top, top),
                      bottom: math.max(media.padding.bottom, inset),
                    ),
                    viewPadding: media.viewPadding.copyWith(
                      top: math.max(media.viewPadding.top, top),
                      bottom: math.max(media.viewPadding.bottom, inset),
                    ),
                  ),
                  child: child!,
                );
              },
              child: UIKitTabBarScrollListener(controller: controller, child: widget.body),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: widget.tabBar),
        ],
      ),
    );
  }
}

/// Bottom inset assumed before the bar has reported its layout.
double estimatedBottomInset(double safeBottom) =>
    (nativeTabBarSupported ? 49.0 : 50.0) + safeBottom;
