import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// Concentric rings expanding outwards from the head.
///
/// A sonar-like beam that reads as "energy pulsing out of the read point". It
/// works with any direction: on [ScanBeamDirection.radial] the rings bloom from
/// the rim, on a straight sweep they trail the line.
class PulseRingsBeam extends ScanBeamLayer {
  /// Creates the style.
  PulseRingsBeam();

  /// How many rings are in flight at once.
  static const int rings = 3;

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final maxRadius = math.min(local.width, local.height) * 0.5;
    if (maxRadius <= 1) return;

    final color = frame.theme.beamAccentColor;
    final center = Offset(headX, headY);
    final width = math.max(1.0, frame.beamThickness * 0.8);
    final sigma = ScanGlow.sigmaFor(frame.glow * 0.5, width);
    final reveal = frame.reveal;
    final intensity = frame.intensity;
    final bloom = sigma > 0 && cache.applyGlowBlur(sigma);

    for (var i = 0; i < rings; i++) {
      final phase = (t + i / rings) % 1;
      final alpha = (1 - phase) * 0.7 * intensity * reveal;
      if (alpha <= 0.002) continue;
      final radius = phase * maxRadius;
      if (radius < 0.5) continue;
      final ring = ScanFxPalette.withAlpha(color, alpha);
      if (bloom) {
        cache.glow
          ..color = ring
          ..strokeWidth = width * 1.4;
        canvas.drawCircle(center, radius, cache.glow);
      }
      cache.stroke
        ..color = ring
        ..strokeWidth = width;
      canvas.drawCircle(center, radius, cache.stroke);
    }
  }
}
