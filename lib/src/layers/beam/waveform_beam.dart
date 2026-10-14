import 'dart:math' as math;
import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import 'scan_beam_layer.dart';

/// A travelling sine wave across the scan area.
///
/// The wave rides the head and oscillates along the rail, so the beam reads as a
/// signal being read rather than a bar passing over. The polyline is rebuilt in
/// place on a cached [Path].
class WaveformBeam extends ScanBeamLayer {
  /// Creates the style.
  WaveformBeam();

  /// How many points the polyline is sampled at.
  static const int samples = 28;

  /// Wave amplitude, as a fraction of the quad's shorter side.
  static const double amplitude = 0.075;

  /// How many full waves fit across the rail.
  static const double waves = 2.4;

  final Path _wave = Path();

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {
    final travelIsY = bandVertical;
    final amp = math.min(local.width, local.height) * amplitude;
    final phase = frame.reduceMotion ? 0.0 : frame.ambientSeconds * 6;
    final start = travelIsY ? local.left : local.top;
    final span = travelIsY ? local.width : local.height;

    _wave.reset();
    for (var i = 0; i <= samples; i++) {
      final f = i / samples;
      final along = start + span * f;
      final offset = math.sin(phase + f * waves * 2 * math.pi) * amp;
      final point = travelIsY
          ? Offset(along, headY + offset)
          : Offset(headX + offset, along);
      if (i == 0) {
        _wave.moveTo(point.dx, point.dy);
      } else {
        _wave.lineTo(point.dx, point.dy);
      }
    }

    final width = frame.beamThickness;
    ScanGlow.strokePath(
      canvas,
      _wave,
      ScanFxPalette.fade(frame.theme.beamColor, frame.reveal),
      width,
      ScanGlow.sigmaFor(math.max(frame.glow, 0.3), width),
      cache,
    );
  }
}
