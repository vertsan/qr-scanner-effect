import 'dart:ui' show Canvas, Path, Size;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../paint/scan_glow.dart';
import 'scan_reticle_layer.dart';

/// The signature "AI focus" lock-on: four brackets that fly in from outside the
/// scan area and land on the detected code.
///
/// This is the effect the package is named for, and it is deliberately
/// *transient*. The brackets are not extra chrome stacked on the corner layer:
/// they are the focus animation itself. They fade in as the spring leaves the
/// default area, travel inwards, and dissolve exactly where the corner layer's
/// brackets already sit — so the two bracket families are never on screen as
/// separate things, and the hand-off is invisible.
///
/// **Geometry.** The brackets are placed from [ScanFxFrame.quad], which the
/// director already morphs from the default scan area onto the target, so
/// rotation, perspective and scale all come for free — no per-style code. The
/// travel is driven by [ScanFxFrame.focusRaw] rather than [ScanFxFrame.focus],
/// so the lock spring's overshoot is visible in the geometry, and the arm length
/// and stroke width converge on the corner layer's values so the final frame of
/// the animation lands pixel-on-pixel on top of what replaces it.
class FocusBracketReticle extends ScanReticleLayer {
  /// Creates the style.
  FocusBracketReticle();

  /// How far outside the scan area the brackets start, as a fraction of the
  /// quad's shortest side.
  static const double startSpread = 0.16;

  /// How much longer the arms are while the brackets are still travelling.
  static const double armTravel = 0.8;

  Path? _path;
  ScanFxQuad? _pathQuad;
  double _pathArm = -1;
  double _pathInset = double.nan;

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.hasTarget) return;

    // `0` while leaving the default area, `1` when landed. Left unclamped above
    // `1` so the spring's overshoot shows in the geometry.
    final settle = frame.focusRaw.clamp(0.0, 1.6);

    // Fade in over the first fifth of the travel, then hold all the way to the
    // corners and dissolve in the last stretch. Holding full opacity until the
    // brackets are nearly on the corners is what makes the hand-off to the
    // corner layer read as a landing rather than as a cross-fade.
    final alpha =
        focusEnvelope(settle, rise: 0.2, fall: 0.14) * frame.intensity;
    if (alpha <= 0.004) return;

    final landed = settle.clamp(0.0, 1.0);
    final side = frame.quad.shortestSide;
    final arm =
        side * frame.theme.cornerArmFraction * (1 + armTravel * (1 - landed));
    final inset = -(1 - settle) * startSpread * side;

    final path = _bracketPath(frame.quad, arm, inset);
    final width = frame.theme.cornerStrokeWidth * (0.7 + 0.3 * landed);
    ScanGlow.strokePath(
      canvas,
      path,
      reticleColor(frame, alpha),
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      cache,
    );
  }

  /// The four travelling brackets, rebuilt in place only when the geometry
  /// actually changed.
  Path _bracketPath(ScanFxQuad quad, double arm, double inset) {
    if (_path != null &&
        _pathQuad == quad &&
        _pathArm == arm &&
        _pathInset == inset) {
      return _path!;
    }
    final path = _path ??= Path();
    path.reset();
    ScanFxShapes.addQuadCornerArms(path, quad, inset, arm);
    _pathQuad = quad;
    _pathArm = arm;
    _pathInset = inset;
    return path;
  }
}
