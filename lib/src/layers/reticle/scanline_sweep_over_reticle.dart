import 'dart:ui' show Canvas, Offset, Size;

import '../../animation/scan_fx_frame.dart';
import '../paint/scan_glow.dart';
import 'scan_reticle_layer.dart';

/// A bright line that sweeps across the target and fades.
///
/// The sweep runs in the quad's own rotated space, so a code held at an angle
/// gets a line that stays parallel to *its* edges rather than to the screen. It
/// is the quietest of the decorative flourishes, which makes it a good fit for
/// themes that want motion without spectacle.
class ScanlineSweepOverReticle extends ScanReticleLayer {
  /// Creates the style.
  ScanlineSweepOverReticle();

  /// How many times the line crosses the target during the lock.
  static const double passes = 1.4;

  /// Peak opacity of the line at full intensity.
  static const double peak = 0.7;

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.hasTarget) return;

    final progress = frame.focus.clamp(0.0, 1.0);
    final alpha = focusEnvelope(progress, rise: 0.16, fall: 0.28) *
        peak *
        frame.intensity;
    if (alpha <= 0.004) return;

    final quad = frame.quad;
    final width = (quad.topRight - quad.topLeft).distance;
    final height = (quad.bottomLeft - quad.topLeft).distance;
    if (width <= 1 || height <= 1) return;

    final sweep = (progress * passes) % 1;
    final y = height * (sweep - 0.5);
    final stroke = frame.beamThickness;

    canvas.save();
    canvas.translate(quad.center.dx, quad.center.dy);
    canvas.rotate(quad.rotation);
    ScanGlow.line(
      canvas,
      Offset(-width / 2, y),
      Offset(width / 2, y),
      reticleColor(frame, alpha),
      stroke,
      ScanGlow.sigmaFor(frame.glow, stroke),
      cache,
    );
    canvas.restore();
  }
}
