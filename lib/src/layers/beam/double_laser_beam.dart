import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// Two parallel laser lines with a bright core between them.
///
/// The pair reads as a scanner gate rather than a single sweep, which makes the
/// covered area obvious at a glance. The lines are offset perpendicular to the
/// rail, so they stay parallel on a rotated or perspective-skewed code.
class DoubleLaserBeam extends ScanBeamLayer {
  /// Creates the style.
  DoubleLaserBeam();

  /// Offset of each line from the rail, as a multiple of the beam thickness.
  static const double separation = 1.9;

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final width = frame.beamThickness;
    final color = ScanFxPalette.fade(frame.theme.beamColor, frame.reveal);
    final accent =
        ScanFxPalette.fade(frame.theme.beamAccentColor, frame.reveal);
    final dx = bx - ax;
    final dy = by - ay;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 0.5) return;

    final nx = -dy / length;
    final ny = dx / length;
    final gap = width * separation;
    final sigma = ScanGlow.sigmaFor(math.max(frame.glow, 0.3), width);

    for (var i = -1; i <= 1; i += 2) {
      final ox = nx * gap * i;
      final oy = ny * gap * i;
      ScanGlow.line(
        canvas,
        Offset(ax + ox, ay + oy),
        Offset(bx + ox, by + oy),
        color,
        width,
        sigma,
        cache,
      );
    }

    // The lit core between the two lines, so the gap does not read as a seam.
    ScanGlow.line(
      canvas,
      Offset(ax, ay),
      Offset(bx, by),
      accent,
      width * 0.45,
      ScanGlow.sigmaFor(frame.glow * 0.6, width),
      cache,
    );
  }
}
