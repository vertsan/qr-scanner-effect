import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// A soft bar with a gradient trail that fades out behind the head.
///
/// The gradient shader is built in the beam's own local space and positioned by
/// the canvas transform, so it depends only on the band *length* and direction —
/// both of which change a handful of times per animation. A full sweep therefore
/// reuses one shader instead of building one per frame.
class SoftGradientBarBeam extends ScanBeamLayer {
  /// Creates the style.
  SoftGradientBarBeam();

  Shader? _shader;
  int _shaderKey = -1;

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final width = frame.beamThickness;
    final color = ScanFxPalette.fade(frame.theme.beamColor, frame.reveal);
    final accent =
        ScanFxPalette.fade(frame.theme.beamAccentColor, frame.reveal);
    final sigma = ScanGlow.sigmaFor(frame.glow * 0.7, width);

    if (hasBand) {
      _paintBand(canvas, local, frame, color, sigma);
    }

    final start = Offset(ax, ay);
    final end = Offset(bx, by);
    if (sigma > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 2;
      canvas.drawLine(start, end, cache.glow);
    }
    cache.stroke
      ..color = accent
      ..strokeWidth = width;
    canvas.drawLine(start, end, cache.stroke);
  }

  void _paintBand(
    Canvas canvas,
    Rect local,
    ScanFxFrame frame,
    Color color,
    double sigma,
  ) {
    if (bandLength <= 1) return;
    final travel = bandSign * bandLength;

    final key = Object.hash(bandVertical, bandSign, (bandLength * 2).round());
    if (_shader == null || _shaderKey != key) {
      _shaderKey = key;
      _shader = Gradient.linear(
        Offset.zero,
        bandVertical ? Offset(0, travel) : Offset(travel, 0),
        <Color>[color, ScanFxPalette.withAlpha(color, 0)],
        const <double>[0, 1],
      );
    }

    final clearEdge = math.min(0.0, travel);
    final solidEdge = math.max(0.0, travel);
    final band = bandVertical
        ? Rect.fromLTRB(-local.width / 2, clearEdge, local.width / 2, solidEdge)
        : Rect.fromLTRB(
            clearEdge, -local.height / 2, solidEdge, local.height / 2);

    canvas.save();
    canvas.translate(headX, headY);
    cache.scratch
      ..shader = _shader
      ..color = const Color(0xFFFFFFFF)
      ..maskFilter = cache.fillFilter(sigma * 0.5);
    canvas.drawRect(band, cache.scratch);
    cache.scratch
      ..shader = null
      ..maskFilter = null;
    canvas.restore();
  }
}
