import 'dart:math' as math;
import 'dart:ui' show Canvas, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// The rim flare that plays with [ScanErrorStyle.shake].
///
/// The director applies the shake to the quad, so this layer deliberately
/// counter-translates by the same offset: the flare stays put while the frame
/// rattles through it, which reads as an impact rather than as two things
/// shaking at once.
///
/// On an [ScanFxState.invalid] code the geometry never shakes (an unreadable
/// code rattling the screen would be a lie), so this degrades to a single soft
/// flare in the invalid colour.
class ShakeErrorEffect extends ScanEffectLayer {
  /// Creates the style.
  const ShakeErrorEffect();

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = faultBurst(frame);
    if (burst < 0) return;

    final strength = frame.reduceMotion
        ? steadyState(frame, 0.5)
        : math.exp(-3.0 * burst) * (1 - burst) * frame.intensity;
    if (strength <= 0.002) return;

    final width = frame.theme.frameStrokeWidth + 6 * strength;
    final color = ScanFxPalette.fade(
      frame.stateColor,
      strength * frame.reveal,
    );
    final sigma = ScanGlow.sigmaFor(frame.glow, width);

    canvas.save();
    canvas.translate(-frame.shake.dx, -frame.shake.dy);
    ScanGlow.strokePath(
      canvas,
      paths.outline(frame),
      color,
      width,
      sigma,
      cache,
    );
    canvas.restore();
  }
}
