import 'dart:math' as math;
import 'dart:ui' show Canvas, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../scan_effect_layer.dart';

/// A tint that washes across the frame and fades back out.
///
/// The calmest success style, and the one banking mode uses: no confetti, no
/// particles, just the frame acknowledging the read.
class ColorWashEffect extends ScanEffectLayer {
  /// Creates the style.
  ColorWashEffect();

  /// Peak opacity of the wash at full intensity.
  static const double _peak = 0.32;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = successBurst(frame);
    if (burst < 0) return;

    final alpha = (frame.reduceMotion
            ? steadyState(frame, _peak)
            : math.sin(math.pi * burst) * _peak * frame.intensity) *
        frame.reveal;
    if (alpha <= 0.002) return;

    cache.fill
      ..color = ScanFxPalette.withAlpha(frame.stateColor, alpha)
      ..maskFilter = null;
    canvas.drawPath(paths.outline(frame), cache.fill);
  }
}
