import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// A faint grid with the line nearest the head lit up.
///
/// The grid gives the scan area a sense of scale and the travelling highlight
/// keeps the direction of travel legible. Both the lattice and the highlight are
/// recomputed in place on a cached [Path], so a sweep costs two draw calls and no
/// allocation.
class GridScanBeam extends ScanBeamLayer {
  /// Creates the style.
  GridScanBeam();

  /// Cells per axis; the lattice therefore has `divisions - 1` lines per axis.
  static const int divisions = 5;

  /// Opacity of the resting lattice at full intensity.
  static const double latticeOpacity = 0.16;

  final Path _grid = Path();

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final color = frame.theme.beamColor;
    final accent = frame.theme.beamAccentColor;
    final reveal = frame.reveal;
    final intensity = frame.intensity;
    final travelIsY = bandVertical;

    _grid.reset();
    for (var i = 1; i < divisions; i++) {
      final f = i / divisions;
      final x = local.left + local.width * f;
      final y = local.top + local.height * f;
      _grid.moveTo(x, local.top);
      _grid.lineTo(x, local.bottom);
      _grid.moveTo(local.left, y);
      _grid.lineTo(local.right, y);
    }

    final lattice =
        ScanFxPalette.withAlpha(color, latticeOpacity * intensity * reveal);
    if (lattice.a > 0.002) {
      ScanGlow.strokePath(canvas, _grid, lattice, 1, 0, cache);
    }

    // The line the head is on, lit.
    final head = travelIsY ? headY : headX;
    final start = travelIsY ? local.top : local.left;
    final span = travelIsY ? local.height : local.width;
    final index = ((head - start) / (span / divisions)).round().clamp(
          1,
          divisions - 1,
        );
    final p = start + span * index / divisions;
    final a = travelIsY ? Offset(local.left, p) : Offset(p, local.top);
    final b = travelIsY ? Offset(local.right, p) : Offset(p, local.bottom);
    final width = frame.beamThickness;
    ScanGlow.line(
      canvas,
      a,
      b,
      ScanFxPalette.fade(accent, reveal),
      width,
      ScanGlow.sigmaFor(frame.glow * 0.7, width),
      cache,
    );
  }
}
