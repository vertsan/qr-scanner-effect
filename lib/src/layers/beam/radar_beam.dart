import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// A rotating sweep with a trailing wake, from the centre outwards.
///
/// Designed for [ScanBeamDirection.radial] and [ScanFrameShape.circle], where it
/// reads as a radar sweep. The wake is drawn as a fan of translucent spokes
/// rather than a swept gradient, which keeps it shader-free and allocation-free.
class RadarBeam extends ScanBeamLayer {
  /// Creates the style.
  RadarBeam();

  /// How many segments the wake is divided into.
  static const int spokes = 10;

  /// How far behind the leading edge the wake reaches, in radians.
  static const double wake = 1.2;

  final Path _spoke = Path();

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final radius = math.min(local.width, local.height) * 0.5;
    if (radius <= 1) return;

    final angle = math.atan2(headY, headX);
    final color = frame.theme.beamColor;
    final reveal = frame.reveal;

    final intensity = frame.intensity;

    for (var i = 0; i < spokes; i++) {
      final alpha = (1 - i / spokes) * 0.2 * intensity * reveal;
      if (alpha <= 0.002) continue;
      final a0 = angle - wake * (i + 1) / spokes;
      final a1 = angle - wake * i / spokes;
      _spoke.reset();
      _spoke.moveTo(0, 0);
      _spoke.lineTo(math.cos(a0) * radius, math.sin(a0) * radius);
      _spoke.lineTo(math.cos(a1) * radius, math.sin(a1) * radius);
      _spoke.close();
      cache.fill.color = ScanFxPalette.withAlpha(color, alpha);
      canvas.drawPath(_spoke, cache.fill);
    }

    final end = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    final core = frame.beamThickness;
    if (cache
        .applyGlowBlur(ScanGlow.sigmaFor(math.max(frame.glow, 0.35), core))) {
      cache.glow
        ..color = color
        ..strokeWidth = core * 1.4;
      canvas.drawLine(Offset.zero, end, cache.glow);
    }
    cache.stroke
      ..color = color
      ..strokeWidth = core;
    canvas.drawLine(Offset.zero, end, cache.stroke);
  }
}
