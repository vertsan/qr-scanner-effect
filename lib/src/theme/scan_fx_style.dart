/// The style vocabulary of the overlay.
///
/// Every category is a plain enum so themes stay `const`-friendly, switchable
/// and JSON-describable. Custom geometry is injected through
/// `ScanLayerStack.insert` rather than by extending these enums, which keeps
/// exhaustive switches (and therefore golden coverage) possible.
library;

import 'package:flutter/foundation.dart' show immutable;

/// How the frame body is drawn around the tracked target.
enum ScanFrameShape {
  /// A classic rounded rectangle.
  roundedSquare,

  /// An iOS-style continuous corner (superellipse).
  squircle,

  /// A perfect circle inscribed in the scan area.
  circle,

  /// No frame outline; only corner brackets are drawn.
  cornersOnly,
}

/// How each corner bracket is drawn.
enum ScanCornerStyle {
  /// Rounded arms with a soft cap.
  rounded,

  /// Sharp mitred arms.
  sharp,

  /// A filled dot at each corner.
  dot,
}

/// How the beam crossing the scan area is drawn.
enum ScanBeamStyle {
  /// A crisp one-pixel sweep line.
  line,

  /// A soft gradient bar with a fading trail.
  softGradientBar,

  /// A bright line with a strong bloom.
  glowingLaser,
}

/// How the area outside the scan target is treated.
enum ScanBackdropStyle {
  /// A uniform dim with a feathered cutout.
  solidDim,

  /// A real backdrop blur (widget-level `BackdropFilter`) behind the cutout.
  blurredFrost,

  /// A radial vignette with no cutout.
  vignette,

  /// A linear gradient fade from one side.
  gradientFade,

  /// No backdrop at all — the camera preview is untouched.
  none,
}

/// How the focus reticle settles onto a target.
enum ScanLockStyle {
  /// Spring physics with a natural overshoot. The signature lock-on.
  springSnap,

  /// A timed, eased morph that never overshoots.
  smoothMorph,

  /// Springs the scale up from a slightly smaller quad.
  zoomIn,

  /// Lock-on geometry still animates, but no reticle flourish is drawn.
  none,
}

/// The single-shot effect played when a read succeeds.
enum ScanSuccessStyle {
  /// A check mark that draws itself inside the frame.
  checkMorph,

  /// A tint that washes across the frame.
  colorWash,

  /// A bloom pulse around the locked quad.
  glowFlash,

  /// No visual; hosts can still use haptics.
  none,
}

/// The single-shot effect played when a read fails.
enum ScanErrorStyle {
  /// A damped horizontal shake.
  shake,

  /// Two soft pulses towards the error colour.
  redPulse,

  /// A gentle alpha blink.
  fadeBlink,

  /// No visual.
  none,
}

/// The ambient motion applied while scanning.
enum ScanIdleStyle {
  /// The frame gently scales and its glow breathes.
  breathing,

  /// The frame drifts vertically by a few pixels.
  floating,

  /// A specular highlight sweeps across the frame.
  shimmer,

  /// No ambient motion. The calmest option, and the reduce-motion fallback.
  still,
}

/// Which layer a painter belongs to, used for ordering and replacement.
enum ScanLayerKind {
  /// Everything behind the cutout.
  backdrop,

  /// The frame outline.
  frame,

  /// The corner brackets.
  corners,

  /// The scan beam.
  beam,

  /// The lock-on reticle flourish.
  reticle,

  /// Success and error effects.
  effects,

  /// Host-facing hint text.
  hint,
}

/// The travel direction of the scan beam.
enum ScanBeamDirection {
  /// Top to bottom.
  down,

  /// Bottom to top.
  up,

  /// Left to right (mirrored automatically in RTL).
  right,

  /// Right to left.
  left,

  /// Corner to corner, following the quad's rotation.
  diagonal,

  /// A rotating radar sweep from the centre.
  radial,
}

/// How the beam head moves over time.
enum ScanBeamMotion {
  /// Sweeps in one direction, then jumps back and repeats.
  loop,

  /// Sweeps back and forth without a jump.
  pingPong,

  /// Drifts with smoothed pseudo-random speed.
  random,
}

/// Tunables for the scan beam.
@immutable
class ScanBeamOptions {
  /// Creates beam options.
  const ScanBeamOptions({
    this.direction = ScanBeamDirection.down,
    this.motion = ScanBeamMotion.loop,
    this.period = const Duration(milliseconds: 2000),
    this.thickness = 3,
    this.trail = 0.28,
    this.glow = 0.65,
  });

  /// Which way the beam travels.
  final ScanBeamDirection direction;

  /// How the beam repeats.
  final ScanBeamMotion motion;

  /// One full sweep duration (before the speed multiplier is applied).
  final Duration period;

  /// The beam thickness in logical pixels.
  final double thickness;

  /// Fade length behind the head, as a fraction of the sweep length.
  final double trail;

  /// Bloom strength, `0..1`.
  final double glow;

  /// Copy with overrides.
  ScanBeamOptions copyWith({
    ScanBeamDirection? direction,
    ScanBeamMotion? motion,
    Duration? period,
    double? thickness,
    double? trail,
    double? glow,
  }) =>
      ScanBeamOptions(
        direction: direction ?? this.direction,
        motion: motion ?? this.motion,
        period: period ?? this.period,
        thickness: thickness ?? this.thickness,
        trail: trail ?? this.trail,
        glow: glow ?? this.glow,
      );

  /// Interpolates between two option sets.
  static ScanBeamOptions lerp(ScanBeamOptions a, ScanBeamOptions b, double t) =>
      ScanBeamOptions(
        direction: t < 0.5 ? a.direction : b.direction,
        motion: t < 0.5 ? a.motion : b.motion,
        period: _lerpDuration(a.period, b.period, t),
        thickness: _lerp(a.thickness, b.thickness, t),
        trail: _lerp(a.trail, b.trail, t),
        glow: _lerp(a.glow, b.glow, t),
      );

  @override
  bool operator ==(Object other) =>
      other is ScanBeamOptions &&
      other.direction == direction &&
      other.motion == motion &&
      other.period == period &&
      other.thickness == thickness &&
      other.trail == trail &&
      other.glow == glow;

  @override
  int get hashCode => Object.hash(
        direction,
        motion,
        period,
        thickness,
        trail,
        glow,
      );
}

/// Tunables for the lock-on animation.
@immutable
class ScanLockOptions {
  /// Creates lock options.
  const ScanLockOptions({
    this.padding = 12,
    this.cornerFollow = 1,
    this.pulseStrength = 0.5,
  });

  /// Extra margin around the detected target, in logical pixels.
  final double padding;

  /// `1` follows rotated corners exactly; lower values relax towards the
  /// axis-aligned bounding box, which reads as calmer for banking UIs.
  final double cornerFollow;

  /// Strength of the lock-on pulse ring, `0..1`.
  final double pulseStrength;

  /// Copy with overrides.
  ScanLockOptions copyWith({
    double? padding,
    double? cornerFollow,
    double? pulseStrength,
  }) =>
      ScanLockOptions(
        padding: padding ?? this.padding,
        cornerFollow: cornerFollow ?? this.cornerFollow,
        pulseStrength: pulseStrength ?? this.pulseStrength,
      );

  /// Interpolates between two option sets.
  static ScanLockOptions lerp(ScanLockOptions a, ScanLockOptions b, double t) =>
      ScanLockOptions(
        padding: _lerp(a.padding, b.padding, t),
        cornerFollow: _lerp(a.cornerFollow, b.cornerFollow, t),
        pulseStrength: _lerp(a.pulseStrength, b.pulseStrength, t),
      );

  @override
  bool operator ==(Object other) =>
      other is ScanLockOptions &&
      other.padding == padding &&
      other.cornerFollow == cornerFollow &&
      other.pulseStrength == pulseStrength;

  @override
  int get hashCode => Object.hash(padding, cornerFollow, pulseStrength);
}

/// Tunables for the success effect.
@immutable
class ScanSuccessOptions {
  /// Creates success options.
  const ScanSuccessOptions({
    this.checkStrokeWidth = 5,
  });

  /// Stroke width of the check mark.
  final double checkStrokeWidth;

  /// Copy with overrides.
  ScanSuccessOptions copyWith({
    double? checkStrokeWidth,
  }) =>
      ScanSuccessOptions(
        checkStrokeWidth: checkStrokeWidth ?? this.checkStrokeWidth,
      );

  /// Interpolates between two option sets.
  static ScanSuccessOptions lerp(
    ScanSuccessOptions a,
    ScanSuccessOptions b,
    double t,
  ) =>
      ScanSuccessOptions(
        checkStrokeWidth: _lerp(a.checkStrokeWidth, b.checkStrokeWidth, t),
      );

  @override
  bool operator ==(Object other) =>
      other is ScanSuccessOptions && other.checkStrokeWidth == checkStrokeWidth;

  @override
  int get hashCode => checkStrokeWidth.hashCode;
}

/// Tunables for the error effect.
@immutable
class ScanErrorOptions {
  /// Creates error options.
  const ScanErrorOptions({
    this.shakeAmplitude = 10,
    this.pulseCount = 2,
  });

  /// Peak horizontal displacement of the shake, in logical pixels.
  final double shakeAmplitude;

  /// How many colour pulses the effect plays.
  final int pulseCount;

  /// Copy with overrides.
  ScanErrorOptions copyWith({double? shakeAmplitude, int? pulseCount}) =>
      ScanErrorOptions(
        shakeAmplitude: shakeAmplitude ?? this.shakeAmplitude,
        pulseCount: pulseCount ?? this.pulseCount,
      );

  /// Interpolates between two option sets.
  static ScanErrorOptions lerp(
    ScanErrorOptions a,
    ScanErrorOptions b,
    double t,
  ) =>
      ScanErrorOptions(
        shakeAmplitude: _lerp(a.shakeAmplitude, b.shakeAmplitude, t),
        pulseCount: t < 0.5 ? a.pulseCount : b.pulseCount,
      );

  @override
  bool operator ==(Object other) =>
      other is ScanErrorOptions &&
      other.shakeAmplitude == shakeAmplitude &&
      other.pulseCount == pulseCount;

  @override
  int get hashCode => Object.hash(shakeAmplitude, pulseCount);
}

/// Tunables for the backdrop layer.
@immutable
class ScanBackdropOptions {
  /// Creates backdrop options.
  const ScanBackdropOptions({
    this.dimOpacity = 0.55,
    this.deepenedOpacity = 0.68,
    this.feather = 18,
    this.blurSigma = 14,
    this.tintOpacity = 0.12,
  });

  /// Dim opacity while scanning.
  final double dimOpacity;

  /// Dim opacity while a target is locked, so the code stands out.
  final double deepenedOpacity;

  /// Softness of the cutout edge, in logical pixels. `0` disables the blur pass
  /// and is the fast path.
  final double feather;

  /// Backdrop blur radius for [ScanBackdropStyle.blurredFrost].
  final double blurSigma;

  /// How strongly the backdrop tint colour is mixed in, `0..1`.
  final double tintOpacity;

  /// Copy with overrides.
  ScanBackdropOptions copyWith({
    double? dimOpacity,
    double? deepenedOpacity,
    double? feather,
    double? blurSigma,
    double? tintOpacity,
  }) =>
      ScanBackdropOptions(
        dimOpacity: dimOpacity ?? this.dimOpacity,
        deepenedOpacity: deepenedOpacity ?? this.deepenedOpacity,
        feather: feather ?? this.feather,
        blurSigma: blurSigma ?? this.blurSigma,
        tintOpacity: tintOpacity ?? this.tintOpacity,
      );

  /// Interpolates between two option sets.
  static ScanBackdropOptions lerp(
    ScanBackdropOptions a,
    ScanBackdropOptions b,
    double t,
  ) =>
      ScanBackdropOptions(
        dimOpacity: _lerp(a.dimOpacity, b.dimOpacity, t),
        deepenedOpacity: _lerp(a.deepenedOpacity, b.deepenedOpacity, t),
        feather: _lerp(a.feather, b.feather, t),
        blurSigma: _lerp(a.blurSigma, b.blurSigma, t),
        tintOpacity: _lerp(a.tintOpacity, b.tintOpacity, t),
      );

  @override
  bool operator ==(Object other) =>
      other is ScanBackdropOptions &&
      other.dimOpacity == dimOpacity &&
      other.deepenedOpacity == deepenedOpacity &&
      other.feather == feather &&
      other.blurSigma == blurSigma &&
      other.tintOpacity == tintOpacity;

  @override
  int get hashCode => Object.hash(
        dimOpacity,
        deepenedOpacity,
        feather,
        blurSigma,
        tintOpacity,
      );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
      microseconds:
          (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
              .round(),
    );
