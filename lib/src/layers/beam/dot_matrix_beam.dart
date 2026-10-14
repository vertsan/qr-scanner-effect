import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import 'scan_beam_layer.dart';

/// A lattice of dots lit by the passing head.
///
/// Dots closer to the head are brighter and larger, so the beam reads as a wave
/// of energy moving through the grid. Nothing is blurred per dot — bloom on
/// twenty-five small circles would dominate the frame cost — so this is the
/// cheapest of the decorative beams.
class DotMatrixBeam extends ScanBeamLayer {
  /// Creates the style.
  DotMatrixBeam();

  /// Dots per axis.
  static const int cells = 5;

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final travelIsY = bandVertical;
    final head = travelIsY ? headY : headX;
    final trail = bandLength <= 1
        ? math.max(local.width, local.height) * 0.16
        : bandLength;
    if (trail <= 0) return;

    final color = frame.theme.beamColor;
    final accent = frame.theme.beamAccentColor;
    final radius =
        math.max(1.0, math.min(local.width, local.height) / (cells * 6));
    final reveal = frame.reveal;
    final intensity = frame.intensity;
    final reach = math.max(trail, 1.0);

    for (var iy = 0; iy < cells; iy++) {
      for (var ix = 0; ix < cells; ix++) {
        final x = local.left + local.width * (ix + 0.5) / cells;
        final y = local.top + local.height * (iy + 0.5) / cells;
        final close =
            (1 - ((travelIsY ? y : x) - head).abs() / reach).clamp(0.0, 1.0);
        final alpha = (0.08 + 0.8 * close * close) * intensity * reveal;
        if (alpha <= 0.002) continue;
        cache.fill.color = ScanFxPalette.withAlpha(
          close > 0.6 ? accent : color,
          alpha,
        );
        canvas.drawCircle(
          Offset(x, y),
          radius * (0.55 + 0.6 * close),
          cache.fill,
        );
      }
    }
  }
}
