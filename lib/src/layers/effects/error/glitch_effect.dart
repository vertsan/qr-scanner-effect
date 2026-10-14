import 'dart:ui' show Canvas, Offset, Path, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../state/scan_fx_state.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../../paint/scan_glow.dart';
import '../scan_effect_layer.dart';

/// A digital glitch: a few stepped, displaced copies of the frame flash in the
/// fault colour.
///
/// The displacement table is fixed and stepped rather than continuous. A smooth
/// slide reads as an animation; a handful of held jumps reads as a *fault*,
/// which is the whole point of this style — it is the loudest thing the package
/// draws, and it exists so hosts who want an unmistakable failure have one.
///
/// ### `invalid` is not an error
///
/// An unreadable or unrecognised code is not a system failure, so this style
/// deliberately degrades on [ScanFxState.invalid]: the stepped jumps are dropped
/// and the code gets one soft tint instead. Geometry is never displaced for an
/// invalid read. The same reasoning applies under reduce-motion, where the
/// effect holds a steady tint rather than jumping at all.
class GlitchEffect extends ScanFaultEffect {
  /// Creates the style.
  GlitchEffect();

  /// The displacement table, in logical pixels at the default
  /// [ScanErrorOptions.shakeAmplitude] of `10`. Other amplitudes scale it.
  static const List<Offset> _jumps = <Offset>[
    Offset(6, 0),
    Offset(0, -3),
    Offset(-4, 0),
    Offset(0, 4),
    Offset(3, 2),
  ];

  /// How many held jumps play across the burst.
  static const int _steps = 12;

  /// Peak opacity of the displaced frame at full intensity.
  static const double _peak = 0.8;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = faultBurst(frame);
    if (burst < 0) return;

    final path = paths.outline(frame);
    final width = frame.theme.frameStrokeWidth * 1.6;

    if (frame.reduceMotion) {
      final alpha = steadyState(frame, _peak * 0.55) * frame.reveal;
      if (alpha <= 0.004) return;
      _displaced(
        canvas,
        path,
        Offset.zero,
        alpha,
        width,
        frame,
      );
      return;
    }

    final strength = envelope(burst, attack: 0.12) * frame.intensity;
    if (strength <= 0.004) return;

    if (frame.state == ScanFxState.invalid) {
      // No displacement: an invalid read gets a single soft tint in place.
      _displaced(
          canvas, path, Offset.zero, strength * frame.reveal, width, frame);
      return;
    }

    // Two short dropout windows, so the fault stutters instead of pulsing.
    if ((burst > 0.16 && burst < 0.22) || (burst > 0.44 && burst < 0.5)) return;

    final scale = frame.theme.error.shakeAmplitude / 10;
    final jump = _jumps[(burst * _steps).floor() % _jumps.length];
    final offset = Offset(jump.dx * scale, jump.dy * scale);
    _displaced(
      canvas,
      path,
      offset,
      strength * frame.reveal,
      width,
      frame,
    );
  }

  /// Paints the tinted fill and outline for one displaced copy.
  void _displaced(
    Canvas canvas,
    Path path,
    Offset offset,
    double strength,
    double width,
    ScanFxFrame frame,
  ) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    cache.fill
      ..color = ScanFxPalette.withAlpha(frame.stateColor, strength * 0.1)
      ..maskFilter = null;
    canvas.drawPath(path, cache.fill);

    ScanGlow.strokePath(
      canvas,
      path,
      ScanFxPalette.fade(frame.stateColor, strength),
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      cache,
    );
    canvas.restore();
  }
}
