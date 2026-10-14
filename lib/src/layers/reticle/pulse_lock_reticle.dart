import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import 'scan_reticle_layer.dart';

/// No focus flourish: the confirmation ring is the whole lock-on.
///
/// The frame geometry still springs onto the target — that is the director's
/// job, not the reticle's — so this style is not "no animation". It simply
/// declines to add a flourish on top, which keeps the lock-on to a single,
/// unambiguous gesture. Pair it with a strong [ScanLockOptions.pulseStrength].
///
/// It reports [animated] as `false`: the ring is driven by the director's timed
/// value, so this layer contributes nothing between locks.
class PulseLockReticle extends ScanReticleLayer {
  /// Creates the style.
  PulseLockReticle();

  @override
  bool get animated => false;

  @override
  void paintFocus(Canvas canvas, Size size, ScanFxFrame frame) {}
}
