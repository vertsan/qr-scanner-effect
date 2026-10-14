import 'dart:ui' show Canvas, Size;

import 'package:flutter/animation.dart' show Curves;

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_style.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import '../paint/scan_paint_cache.dart';
import '../paint/scan_path_cache.dart';
import '../scan_layer.dart';

/// The lock-on ring: the flourish that confirms the spring has settled.
///
/// One ring, expanding to `1.3x` the frame and fading out. It is driven by the
/// director's `pulse` value, which is a single `0..1` timed value, so the ring
/// costs one path and two draw calls while it is live and **nothing** once
/// `pulse` reaches `1` — the early return is the whole steady-state cost.
///
/// The ring takes the same corner geometry as the frame, so it reads as the
/// frame's own echo rather than as an unrelated circle.
class LockPulseReticle extends ScanLayer {
  /// Creates the style.
  const LockPulseReticle();

  @override
  ScanLayerKind get kind => ScanLayerKind.reticle;

  late final ScanPaintCache _cache = ScanPaintCache();
  late final ScanQuadPathCache _paths = ScanQuadPathCache();

  /// How far the ring travels past the frame, as a fraction of its size.
  static const double _expansion = 0.30;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final strength = frame.theme.lock.pulseStrength;
    if (strength <= 0 || frame.pulse <= 0.001 || frame.pulse >= 1) return;

    final eased = Curves.easeOutQuart.transform(frame.pulse);
    final alpha = (1 - eased) * strength * frame.reveal;
    if (alpha <= 0.004) return;

    final scale = 1 + _expansion * eased;
    final width = frame.theme.frameStrokeWidth + 3 * (1 - eased);
    ScanGlow.strokePath(
      canvas,
      _paths.roundedQuad(
        frame,
        radius: frame.cornerRadius * scale,
        scale: scale,
      ),
      ScanFxPalette.fade(frame.stateColor, alpha),
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      _cache,
    );
  }
}
