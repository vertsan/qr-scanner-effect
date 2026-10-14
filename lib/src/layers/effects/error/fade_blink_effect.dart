import 'dart:math' as math;
import 'dart:ui' show Canvas, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// A gentle alpha blink in the fault colour.
///
/// The most restrained fault style, and the one banking mode uses: the frame
/// itself never moves, the overlay simply blinks twice and settles. It is also
/// the safest choice for hosts whose scan area sits over important UI.
class FadeBlinkEffect extends ScanFaultEffect {
  /// Creates the style.
  FadeBlinkEffect();

  /// How many blinks play across the burst.
  static const int _blinks = 2;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = faultBurst(frame);
    if (burst < 0) return;

    final strength = frame.reduceMotion
        ? steadyState(frame, 0.45)
        : math.sin(math.pi * ((burst * _blinks) % 1)).abs() *
            (1 - burst) *
            frame.intensity;
    if (strength <= 0.002) return;

    final path = paths.outline(frame);
    final color = ScanFxPalette.fade(
      frame.stateColor,
      strength * frame.reveal,
    );

    cache.fill
      ..color = ScanFxPalette.withAlpha(frame.stateColor, strength * 0.14)
      ..maskFilter = null;
    canvas.drawPath(path, cache.fill);

    ScanGlow.strokePath(
      canvas,
      path,
      color,
      frame.theme.frameStrokeWidth * 1.4,
      ScanGlow.sigmaFor(frame.glow, frame.theme.frameStrokeWidth),
      cache,
    );
  }
}
