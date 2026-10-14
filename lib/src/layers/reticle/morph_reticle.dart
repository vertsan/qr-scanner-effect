import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import '../paint/scan_glow.dart';
import 'scan_reticle_layer.dart';

/// A calm lock-on: a single soft halo that brightens as the frame morphs onto
/// the target and fades once it has landed.
///
/// This is the `smoothMorph` flourish, and the one banking mode uses. There are
/// no brackets to fly in and nothing to overshoot — the geometry morph is done
/// by the spring, so all this style has to do is acknowledge it.
///
/// The halo is drawn from [ScanQuadPathCache.outline], so a `circle` theme gets
/// a circular halo and a `squircle` theme a continuous-corner one without a line
/// of per-shape code.
class MorphReticle extends ScanReticleLayer {
  /// Creates the style.
  MorphReticle();

  /// Peak opacity of the halo at full intensity.
  static const double peak = 0.5;

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.hasTarget) return;

    // [ScanFxFrame.focus] is clamped, so a theme whose spring overshoots still
    // gets a monotonic fade here — the overshoot belongs to the bracket style.
    final alpha = focusEnvelope(frame.focus, rise: 0.3, fall: 0.35) *
        peak *
        frame.intensity;
    if (alpha <= 0.004) return;

    final width = frame.theme.cornerStrokeWidth * (1 + 0.5 * (1 - frame.focus));
    ScanGlow.strokePath(
      canvas,
      paths.outline(frame),
      reticleColor(frame, alpha),
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      cache,
    );
  }
}
