import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import 'controller.dart';
import 'model.dart';
import 'tab_bar.dart';

/// [CupertinoTabBar] built from the same configuration, for iOS < 26 and
/// all other platforms. Native-only features (accessory, minimizing,
/// prominent tab, native search field) are not reproduced.
class FallbackTabBar extends StatelessWidget {
  /// Creates the fallback bar.
  const FallbackTabBar({super.key, required this.config, required this.controller});

  /// The public widget's configuration.
  final UIKitTabBar config;

  /// The controller in use.
  final UIKitTabBarController controller;

  List<_Item> get _items => [
        for (final tab in config.tabs)
          if (!tab.hidden) _Item(tab.id, tab.label, tab.enabled, tab.badge, _icon(tab, false), _icon(tab, true)),
        if (config.searchTab case final search?)
          _Item(
            search.id,
            search.label ?? 'Search',
            true,
            null,
            search.fallbackIcon ?? const _SearchGlyph(),
            search.fallbackIcon ?? const _SearchGlyph(),
          ),
      ];

  static Widget _icon(UIKitTab tab, bool selected) {
    final explicit = selected ? tab.fallbackSelectedIcon ?? tab.fallbackIcon : tab.fallbackIcon;
    if (explicit != null) return explicit;
    final icon = selected ? tab.selectedIcon ?? tab.icon : tab.icon;
    return switch (icon) {
      UIKitIconDataIcon(:final icon) => Icon(icon),
      UIKitImageIcon(:final image, :final size) =>
        ImageIcon(image, size: size.shortestSide),
      UIKitSymbolIcon(:final name) => throw FlutterError(
          'UIKitTab "${tab.id}" uses the SF Symbol "$name" but has no fallbackIcon. '
          'SF Symbols only exist on iOS; set UIKitTab.fallbackIcon.',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final padding = MediaQuery.paddingOf(context).bottom;
    if (config.hidden || items.length < 2) {
      _report(UIKitTabBarGeometry(isNative: false, bottomInset: padding, hidden: config.hidden));
      return const SizedBox.shrink();
    }
    final index = items.indexWhere((i) => i.id == config.selectedId);
    final bar = CupertinoTabBar(
      currentIndex: index < 0 ? 0 : index,
      activeColor: config.style.selectedColor ?? config.style.tintColor,
      onTap: (i) {
        final item = items[i];
        if (!item.enabled) return;
        if (item.id == config.selectedId) {
          config.onReselect?.call(item.id);
        } else {
          config.onSelected(item.id);
        }
      },
      items: [
        for (final item in items)
          BottomNavigationBarItem(
            label: item.label,
            icon: _decorate(item, item.icon),
            activeIcon: _decorate(item, item.activeIcon),
          ),
      ],
    );
    final height = bar.preferredSize.height + padding;
    _report(UIKitTabBarGeometry(
      isNative: false,
      bottomInset: height,
      barRect: Rect.fromLTWH(0, 0, MediaQuery.sizeOf(context).width, height),
    ));
    return bar;
  }

  Widget _decorate(_Item item, Widget icon) {
    Widget result = icon;
    if (item.badge case final badge?) {
      result = _Badge(
        text: badge,
        color: config.style.badgeColor,
        textColor: config.style.badgeTextColor,
        child: result,
      );
    }
    if (!item.enabled) result = Opacity(opacity: 0.4, child: result);
    return result;
  }

  void _report(UIKitTabBarGeometry geometry) {
    if (controller.geometry.value == geometry) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (controller.geometry.value == geometry) return;
      controller.setGeometry(geometry);
      config.onGeometryChanged?.call(geometry);
    });
  }
}

class _Item {
  const _Item(this.id, this.label, this.enabled, this.badge, this.icon, this.activeIcon);
  final String id;
  final String label;
  final bool enabled;
  final String? badge;
  final Widget icon;
  final Widget activeIcon;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.textColor, required this.child});
  final String text;
  final Color? color;
  final Color? textColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            constraints: BoxConstraints(minWidth: text.isEmpty ? 10 : 18, minHeight: text.isEmpty ? 10 : 18),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: color ?? CupertinoColors.systemRed.resolveFrom(context),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: text.isEmpty
                ? null
                : Text(
                    text,
                    style: TextStyle(color: textColor ?? CupertinoColors.white, fontSize: 12, height: 1.2),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Magnifier drawn directly: `CupertinoIcons` needs the `cupertino_icons`
/// font, which this package does not depend on.
class _SearchGlyph extends StatelessWidget {
  const _SearchGlyph();

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SearchPainter(theme.color ?? const Color(0xFF000000))),
    );
  }
}

class _SearchPainter extends CustomPainter {
  _SearchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round;
    final center = Offset(s * 0.42, s * 0.42);
    final radius = s * 0.28;
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(center + Offset(radius * 0.72, radius * 0.72), Offset(s * 0.88, s * 0.88), paint);
  }

  @override
  bool shouldRepaint(_SearchPainter oldDelegate) => oldDelegate.color != color;
}
