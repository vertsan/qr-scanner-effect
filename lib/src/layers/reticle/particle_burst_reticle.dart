import 'dart:ui' show Canvas, Offset, Size;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../paint/scan_glow.dart';
import 'scan_reticle_layer.dart';

/// Particles that fly in towards the corners and vanish on arrival.
///
/// Each corner receives the same fan of particles, so the gesture is symmetric
/// on a rotated or perspective-skewed target. The directions are a fixed table
/// and every particle is placed by interpolating two doubles, so a frame of the
/// flight allocates nothing beyond the [Offset]s the draw calls require.
class ParticleBurstReticle extends ScanReticleLayer {
  /// Creates the style.
  ParticleBurstReticle();

  /// How far outside the corner each particle starts, as a fraction of the
  /// quad's shortest side.
  static const double spread = 0.22;

  /// Peak opacity of each particle at full intensity.
  static const double peak = 0.85;

  static const List<double> _dx = <double>[
    1,
    0.707,
    0,
    -0.707,
    -1,
    -0.707,
    0,
    0.707,
  ];
  static const List<double> _dy = <double>[
    0,
    0.707,
    1,
    0.707,
    0,
    -0.707,
    -1,
    -0.707,
  ];

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.hasTarget) return;

    final progress = frame.focus.clamp(0.0, 1.0);
    final alpha = focusEnvelope(progress, rise: 0.14, fall: 0.22) *
        peak *
        frame.intensity;
    if (alpha <= 0.004) return;

    final quad = frame.quad;
    final reach = quad.shortestSide * spread;
    final eased = progress * progress;
    final radius = (frame.theme.cornerStrokeWidth * 0.34).clamp(0.8, 6.0);

    for (var corner = 0; corner < 4; corner++) {
      final origin = ScanFxShapes.quadCorner(quad, corner);
      for (var i = 0; i < _dx.length; i++) {
        final startX = origin.dx + _dx[i] * reach;
        final startY = origin.dy + _dy[i] * reach;
        final x = startX + (origin.dx - startX) * eased;
        final y = startY + (origin.dy - startY) * eased;
        ScanGlow.circle(
          canvas,
          Offset(x, y),
          radius,
          reticleColor(frame, alpha),
          0,
          cache,
        );
      }
    }
  }
}
