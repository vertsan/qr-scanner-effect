import 'dart:math' as math;
import 'dart:ui' show Canvas, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// Two soft pulses towards the fault colour.
///
/// The pulse count comes from [ScanErrorOptions.pulseCount], and the envelope is
/// multiplied by `1 - burst` so the final pulse always lands back at rest
/// instead of being cut off mid-flash.
class RedPulseEffect extends ScanEffectLayer {
  /// Creates the style.
  RedPulseEffect();

  /// Peak opacity of the rim at full intensity.
  static const double _peak = 0.85;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = faultBurst(frame);
    if (burst < 0) return;

    final pulses = frame.theme.error.pulseCount;
    if (pulses <= 0) return;

    final strength = frame.reduceMotion
        ? steadyState(frame, 0.5)
        : math.sin(math.pi * ((burst * pulses) % 1)) *
            (1 - burst) *
            _peak *
            frame.intensity;
    if (strength <= 0.002) return;

    final color = ScanFxPalette.fade(
      frame.stateColor,
      strength * frame.reveal,
    );
    final path = paths.outline(frame);
    final width = frame.theme.frameStrokeWidth * (2 + 2.5 * strength);

    ScanGlow.strokePath(
      canvas,
      path,
      color,
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      cache,
    );

    // A faint inner wash stops the pulse reading as a bare outline.
    cache.fill
      ..color = ScanFxPalette.withAlpha(frame.stateColor, strength * 0.12)
      ..maskFilter = null;
    canvas.drawPath(path, cache.fill);
  }
}
