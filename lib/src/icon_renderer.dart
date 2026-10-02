import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'model.dart';
import 'protocol.dart';

/// Renders non-symbol icons to template PNGs, once per icon and scale.
///
/// Shared by all bars; the native side caches decoded images per view by
/// [RenderedIcon.key].
class IconRenderer {
  IconRenderer._();

  /// The process-wide renderer.
  static final IconRenderer instance = IconRenderer._();

  /// Nominal tab bar glyph size in points.
  static const double glyphSize = 26;

  final Map<(UIKitTabIcon, double), RenderedIcon> _done = {};
  final Map<(UIKitTabIcon, double), Future<RenderedIcon?>> _pending = {};
  int _counter = 0;

  /// The rendered icon, or `null` while rendering. [onReady] runs once the
  /// icon becomes available.
  RenderedIcon? lookup(UIKitTabIcon icon, double scale, {VoidCallback? onReady}) {
    final key = (icon, scale);
    final done = _done[key];
    if (done != null) return done;
    final pending = _pending[key] ??= _render(icon, scale).then((r) {
      _pending.remove(key);
      if (r != null) _done[key] = r;
      return r;
    });
    if (onReady != null) pending.then((r) => r != null ? onReady() : null);
    return null;
  }

  /// Renders all [icons] and completes when done (for tests and warm-up).
  Future<void> precache(Iterable<UIKitTabIcon> icons, double scale) async {
    await Future.wait([
      for (final icon in icons)
        if (lookup(icon, scale) == null) _pending[(icon, scale)] ?? Future.value(),
    ]);
  }

  Future<RenderedIcon?> _render(UIKitTabIcon icon, double scale) async {
    final ui.Image? image = switch (icon) {
      UIKitSymbolIcon() => null,
      UIKitIconDataIcon(:final icon) => _renderGlyph(icon, scale),
      UIKitImageIcon(:final image, :final size) => await _renderImage(image, size, scale),
    };
    if (image == null) return null;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return RenderedIcon(key: 'i${_counter++}', png: data.buffer.asUint8List(), scale: scale);
  }

  ui.Image _renderGlyph(IconData icon, double scale) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          fontSize: glyphSize,
          height: 1,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontFamilyFallback: icon.fontFamilyFallback,
          color: const Color(0xFF000000),
        ),
      ),
    )..layout();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    painter.paint(
      canvas,
      Offset((glyphSize - painter.width) / 2, (glyphSize - painter.height) / 2),
    );
    painter.dispose();
    final px = (glyphSize * scale).ceil();
    return recorder.endRecording().toImageSync(px, px);
  }

  Future<ui.Image?> _renderImage(ImageProvider provider, Size size, double scale) async {
    final completer = Completer<ImageInfo?>();
    final stream = provider.resolve(ImageConfiguration(devicePixelRatio: scale, size: size));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info);
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
        FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'uikit_tab_bar',
          context: ErrorDescription('while loading a tab icon image'),
        ));
      },
    );
    stream.addListener(listener);
    final info = await completer.future;
    if (info == null) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final dst = Rect.fromLTWH(0, 0, size.width * scale, size.height * scale);
    paintImage(canvas: canvas, rect: dst, image: info.image, fit: BoxFit.contain);
    info.dispose();
    return recorder
        .endRecording()
        .toImageSync(dst.width.ceil(), dst.height.ceil());
  }
}
