import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import 'scan_beam_layer.dart';

/// A drifting curtain of soft colour bands.
///
/// The most atmospheric beam. Each band is a blurred rectangle rather than a
/// gradient, which keeps the effect shader-free and lets the blur filter be
/// cached once per frame instead of rebuilt per band.
class AuroraBeam extends ScanBeamLayer {
  /// Creates the style.
  AuroraBeam();

  /// How many bands are in flight at once.
  static const int bands = 4;

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final travelIsY = bandVertical;
    final span = travelIsY ? local.height : local.width;
    if (span <= 1) return;

    final phase = frame.reduceMotion ? 0.0 : frame.ambientSeconds * 0.12;
    final sigma = math.max(6.0, span * 0.09);
    final reveal = frame.reveal;
    final intensity = frame.intensity;
    final thickness = span * 0.22;
    final base = frame.theme.beamColor;
    final accent = frame.theme.beamAccentColor;

    cache.fill.maskFilter = cache.fillFilter(sigma);
    for (var i = 0; i < bands; i++) {
      final f = ((i / bands) + phase) % 1;
      final alpha = math.sin(math.pi * f) * 0.26 * intensity * reveal;
      if (alpha <= 0.002) continue;
      final p = (travelIsY ? local.top : local.left) + span * f;
      final rect = travelIsY
          ? Rect.fromLTRB(
              local.left, p - thickness / 2, local.right, p + thickness / 2)
          : Rect.fromLTRB(
              p - thickness / 2, local.top, p + thickness / 2, local.bottom);
      cache.fill.color = ScanFxPalette.withAlpha(
        i.isEven ? base : accent,
        alpha,
      );
      canvas.drawRect(rect, cache.fill);
    }
    cache.fill.maskFilter = null;
  }
}
