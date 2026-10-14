import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// A crisp sweep line with a short trail of ghosts behind the head.
///
/// The ghosts are the same rail re-computed at slightly earlier positions, which
/// costs four `computeRail` calls and no allocation. The trail therefore follows
/// the code's rotation for free.
class LineBeam extends ScanBeamLayer {
  /// Creates the style.
  const LineBeam();

  static const int _ghosts = 4;

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final width = frame.beamThickness;
    final color = ScanFxPalette.fade(frame.theme.beamColor, frame.reveal);
    final accent = ScanFxPalette.fade(frame.theme.beamAccentColor, frame.reveal);
    final trail = frame.theme.beam.trail.clamp(0.0, 1.0);
    final sigma = ScanGlow.sigmaFor(frame.glow * 0.5, width);

    for (var i = _ghosts; i >= 1; i--) {
      final ghost = t - trail * 0.22 * (i / _ghosts);
      if (ghost < 0) continue;
      computeRail(frame, local, ghost);
      cache.stroke
        ..color = ScanFxPalette.fade(color, (1 - i / (_ghosts + 1)) * 0.2)
        ..strokeWidth = width;
      canvas.drawLine(Offset(ax, ay), Offset(bx, by), cache.stroke);
    }

    computeRail(frame, local, t);
    final start = Offset(ax, ay);
    final end = Offset(bx, by);

    if (sigma > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 1.8;
      canvas.drawLine(start, end, cache.glow);
    }

    cache.stroke
      ..color = accent
      ..strokeWidth = width;
    canvas.drawLine(start, end, cache.stroke);
  }
}
