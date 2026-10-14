import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// A bright core line inside two bloom passes.
///
/// The widest, softest beam. It forces a minimum glow so the look is never
/// half-applied, but it still honours the glow tunable as a *scale*: setting the
/// tunable to `0` removes both blur passes and leaves the crisp core.
class GlowingLaserBeam extends ScanBeamLayer {
  /// Creates the style.
  const GlowingLaserBeam();

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final width = frame.beamThickness;
    final color = ScanFxPalette.fade(frame.theme.beamColor, frame.reveal);
    final start = Offset(ax, ay);
    final end = Offset(bx, by);

    final glow = frame.theme.resolvedGlow;
    if (glow > 0) {
      final sigma = ScanGlow.sigmaFor(math.max(glow, 0.4), width);

      // Wide wash: what makes the laser feel like it lights the frame up.
      cache.applyGlowBlur(sigma * 2.1);
      cache.glow
        ..color = ScanFxPalette.withAlpha(color, color.a * 0.42)
        ..strokeWidth = width * 5;
      canvas.drawLine(start, end, cache.glow);

      // Inner bloom around the core.
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 2;
      canvas.drawLine(start, end, cache.glow);
    }

    cache.stroke
      ..color = ScanFxPalette.fade(frame.theme.beamAccentColor, frame.reveal)
      ..strokeWidth = width;
    canvas.drawLine(start, end, cache.stroke);
  }
}
