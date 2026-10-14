import 'dart:ui'
    show Canvas, Color, Offset, PaintingStyle, Path, Rect;

import 'scan_paint_cache.dart';

/// The package's glow helper.
///
/// Bloom is the single most expensive thing an overlay can do, so it lives in
/// one place with one policy:
///
/// * [sigmaFor] converts a `0..1` strength into a blur radius and returns `0`
///   when glow is disabled, letting callers skip the blur pass entirely.
/// * Every draw reuses a cached [Paint] and only rebuilds the blur filter when
///   the radius actually changes.
///
/// A future shader-based bloom can be dropped in here without touching a single
/// layer, because layers only ever call these helpers.
abstract final class ScanGlow {
  /// Converts a glow [strength] (`0..1`) and a stroke [width] into a blur
  /// radius. Returns `0` when glow should be skipped.
  static double sigmaFor(double strength, [double width = 2]) {
    if (strength <= 0) return 0;
    final s = strength.clamp(0.0, 1.0);
    return (1.5 + 7.5 * s) * (0.75 + width * 0.05);
  }

  /// Draws a blurred copy of [path] underneath a crisp stroke.
  ///
  /// The blurred pass is skipped when [sigma] is `0`, and the crisp pass is
  /// always drawn so the shape stays legible without bloom.
  static void strokePath(
    Canvas canvas,
    Path path,
    Color color,
    double width,
    double sigma,
    ScanPaintCache cache,
  ) {
    if (sigma > 0 && color.a > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 1.4;
      canvas.drawPath(path, cache.glow);
    }
    cache.stroke
      ..color = color
      ..strokeWidth = width;
    canvas.drawPath(path, cache.stroke);
  }

  /// Fills a circle with an optional bloom.
  static void circle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double sigma,
    ScanPaintCache cache,
  ) {
    if (radius <= 0 || color.a <= 0) return;
    if (sigma > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawCircle(center, radius, cache.glow);
      cache.glow.style = PaintingStyle.stroke;
    }
    cache.fill.color = color;
    canvas.drawCircle(center, radius, cache.fill);
  }

  /// Strokes a rectangle with an optional bloom.
  static void strokeRect(
    Canvas canvas,
    Rect rect,
    Color color,
    double width,
    double sigma,
    ScanPaintCache cache,
  ) {
    if (sigma > 0 && color.a > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 1.4;
      canvas.drawRect(rect, cache.glow);
    }
    cache.stroke
      ..color = color
      ..strokeWidth = width;
    canvas.drawRect(rect, cache.stroke);
  }
}
