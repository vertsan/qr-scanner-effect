import 'dart:ui' show Canvas, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// A bloom pulse that flashes outwards from the locked frame.
///
/// The widest success style. The stroke widens as the bloom decays, so the light
/// appears to spread and dissipate rather than simply fade.
class GlowFlashEffect extends ScanEffectLayer {
  /// Creates the style.
  GlowFlashEffect();

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = successBurst(frame);
    if (burst < 0) return;

    final strength = frame.reduceMotion
        ? steadyState(frame, 0.55)
        : envelope(burst, attack: 0.18) * frame.intensity;
    if (strength <= 0.002) return;

    final width = frame.theme.frameStrokeWidth * (1 + 2.6 * strength);
    final color = ScanFxPalette.fade(
      frame.theme.successColor,
      strength * frame.reveal,
    );
    ScanGlow.strokePath(
      canvas,
      paths.outline(frame),
      color,
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      cache,
    );
  }
}
