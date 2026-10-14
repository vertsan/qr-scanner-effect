import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import '../paint/scan_glow.dart';
import 'scan_reticle_layer.dart';

/// A ring that starts wide and contracts onto the frame.
///
/// The opposite gesture to [ZoomReticle]: instead of an echo growing into place,
/// a halo closes in and disappears exactly where the frame has landed. It reads
/// as a target being *acquired*, which suits security and verification themes.
class RingContractReticle extends ScanReticleLayer {
  /// Creates the style.
  RingContractReticle();

  /// How much larger than the target the ring starts.
  static const double startScale = 1.3;

  /// Peak opacity of the ring at full intensity.
  static const double peak = 0.5;

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.hasTarget) return;

    final progress = frame.focus.clamp(0.0, 1.0);
    final alpha = focusEnvelope(progress, rise: 0.12, fall: 0.26) *
        peak *
        frame.intensity;
    if (alpha <= 0.004) return;

    final scale = startScale - (startScale - 1) * progress;
    final width = frame.theme.frameStrokeWidth + 2 * (1 - progress);
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
