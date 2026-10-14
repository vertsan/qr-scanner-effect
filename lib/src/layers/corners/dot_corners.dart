import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_corner_layer.dart';

/// A filled dot at each corner.
///
/// The calmest bracket style and the natural partner for
/// [ScanLockStyle.smoothMorph] and [ScanFrameShape.circle]: the dots sit still
/// on the frame and inherit the same convergence and glow as the arms.
class DotCorners extends ScanCornerLayer {
  /// Creates the style.
  DotCorners();

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final color = ScanFxPalette.fade(colorFor(frame), frame.reveal);
    if (color.a <= 0.004) return;

    final quad = frame.quad;
    final inset = insetFor(frame);
    final radius = frame.theme.cornerStrokeWidth * 0.9;
    final sigma = ScanGlow.sigmaFor(frame.glow, radius * 2);
    for (var i = 0; i < 4; i++) {
      ScanGlow.circle(
        canvas,
        ScanCornerLayer.bracketOrigin(quad, i, inset),
        radius,
        color,
        sigma,
        cache,
      );
    }
  }
}
