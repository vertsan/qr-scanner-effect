import 'dart:math' as math;
import 'dart:ui' show Canvas, Path, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../geometry/scan_fx_quad.dart';
import '../../../geometry/scan_fx_shapes.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// The corner brackets flash on and off.
///
/// A deliberately *redundant* effect: the corner layer already draws brackets,
/// and this brightens them in the success colour a couple of times. That is the
/// point — the read is acknowledged exactly where the eye already is, without
/// moving a single pixel of geometry, which suits hosts whose scan area sits over
/// important UI.
class CornersFlashEffect extends ScanSuccessEffect {
  /// Creates the style.
  CornersFlashEffect();

  /// How many blinks play across the burst.
  static const int blinks = 2;

  /// Peak opacity of the flash at full intensity.
  static const double peak = 0.95;

  final Path _path = Path();
  ScanFxQuad? _pathQuad;
  double _pathArm = -1;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = successBurst(frame);
    if (burst < 0) return;

    final strength = frame.reduceMotion
        ? steadyState(frame, peak * 0.6)
        : math.sin(math.pi * ((burst * blinks) % 1)).abs() *
            (1 - burst) *
            peak *
            frame.intensity;
    if (strength <= 0.004) return;

    final quad = frame.quad;
    final arm = quad.shortestSide * frame.theme.cornerArmFraction;
    if (arm <= 0.5) return;

    final path = _bracketPath(quad, arm);
    final width = frame.theme.cornerStrokeWidth * (1 + 0.5 * strength);
    final color = ScanFxPalette.fade(
      frame.theme.successColor,
      strength * frame.reveal,
    );
    final sigma = ScanGlow.sigmaFor(math.max(frame.glow, 0.35), width);

    if (sigma > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 1.6;
      canvas.drawPath(path, cache.glow);
    }
    cache.stroke
      ..color = color
      ..strokeWidth = width;
    canvas.drawPath(path, cache.stroke);
  }

  Path _bracketPath(ScanFxQuad quad, double arm) {
    if (_pathQuad == quad && _pathArm == arm) return _path;
    _path.reset();
    ScanFxShapes.addQuadCornerArms(_path, quad, 0, arm);
    _pathQuad = quad;
    _pathArm = arm;
    return _path;
  }
}
