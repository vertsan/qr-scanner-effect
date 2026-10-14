import 'dart:ui' show Canvas, Color, Size;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show protected;

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_style.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import '../paint/scan_paint_cache.dart';
import '../paint/scan_path_cache.dart';
import '../scan_layer.dart';

/// Shared behaviour for the lock-on flourish family.
///
/// A lock style answers one question — "what does settling onto the target look
/// like?" — and the styles differ only in the shape they draw while the focus
/// spring is in flight. Everything that is true of all of them lives here:
///
/// * the reveal fade and the state tint, via [reticleColor];
/// * a cached [ScanPaintCache] and [ScanQuadPathCache];
/// * the **lock pulse**, the single ring the director fires once the spring has
///   settled.
///
/// Keeping the pulse here is what lets [ScanLockStyle] stay about the *focus*
/// look. The confirmation ring is identical everywhere and is dialled off in one
/// place, through [ScanLockOptions.pulseStrength], instead of being reimplemented
/// (and re-forgotten) per style.
///
/// Subclasses implement [paintFocus] and get the pulse for free.
abstract class ScanReticleLayer extends ScanLayer {
  /// Creates the base.
  ScanReticleLayer();

  @override
  ScanLayerKind get kind => ScanLayerKind.reticle;

  /// Paint objects shared by this layer's draws.
  @protected
  late final ScanPaintCache cache = ScanPaintCache();

  /// Outline cache shared by this layer's draws.
  @protected
  late final ScanQuadPathCache paths = ScanQuadPathCache();

  /// How far the pulse ring travels past the frame, as a fraction of its size.
  static const double pulseExpansion = 0.30;

  /// The colour a flourish uses, faded by [alpha] and the overlay reveal.
  @protected
  Color reticleColor(ScanFxFrame frame, double alpha) =>
      ScanFxPalette.fade(frame.stateColor, alpha * frame.reveal);

  /// A bell envelope over a `0..1` [progress]: `0` at both ends and `1` through
  /// the middle, with the two ramps sized by [rise] and [fall].
  ///
  /// Every focus flourish has the same problem — it must appear without popping
  /// and vanish once it has landed — so the shape of that fade lives here once.
  /// A short [fall] holds the flourish at full strength almost to the corners,
  /// which is what makes a landing read as a landing rather than as a cross-fade.
  @protected
  double focusEnvelope(
    double progress, {
    double rise = 0.2,
    double fall = 0.3,
  }) {
    final up = (progress / rise).clamp(0.0, 1.0);
    final down = ((1 - progress) / fall).clamp(0.0, 1.0);
    return up * down;
  }

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    paintFocus(canvas, size, frame);
    paintPulse(canvas, size, frame);
  }

  /// Draws this style's focus flourish. Runs before the pulse, so the pulse
  /// always reads as the topmost confirmation.
  @protected
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame);

  /// Draws the one-shot lock pulse, when the frame has one live.
  ///
  /// The pulse is a `0..1` timed value rather than a spring precisely so it
  /// lands on `1` and stops: the early return below is the entire steady-state
  /// cost once the ring has faded.
  @protected
  void paintPulse(Canvas canvas, Size size, ScanFxFrame frame) {
    final strength = frame.theme.lock.pulseStrength;
    final pulse = frame.pulse;
    if (strength <= 0 || pulse <= 0.001 || pulse >= 1) return;

    final eased = Curves.easeOutQuart.transform(pulse);
    final alpha = (1 - eased) * strength;
    if (alpha <= 0.004) return;

    final scale = 1 + pulseExpansion * eased;
    final width = frame.theme.frameStrokeWidth + 3 * (1 - eased);
    ScanGlow.strokePath(
      canvas,
      paths.roundedQuad(
        frame,
        radius: frame.cornerRadius * scale,
        scale: scale,
      ),
      reticleColor(frame, alpha),
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      cache,
    );
  }
}
