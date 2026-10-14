import 'dart:ui' show Canvas, Color, Offset, Path, Size;

import 'package:flutter/animation.dart' show Curves;

import '../../../animation/scan_fx_frame.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// Concentric waves that expand out from the locked frame and dissolve.
///
/// Each wave is the same [ScanQuadPathCache.outline] path, scaled with a canvas
/// transform rather than rebuilt per wave. That is what lets the style draw
/// [ScanSuccessOptions.rippleWaves] rings for the cost of one cached path, and it
/// makes the waves inherit the frame's shape — a `circle` theme ripples
/// circularly, a `squircle` theme with continuous corners.
class RippleWavesEffect extends ScanSuccessEffect {
  /// Creates the style.
  RippleWavesEffect();

  /// Fraction of the burst between the launch of one wave and the next.
  static const double _stagger = 0.2;

  /// Fraction of the burst a single wave lives for.
  static const double _life = 0.68;

  /// How far past the frame the last wave reaches, as a fraction of its size.
  static const double _expansion = 0.5;

  /// Peak opacity of a wave at full intensity.
  static const double _peak = 0.5;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = successBurst(frame);
    if (burst < 0) return;

    final path = paths.outline(frame);
    final center = frame.quad.center;
    final width = frame.theme.frameStrokeWidth * 1.3;
    final sigma = ScanGlow.sigmaFor(frame.glow, width);

    if (frame.reduceMotion) {
      // The steady state is the *result* of a ripple: one settled ring. Drawing
      // it at the resting scale rather than at full expansion keeps the frame
      // legible under reduce-motion.
      final alpha = steadyState(frame, _peak) * frame.reveal;
      if (alpha <= 0.004) return;
      _wave(
        canvas,
        path,
        center,
        1 + _expansion * 0.4,
        width,
        sigma,
        ScanFxPalette.fade(frame.stateColor, alpha),
      );
      return;
    }

    final waves = frame.theme.success.rippleWaves;
    if (waves <= 0) return;

    for (var i = 0; i < waves; i++) {
      // Computed directly rather than through [ScanFxFrame.local] so a wave that
      // has not launched yet is skipped instead of sitting on the frame edge at
      // full opacity.
      final t = (burst - i * _stagger) / _life;
      if (t <= 0 || t >= 1) continue;

      final eased = Curves.easeOutCubic.transform(t);
      final alpha = (1 - t) * (1 - t) * _peak * frame.intensity * frame.reveal;
      if (alpha <= 0.004) continue;

      _wave(
        canvas,
        path,
        center,
        1 + _expansion * eased,
        width,
        sigma * (1 - eased * 0.6),
        ScanFxPalette.fade(frame.stateColor, alpha),
      );
    }
  }

  /// Draws one ring, scaled about the quad's centre.
  ///
  /// The stroke is pre-divided by [scale] so the canvas transform leaves the
  /// on-screen width constant — a wave that thickened as it grew would read as
  /// the frame inflating rather than as a ring travelling away from it.
  void _wave(
    Canvas canvas,
    Path path,
    Offset center,
    double scale,
    double width,
    double sigma,
    Color color,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    ScanGlow.strokePath(canvas, path, color, width / scale, sigma, cache);
    canvas.restore();
  }
}
