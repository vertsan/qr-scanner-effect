import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/physics.dart' show SpringDescription;

/// The complete timing spec of the overlay, as data.
///
/// Keeping durations and spring values here — rather than scattered through
/// painters — is what makes "one motion language" possible: change
/// [lockSpring] once and every style that locks on inherits it.
///
/// See `doc/animation-spec.md` for the reasoning behind each number.
@immutable
class ScanFxMotion {
  /// Creates a motion spec. The defaults are the shipped values.
  const ScanFxMotion({
    this.start = const Duration(milliseconds: 240),
    this.lockHold = const Duration(milliseconds: 140),
    this.lockConverge = const Duration(milliseconds: 220),
    this.beamRetract = const Duration(milliseconds: 220),
    this.breathFade = const Duration(milliseconds: 180),
    this.backdropDeepen = const Duration(milliseconds: 260),
    this.colorBlend = const Duration(milliseconds: 260),
    this.hint = const Duration(milliseconds: 260),
    this.success = const Duration(milliseconds: 900),
    this.error = const Duration(milliseconds: 620),
    this.invalid = const Duration(milliseconds: 380),
    this.reset = const Duration(milliseconds: 300),
    this.microFade = const Duration(milliseconds: 120),
    this.lockSpring = const SpringDescription(
      mass: 1,
      stiffness: 180,
      damping: 19.32,
    ),
    this.calmLockSpring = const SpringDescription(
      mass: 1,
      stiffness: 220,
      damping: 29.66,
    ),
    this.resetSpring = const SpringDescription(
      mass: 1,
      stiffness: 260,
      damping: 32.25,
    ),
    this.zoomSpring = const SpringDescription(
      mass: 1,
      stiffness: 200,
      damping: 16.97,
    ),
    this.reducedSpring = const SpringDescription(
      mass: 1,
      stiffness: 2600,
      damping: 102,
    ),
    this.reduceMotion = false,
    this.shakeCycles = 5.9,
    this.shakeDecay = 3.5,
  });

  /// The shipped defaults: lively but tasteful.
  static const ScanFxMotion defaults = ScanFxMotion();

  /// The banking variant: every duration under 400 ms and a critically damped
  /// lock-on, so nothing ever feels jumpy or celebratory.
  static const ScanFxMotion banking = ScanFxMotion(
    start: Duration(milliseconds: 200),
    lockHold: Duration(milliseconds: 120),
    lockConverge: Duration(milliseconds: 180),
    beamRetract: Duration(milliseconds: 180),
    breathFade: Duration(milliseconds: 160),
    backdropDeepen: Duration(milliseconds: 220),
    colorBlend: Duration(milliseconds: 220),
    hint: Duration(milliseconds: 220),
    success: Duration(milliseconds: 380),
    error: Duration(milliseconds: 360),
    invalid: Duration(milliseconds: 340),
    reset: Duration(milliseconds: 260),
    lockSpring: SpringDescription(mass: 1, stiffness: 220, damping: 29.66),
  );

  /// Time from idle to the first scanning frame.
  final Duration start;

  /// How long [ScanFxState.detected] is held before auto-locking.
  final Duration lockHold;

  /// Bracket convergence after the lock springs settle.
  final Duration lockConverge;

  /// How long the beam takes to retract onto the target.
  final Duration beamRetract;

  /// Fade-out of the idle breathing amplitude when a target appears.
  final Duration breathFade;

  /// Backdrop dimming ramp.
  final Duration backdropDeepen;

  /// Colour cross-fades between states.
  final Duration colorBlend;

  /// Hint text slide and fade.
  final Duration hint;

  /// Total length of the success effect.
  final Duration success;

  /// Total length of the error effect.
  final Duration error;

  /// Total length of the invalid effect.
  final Duration invalid;

  /// Return-to-scanning duration.
  final Duration reset;

  /// The ceiling applied to every duration under reduce-motion.
  final Duration microFade;

  /// Spring used by [ScanLockStyle.springSnap].
  final SpringDescription lockSpring;

  /// Critically damped lock-on used by banking mode and reduce-motion.
  final SpringDescription calmLockSpring;

  /// Spring used when returning to the default scan area.
  final SpringDescription resetSpring;

  /// Spring used by [ScanLockStyle.zoomIn].
  final SpringDescription zoomSpring;

  /// A very stiff spring that settles in a few frames, used when
  /// [reduceMotion] is set so the same code path still runs.
  final SpringDescription reducedSpring;

  /// When `true`, ambient loops stop and every duration is capped at
  /// [microFade].
  final bool reduceMotion;

  /// Oscillations of the error shake across the whole burst.
  final double shakeCycles;

  /// Envelope decay of the error shake; higher stops it sooner.
  final double shakeDecay;

  /// The spring this spec uses for lock-on, accounting for reduce-motion.
  SpringDescription get effectiveLockSpring =>
      reduceMotion ? reducedSpring : lockSpring;

  /// The spring this spec uses when returning to scanning.
  SpringDescription get effectiveResetSpring =>
      reduceMotion ? reducedSpring : resetSpring;

  /// Caps [duration] under reduce-motion, otherwise returns it unchanged.
  Duration effective(Duration duration) =>
      reduceMotion && duration > microFade ? microFade : duration;

  /// Returns a copy with durations divided by [speedMultiplier] and
  /// [reduceMotion] applied.
  ///
  /// Speed changes never reset the animation: the director keeps its current
  /// position and simply walks the remaining distance faster.
  ScanFxMotion scale({
    required double speedMultiplier,
    required bool reduceMotion,
  }) {
    final speed = speedMultiplier.clamp(0.25, 3.0);
    Duration s(Duration d) => Duration(
          microseconds: (d.inMicroseconds / speed).round(),
        );
    return ScanFxMotion(
      start: s(start),
      lockHold: s(lockHold),
      lockConverge: s(lockConverge),
      beamRetract: s(beamRetract),
      breathFade: s(breathFade),
      backdropDeepen: s(backdropDeepen),
      colorBlend: s(colorBlend),
      hint: s(hint),
      success: s(success),
      error: s(error),
      invalid: s(invalid),
      reset: s(reset),
      microFade: microFade,
      lockSpring: lockSpring,
      calmLockSpring: calmLockSpring,
      resetSpring: resetSpring,
      zoomSpring: zoomSpring,
      reducedSpring: reducedSpring,
      reduceMotion: reduceMotion,
      shakeCycles: shakeCycles,
      shakeDecay: shakeDecay,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScanFxMotion &&
      other.start == start &&
      other.lockHold == lockHold &&
      other.lockConverge == lockConverge &&
      other.beamRetract == beamRetract &&
      other.breathFade == breathFade &&
      other.backdropDeepen == backdropDeepen &&
      other.colorBlend == colorBlend &&
      other.hint == hint &&
      other.success == success &&
      other.error == error &&
      other.invalid == invalid &&
      other.reset == reset &&
      other.microFade == microFade &&
      other.lockSpring == lockSpring &&
      other.calmLockSpring == calmLockSpring &&
      other.resetSpring == resetSpring &&
      other.zoomSpring == zoomSpring &&
      other.reducedSpring == reducedSpring &&
      other.reduceMotion == reduceMotion &&
      other.shakeCycles == shakeCycles &&
      other.shakeDecay == shakeDecay;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        start,
        lockHold,
        lockConverge,
        beamRetract,
        breathFade,
        backdropDeepen,
        colorBlend,
        hint,
        success,
        error,
        invalid,
        reset,
        microFade,
        lockSpring,
        calmLockSpring,
        resetSpring,
        zoomSpring,
        reducedSpring,
        reduceMotion,
        shakeCycles,
        shakeDecay,
      ]);
}

/// The easing vocabulary used by the overlay, named for readability at call
/// sites. Flutter's built-ins cover most of the spec; the remainder live in
/// `ScanFxCurves`.
abstract final class ScanFxEasing {
  /// Default easing for state cross-fades.
  static const start = Curves.easeOutCubic;

  /// Beam retract and bracket convergence.
  static const converge = Curves.easeOutCubic;

  /// Ripple waves and glow flashes.
  static const burst = Curves.easeOutQuart;

  /// Fade-out halves.
  static const release = Curves.easeInCubic;

  /// Symmetric ambient transitions.
  static const ambient = Curves.easeInOutSine;

  /// Colour washes.
  static const wash = Curves.easeInOutCubic;
}
