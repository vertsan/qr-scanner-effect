import 'dart:math' as math;
import 'dart:ui' show Canvas, PaintingStyle, RRect, Radius, Rect, Size;

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_corner_layer.dart';

/// A short filled capsule at each corner, aligned with the corner's bisector.
///
/// Arms are lines; this is a solid. The capsule points inwards along the
/// diagonal, so a rotated or perspective-skewed code still gets four markers
/// that look placed rather than projected. It is the chunkiest corner style and
/// the natural partner for a thin or absent frame outline.
class PillCorners extends ScanCornerLayer {
  /// Creates the style.
  PillCorners();

  /// Capsule thickness, as a multiple of the stroke width.
  static const double thicknessFactor = 1.6;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final color = ScanFxPalette.fade(colorFor(frame), frame.reveal);
    if (color.a <= 0.004) return;

    final quad = frame.quad;
    final inset = insetFor(frame);
    final length = armFor(frame);
    final thickness = frame.theme.cornerStrokeWidth * thicknessFactor;
    final sigma = ScanGlow.sigmaFor(glowFor(frame), thickness);
    final radius = Radius.circular(thickness / 2);

    for (var i = 0; i < 4; i++) {
      final origin = ScanCornerLayer.bracketOrigin(quad, i, inset);
      final towards = ScanCornerLayer.unit(origin, quad.center);
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(math.atan2(towards.dy, towards.dx));
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -thickness / 2, length, thickness),
        radius,
      );

      if (sigma > 0) {
        cache.applyGlowBlur(sigma);
        cache.glow
          ..style = PaintingStyle.fill
          ..color = color;
        canvas.drawRRect(rrect, cache.glow);
        cache.glow.style = PaintingStyle.stroke;
      }
      cache.fill.color = color;
      canvas.drawRRect(rrect, cache.fill);
      canvas.restore();
    }
  }
}
