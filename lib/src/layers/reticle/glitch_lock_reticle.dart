import 'dart:ui' show Canvas, Offset, Size;

import '../../animation/scan_fx_frame.dart';
import '../paint/scan_glow.dart';
import 'scan_reticle_layer.dart';

/// A glitched echo of the frame that snaps into place.
///
/// Two offset copies of the outline are drawn in the state colour and stepped
/// through a fixed jump table as the lock settles, with the displacement
/// shrinking to zero on arrival so the last frames are a clean landing. It is
/// the loudest flourish, and the natural partner for
/// [ScanLockStyle.glitchLock]'s bouncy spring.
class GlitchLockReticle extends ScanReticleLayer {
  /// Creates the style.
  GlitchLockReticle();

  /// How many positions the jumps are stepped through.
  static const int steps = 8;

  /// Peak displacement, as a fraction of the quad's shortest side.
  static const double amplitude = 0.07;

  /// Peak opacity of the echoes at full intensity.
  static const double peak = 0.8;

  static const List<Offset> _jumps = <Offset>[
    Offset(1, 0),
    Offset(0.4, -0.3),
    Offset(-0.7, 0.2),
    Offset(0, 1),
    Offset(0.6, 0.6),
    Offset(-1, 0),
    Offset(0.3, -0.8),
    Offset(0, -0.5),
  ];

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.hasTarget) return;

    final settle = frame.focusRaw.clamp(0.0, 1.6);
    final alpha =
        focusEnvelope(settle, rise: 0.12, fall: 0.22) * peak * frame.intensity;
    if (alpha <= 0.004) return;

    final landed = settle.clamp(0.0, 1.0);
    final magnitude = (1 - landed) * amplitude * frame.quad.shortestSide;
    if (magnitude <= 0.1) return;

    final step = (settle * steps).floor() % _jumps.length;
    final jump = _jumps[step];
    final width = frame.theme.frameStrokeWidth;
    final sigma = ScanGlow.sigmaFor(frame.glow, width);
    final outline = paths.outline(frame);

    canvas.save();
    canvas.translate(jump.dx * magnitude, jump.dy * magnitude);
    ScanGlow.strokePath(
      canvas,
      outline,
      reticleColor(frame, alpha * 0.7),
      width,
      sigma,
      cache,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(-jump.dy * magnitude * 0.6, jump.dx * magnitude * 0.6);
    ScanGlow.strokePath(
      canvas,
      outline,
      reticleColor(frame, alpha * 0.45),
      width * 0.8,
      sigma,
      cache,
    );
    canvas.restore();
  }
}
