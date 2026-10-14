import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect, Size, TextDirection;

import '../geometry/scan_fx_quad.dart';
import '../state/scan_fx_state.dart';
import '../theme/qr_scan_fx_theme.dart';
import '../theme/scan_fx_motion.dart';
import '../theme/scan_fx_style.dart';

/// An immutable snapshot of everything a layer may read while painting.
///
/// The animation director builds exactly one frame per tick and hands the *same
/// instance* to every layer, which is what keeps multiple layers perfectly in
/// sync (frame, corner brackets, beam and reticle all read [quad]).
///
/// Painters must treat this object as read-only: the director is free to stop
/// rebuilding it as soon as nothing is animating, and layers that cache derived
/// geometry should key that cache on [revision].
class ScanFxFrame {
  /// Creates a frame snapshot. Instances are produced by `ScanFxDirector`.
  const ScanFxFrame({
    required this.size,
    required this.state,
    required this.theme,
    required this.frameShape,
    required this.ambientSeconds,
    required this.focus,
    required this.focusRaw,
    required this.beamSpan,
    required this.breath,
    required this.dim,
    required this.feedback,
    required this.pulse,
    required this.hint,
    required this.reveal,
    required this.shake,
    required this.quad,
    required this.defaultQuad,
    required this.lockedQuad,
    required this.idleScale,
    required this.idleOffset,
    required this.shimmer,
    required this.reduceMotion,
    required this.textDirection,
    required this.revision,
  });

  /// The size of the overlay, in logical pixels.
  final Size size;

  /// The current lifecycle state.
  final ScanFxState state;

  /// The resolved theme, including live tunables.
  final QrScanFxTheme theme;

  /// The outline the frame layer is actually drawing.
  ///
  /// Normally this equals `theme.frameShape`, but it is resolved from the frame
  /// layer itself so that a host who replaces the frame layer with a different
  /// shape still gets a backdrop cutout (and effect outline) that matches what is
  /// on screen.
  final ScanFrameShape frameShape;

  /// Seconds of ambient time accumulated so far. Scaled by the speed
  /// multiplier, so ambient loops speed up with the rest of the motion spec.
  final double ambientSeconds;

  /// Lock-on progress clamped to `0..1`, for opacity and colour mixing where
  /// an overshoot would be wrong.
  final double focus;

  /// Lock-on progress **without** the `0..1` clamp. Springs overshoot here,
  /// which is what makes the lock feel physical.
  final double focusRaw;

  /// The beam's span across the target, `1` while scanning and `~0.15` when a
  /// target is locked.
  final double beamSpan;

  /// Idle-motion amplitude multiplier: `1` while scanning, `0` once focused.
  final double breath;

  /// Extra backdrop dimming applied when a target is focused, `0..1`.
  final double dim;

  /// Progress of the current terminal-state effect (success/error/invalid),
  /// linearly `0..1` across the whole burst.
  final double feedback;

  /// Progress of the lock-on pulse ring, `0..1`. Reaches `1` when faded out.
  final double pulse;

  /// Hint text reveal, `0..1`.
  final double hint;

  /// Overlay reveal, `0.35` while [ScanFxState.idle] and `1` once a scan
  /// session starts. Layers multiply their alpha by this to produce the
  /// "coming to life" transition.
  final double reveal;

  /// The error-shake displacement already applied to [quad].
  ///
  /// Exposed so layers that deliberately want to *stay still* while the frame
  /// shakes (for example a centred check mark) can subtract it.
  final Offset shake;

  /// The live quad: the default scan area morphed onto the tracked target and
  /// then transformed by the idle motion. Every layer reads this.
  final ScanFxQuad quad;

  /// The default scan area when nothing is tracked.
  final ScanFxQuad defaultQuad;

  /// The padded, mapped target quad, or `null` when nothing is tracked.
  final ScanFxQuad? lockedQuad;

  /// Idle scale factor already baked into [quad], exposed for layers that want
  /// to scale independently (for example the glow).
  final double idleScale;

  /// Idle translation already baked into [quad].
  final Offset idleOffset;

  /// Specular shimmer position, `0..1`, or `0` when the idle style is not
  /// [ScanIdleStyle.shimmer].
  final double shimmer;

  /// Whether the platform asked for reduced motion.
  final bool reduceMotion;

  /// The ambient text direction, used for mirroring directional effects.
  final TextDirection textDirection;

  /// Monotonically increasing counter bumped whenever anything the layers read
  /// changes. Layers may use it to invalidate cached geometry.
  final int revision;

  /// The overall effect strength, `0..1`.
  double get intensity => theme.tunables.intensity;

  /// The glow strength after tunable override and intensity scaling.
  double get glow => theme.resolvedGlow * intensity;

  /// The frame corner radius after tunable override.
  double get cornerRadius => theme.resolvedCornerRadius;

  /// The beam thickness after tunable override and intensity scaling.
  double get beamThickness =>
      (theme.resolvedBeamThickness * (0.6 + 0.4 * intensity)).clamp(0.5, 40);

  /// The bounding box of [quad].
  Rect get rect => quad.bounds;

  /// The full overlay rectangle.
  Rect get overlay => Offset.zero & size;

  /// Whether a live target quad is being drawn.
  bool get hasTarget => lockedQuad != null;

  /// Whether the overlay is inside the window of a terminal effect.
  bool get isTerminal => state.isTerminal;

  /// The colour associated with the current state, falling back to
  /// [QrScanFxTheme.frameColor] while scanning.
  Color get stateColor => switch (state) {
        ScanFxState.success => theme.successColor,
        ScanFxState.error => theme.errorColor,
        ScanFxState.invalid => theme.invalidColor,
        _ => theme.frameColor,
      };

  /// A looping `0..1` value for a channel with [periodMs] and [phase].
  ///
  /// Periods are derived from [ambientSeconds], so a single ticker drives every
  /// ambient loop in the overlay.
  double channel(double periodMs, [double phase = 0]) {
    if (periodMs <= 0) return 0;
    final value = ambientSeconds * (1000 / periodMs) + phase;
    return value - value.floorToDouble();
  }

  /// The beam head position for [options], applying its motion mode.
  ///
  /// * [ScanBeamMotion.loop] wraps, like a scrolling marquee.
  /// * [ScanBeamMotion.pingPong] reflects, so the head never jumps back.
  /// * [ScanBeamMotion.random] uses a smooth, stateless two-tone sum that
  ///   wanders without the jitter of true noise.
  double beamPosition([ScanBeamOptions? options]) {
    final o = options ?? theme.beam;
    final p = channel(o.period.inMilliseconds.toDouble());
    return switch (o.motion) {
      ScanBeamMotion.loop => p,
      ScanBeamMotion.pingPong => 1 - (2 * p - 1).abs(),
      ScanBeamMotion.random => _wander(p),
    };
  }

  /// Maps [feedback] onto a sub-interval of the burst timeline.
  ///
  /// [start] and [span] are fractions of the whole burst, which is how each
  /// effect gets its own stagger from a single shared progress value.
  double local(double start, double span) {
    if (span <= 0) return feedback >= start ? 1 : 0;
    return ((feedback - start) / span).clamp(0.0, 1.0);
  }

  /// The damped sine used to shake the overlay on a failed read.
  ///
  /// [progress] is the burst progress `0..1`, [amplitude] the peak displacement
  /// in logical pixels.
  static Offset shakeFor(
    double progress,
    ScanFxMotion motion,
    double amplitude,
  ) {
    if (amplitude == 0) return Offset.zero;
    final t = progress.clamp(0.0, 1.0);
    final value = math.exp(-motion.shakeDecay * t) *
        math.sin(2 * math.pi * motion.shakeCycles * t);
    return Offset(value * amplitude, 0);
  }

  static double _wander(double p) {
    final a = math.sin(2 * math.pi * p);
    final b = math.sin(2 * math.pi * 2.7 * p + 1.3);
    return (0.5 + 0.35 * a + 0.15 * b).clamp(0.0, 1.0);
  }
}
