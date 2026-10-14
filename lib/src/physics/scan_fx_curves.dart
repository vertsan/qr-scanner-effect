import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve;

/// The curve vocabulary used by the motion spec.
///
/// Flutter already ships `easeOutCubic`, `easeOutQuint`, `easeOutExpo`,
/// `easeOutCirc`, `easeOutBack` and friends, so this file only defines the few
/// shapes the overlay needs that have no built-in equivalent.
abstract final class ScanFxCurves {
  /// Hermite fade with zero first derivative at both ends.
  static const Curve smoothstep = _SmoothstepCurve();

  /// Overshoots the target by [amount] then settles, for soft "pop" motion.
  static const Curve overshootSoft = _OvershootCurve(0.06);

  /// A stronger pop, used by `lock.zoomIn`.
  static const Curve overshootStrong = _OvershootCurve(0.12);

  /// Pulls back slightly before moving forward, then overshoots.
  static const Curve anticipateOvershoot = _AnticipateOvershootCurve(0.07);
}

/// A damped sine, used for the error shake and the glitch jitter.
///
/// [t] is normalized `0..1` across the whole effect. [cycles] is how many
/// oscillations happen over that span and [decay] controls how fast the
/// envelope collapses (higher decays faster).
double scanFxDampedSine(
  double t, {
  double cycles = 5.9,
  double decay = 3.5,
}) {
  if (t <= 0) return 0;
  if (t >= 1) return 0;
  return math.exp(-decay * t) * math.sin(2 * math.pi * cycles * t);
}

class _SmoothstepCurve extends Curve {
  const _SmoothstepCurve();

  @override
  double transformInternal(double t) => t * t * (3 - 2 * t);
}

class _OvershootCurve extends Curve {
  const _OvershootCurve(this.amount);

  final double amount;

  @override
  double transformInternal(double t) {
    // A single cubic that rises past 1 and returns, with no undershoot.
    return math.sin(t * math.pi * 0.5) * (1 + amount) - amount * t;
  }
}

class _AnticipateOvershootCurve extends Curve {
  const _AnticipateOvershootCurve(this.amount);

  final double amount;

  @override
  double transformInternal(double t) {
    final eased = t * t * (3 - 2 * t);
    final wobble = math.sin(t * math.pi * 2) * amount * (1 - t);
    return eased - wobble + wobble * t;
  }
}
