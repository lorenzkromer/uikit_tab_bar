import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'icon_renderer.dart';
import 'model.dart';
import 'protocol.dart';
import 'tab_bar.dart';

/// Height of the platform view hosting the native controller. The glass
/// bar, accessory and search field are laid out inside it by UIKit; the
/// transparent rest lets touches through to Flutter.
const double kNativeHostHeight = 200;

/// The UIKit-backed implementation of [UIKitTabBar].
class NativeTabBar extends StatefulWidget {
  /// Creates the native bar.
  const NativeTabBar({super.key, required this.config, required this.controller});

  /// The public widget's configuration.
  final UIKitTabBar config;

  /// The controller in use.
  final UIKitTabBarController controller;

  @override
  State<NativeTabBar> createState() => NativeTabBarState();
}

/// State of [NativeTabBar]; visible for tests.
@visibleForTesting
class NativeTabBarState extends State<NativeTabBar> implements UIKitTabBarConnection {
  MethodChannel? _channel;
  Map<String, Object?>? _lastSent;
  final Set<String> _sentImages = {};
  bool _updateScheduled = false;
  double _scale = 3;
  double _extraHeight = 0;
  UIKitTabBarGeometry _geometry = UIKitTabBarGeometry.initial;
  bool _searchActive = false;
  Map<String, Object?>? _lastScroll;
  late Map<String, Object?> _creationParams;

  UIKitTabBar get _config => widget.config;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scale = MediaQuery.devicePixelRatioOf(context);
    if (_channel == null) {
      final encoded = _encode();
      _creationParams = {'state': encoded, 'images': _takeImages(encoded)};
      _lastSent = encoded;
    } else {
      _scheduleUpdate();
    }
  }

  @override
  void didUpdateWidget(NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach(this);
      widget.controller.attach(this);
      widget.controller.setGeometry(_geometry);
    }
    if (oldWidget.config.selectedId != _config.selectedId) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.resendVisibleScroll();
      });
    }
    _scheduleUpdate();
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  TabBarState get _state => TabBarState(
    tabs: _config.tabs,
    selectedId: _config.selectedId,
    searchTab: _config.searchTab,
    prominentTabId: _config.prominentTabId,
    minimizeBehavior: _config.minimizeBehavior,
    hidden: _config.hidden,
    accessory: _config.accessory,
    style: _config.style,
    brightness:
        _config.style.brightness ??
        CupertinoTheme.maybeBrightnessOf(context) ??
        MediaQuery.platformBrightnessOf(context),
    rtl: Directionality.maybeOf(context) == TextDirection.rtl,
  );

  Map<String, Object?> _encode() => encodeState(
    _state,
    (icon) => IconRenderer.instance.lookup(icon, _scale, onReady: _scheduleUpdate),
  );

  /// PNGs for image keys the native side has not received yet.
  Map<String, Uint8List> _takeImages(Map<String, Object?> encoded) {
    final images = <String, Uint8List>{};
    final keys = referencedImageKeys(encoded).difference(_sentImages);
    if (keys.isEmpty) return images;
    for (final icon in _state.imageIcons) {
      final rendered = IconRenderer.instance.lookup(icon, _scale);
      if (rendered != null && keys.contains(rendered.key)) images[rendered.key] = rendered.png;
    }
    _sentImages.addAll(images.keys);
    return images;
  }

  void _scheduleUpdate() {
    if (_updateScheduled || !mounted) return;
    _updateScheduled = true;
    // Coalesce all changes of one frame into a single native batch.
    scheduleMicrotask(() {
      _updateScheduled = false;
      if (mounted) _sendUpdate();
    });
  }

  void _sendUpdate({bool force = false}) {
    final channel = _channel;
    if (channel == null) return;
    final encoded = _encode();
    if (!force && encodedEquals(encoded, _lastSent)) return;
    _lastSent = encoded;
    final images = _takeImages(encoded);
    channel.invokeMethod<void>('update', {'state': encoded, 'images': images, 'animated': true});
  }

  void _onCreated(int id) {
    final channel = MethodChannel(channelName(id));
    channel.setMethodCallHandler(_handle);
    _channel = channel;
    // The creation params may be outdated by now, and the content's first
    // scroll metrics were reported before the channel existed.
    _sendUpdate();
    widget.controller.resendVisibleScroll();
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments is Map
        ? (call.arguments as Map).cast<Object?, Object?>()
        : const {};
    switch (call.method) {
      case 'selected':
        final id = args['id'] as String;
        _config.onSelected(id);
        // Reconcile: if the app vetoed (kept selectedId), native goes back.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sendUpdate(force: true);
        });
        SchedulerBinding.instance.ensureVisualUpdate();
      case 'reselected':
        _config.onReselect?.call(args['id'] as String);
      case 'geometry':
        _setGeometry(decodeGeometry(args));
      case 'searchChanged':
        _config.searchTab?.onChanged?.call(args['text'] as String? ?? '');
      case 'searchSubmitted':
        _config.searchTab?.onSubmitted?.call(args['text'] as String? ?? '');
      case 'searchActive':
        final active = args['active'] == true;
        setState(() => _searchActive = active);
        widget.controller.setSearchActive(active);
        _config.searchTab?.onActiveChanged?.call(active);
      case 'accessoryTap':
        _config.accessory?.onTap?.call();
      case 'accessoryAction':
        _config.accessory?.onAction?.call(args['id'] as String);
    }
    return null;
  }

  void _setGeometry(UIKitTabBarGeometry geometry) {
    // Grow the host if the search field (the only element that can sit
    // high above the bar) is laid out near or above its top edge.
    final top = geometry.searchFieldRect?.top ?? double.infinity;
    final grow = top < 8 ? 8 - top : 0.0;
    final changed = geometry != _geometry;
    if (!changed && grow == 0) return;
    setState(() {
      _geometry = geometry;
      _extraHeight += grow;
    });
    if (!changed) return;
    widget.controller.setGeometry(geometry);
    _config.onGeometryChanged?.call(geometry);
  }

  @override
  void reportScroll(ScrollMetrics metrics) {
    final channel = _channel;
    if (channel == null || !metrics.hasContentDimensions || !metrics.hasPixels) return;
    final args = encodeScroll(
      tabId: _config.selectedId,
      pixels: metrics.pixels,
      minScrollExtent: metrics.minScrollExtent,
      maxScrollExtent: metrics.maxScrollExtent,
      viewportDimension: metrics.viewportDimension,
    );
    if (encodedEquals(args, _lastScroll)) return;
    _lastScroll = args;
    channel.invokeMethod<void>('scroll', args);
  }

  @override
  Future<void> searchCommand(String action, [String? text]) async {
    await _channel?.invokeMethod<void>('search', {'action': action, 'text': text});
  }

  @override
  Widget build(BuildContext context) {
    // While the native search field is active, the host fills the
    // available height: UIKit then places the field at the top below the
    // status bar, as in a native app, instead of at the top of a strip.
    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return SizedBox(
          height: _searchActive ? full : kNativeHostHeight + _extraHeight,
          child: NativeHitRegion(
            rects: _geometry.hitRects,
            child: UiKitView(
              viewType: kViewType,
              creationParams: _creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onCreated,
              gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
              },
            ),
          ),
        );
      },
    );
  }
}

/// Lets pointer events reach its child only inside [rects]; everything
/// else falls through to the widgets behind.
class NativeHitRegion extends SingleChildRenderObjectWidget {
  /// Creates a hit region.
  const NativeHitRegion({super.key, required this.rects, super.child});

  /// Areas that hit the child, in local coordinates.
  final List<Rect> rects;

  @override
  RenderNativeHitRegion createRenderObject(BuildContext context) => RenderNativeHitRegion(rects);

  @override
  void updateRenderObject(BuildContext context, RenderNativeHitRegion renderObject) {
    renderObject.rects = rects;
  }
}

/// Render object of [NativeHitRegion].
class RenderNativeHitRegion extends RenderProxyBox {
  /// Creates the render object.
  RenderNativeHitRegion(this.rects);

  /// Areas that hit the child.
  List<Rect> rects;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!rects.any((r) => r.contains(position))) return false;
    return super.hitTest(result, position: position);
  }
}
