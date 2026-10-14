import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import '../paint/scan_glow.dart';
import 'scan_reticle_layer.dart';

/// A lock-on that scales up into place: the frame's echo starts slightly smaller
/// than the target and grows onto it, overshooting a touch on the way.
///
/// This is the `zoomIn` flourish. It reads [ScanFxFrame.focusRaw] rather than
/// [ScanFxFrame.focus] so the spring's overshoot *is* the style: the echo grows
/// past the target and settles back, which is the whole point of pairing this
/// flourish with the overshooting lock spring.
class ZoomReticle extends ScanReticleLayer {
  /// Creates the style.
  ZoomReticle();

  /// How much smaller than the target the echo starts.
  static const double startScale = 0.9;

  /// Peak opacity of the echo at full intensity.
  static const double peak = 0.45;

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.hasTarget) return;

    final progress = frame.focusRaw.clamp(0.0, 1.5);
    final alpha =
        focusEnvelope(progress, rise: 0.22, fall: 0.4) * peak * frame.intensity;
    if (alpha <= 0.004) return;

    final scale = startScale + (1 - startScale) * progress;
    final width = frame.theme.cornerStrokeWidth * (1.6 - 0.6 * progress);
    ScanGlow.strokePath(
      canvas,
      paths.roundedQuad(
        frame,
        radius: frame.cornerRadius * scale,
        scale: scale,
      ),
      reticleColor(frame, alpha),
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      cache,
    );
  }
}
