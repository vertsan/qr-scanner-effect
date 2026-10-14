import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../geometry/scan_fx_shapes.dart';
import '../../../physics/scan_fx_curves.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// A cross that draws itself across the frame.
///
/// The natural counterpart to the success check mark: the same in-quad layout,
/// the same draw-on, the opposite meaning. Both legs grow together from their
/// starts and the whole mark fades out as the burst ends, so the frame is left
/// exactly as it was found.
///
/// It paints in [ScanFxFrame.stateColor], so an `error` gets the error colour and
/// an `invalid` read gets the invalid one from this single implementation.
class CrossMorphEffect extends ScanFaultEffect {
  /// Creates the style.
  CrossMorphEffect();

  /// Where the draw-on starts within the fault burst.
  static const double _start = 0.02;

  /// How much of the burst the stroke takes.
  static const double _span = 0.5;

  /// Peak opacity of the cross at full intensity.
  static const double peak = 0.9;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = faultBurst(frame);
    if (burst < 0) return;

    final progress = frame.reduceMotion
        ? 1.0
        : ScanFxCurves.overshootSoft.transform(frame.local(_start, _span));
    final strength = frame.reduceMotion
        ? steadyState(frame, peak * 0.7)
        : progress * (1 - burst) * peak * frame.intensity;
    if (strength <= 0.004) return;

    final quad = frame.quad;
    final fromA = ScanFxShapes.quadPoint(quad, 0.27, 0.27);
    final toA = ScanFxShapes.quadPoint(quad, 0.73, 0.73);
    final fromB = ScanFxShapes.quadPoint(quad, 0.73, 0.27);
    final toB = ScanFxShapes.quadPoint(quad, 0.27, 0.73);

    final length = math.max(
      (toA - fromA).distance,
      (toB - fromB).distance,
    );
    if (length <= 1e-3) return;

    final drawn = (progress.clamp(0.0, 1.0)) * length;
    final tipA = _advance(fromA, toA, drawn);
    final tipB = _advance(fromB, toB, drawn);

    final color = ScanFxPalette.fade(
      frame.stateColor,
      strength * frame.reveal,
    );
    final width =
        frame.theme.error.crossStrokeWidth * (0.65 + 0.35 * frame.intensity);
    final sigma = ScanGlow.sigmaFor(frame.glow * 0.9, width);

    if (sigma > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 1.7;
      canvas.drawLine(fromA, tipA, cache.glow);
      canvas.drawLine(fromB, tipB, cache.glow);
    }
    cache.stroke
      ..color = color
      ..strokeWidth = width;
    canvas.drawLine(fromA, tipA, cache.stroke);
    canvas.drawLine(fromB, tipB, cache.stroke);
  }

  /// A point [distance] along the segment [from] → [to], clamped to the end.
  static Offset _advance(Offset from, Offset to, double distance) {
    final delta = to - from;
    final length = delta.distance;
    if (length < 1e-6) return from;
    final t = (distance / length).clamp(0.0, 1.0);
    return from + delta * t;
  }
}
