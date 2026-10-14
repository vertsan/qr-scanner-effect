import 'dart:ui' show Canvas, Offset, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../geometry/scan_fx_quad.dart';
import '../../../physics/scan_fx_curves.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// A check mark that draws itself inside the frame.
///
/// The mark is laid out in the quad's own space — a fraction across the top edge
/// and a fraction down the left edge — so it lands correctly on a rotated,
/// perspective-skewed, tiny or huge scan area without a single special case.
///
/// Under reduce-motion the mark is simply already drawn: the *result* of the
/// effect is the check mark, and skipping the motion keeps that result.
class CheckMorphEffect extends ScanSuccessEffect {
  /// Creates the style.
  CheckMorphEffect();

  /// Where the draw-on starts within the success burst.
  static const double _start = 0.02;

  /// How much of the burst the stroke takes.
  static const double _span = 0.46;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = successBurst(frame);
    if (burst < 0) return;

    final progress = frame.reduceMotion
        ? 1.0
        : ScanFxCurves.overshootSoft.transform(frame.local(_start, _span));
    if (progress <= 0) return;

    final quad = frame.quad;
    final first = _point(quad, 0.24, 0.52);
    final joint = _point(quad, 0.44, 0.73);
    final last = _point(quad, 0.78, 0.28);

    final firstLeg = (joint - first).distance;
    final secondLeg = (last - joint).distance;
    final total = firstLeg + secondLeg;
    if (total <= 1e-3) return;

    final drawn = progress * total;
    final secondVisible = drawn > firstLeg;
    final tip = !secondVisible
        ? first + (joint - first) / firstLeg * drawn
        : joint + (last - joint) / secondLeg * (drawn - firstLeg);

    final color = ScanFxPalette.fade(
      frame.theme.successColor,
      frame.reveal,
    );
    final width =
        frame.theme.success.checkStrokeWidth * (0.65 + 0.35 * frame.intensity);
    final sigma = ScanGlow.sigmaFor(frame.glow * 0.9, width);

    if (sigma > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 1.7;
      canvas.drawLine(first, tip, cache.glow);
      if (secondVisible) canvas.drawLine(joint, tip, cache.glow);
    }

    cache.stroke
      ..color = color
      ..strokeWidth = width;
    canvas.drawLine(first, tip, cache.stroke);
    if (secondVisible) canvas.drawLine(joint, tip, cache.stroke);
  }

  /// A point [across] of the way along the quad's top edge and [down] of the way
  /// along its left edge.
  ///
  /// Bilinear interpolation, so the point tracks rotation, perspective and scale
  /// together.
  static Offset _point(ScanFxQuad quad, double across, double down) =>
      quad.topLeft +
      (quad.topRight - quad.topLeft) * across +
      (quad.bottomLeft - quad.topLeft) * down;
}
