import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'scan_fx_labels.dart';
import 'scan_fx_motion.dart';
import 'scan_fx_style.dart';
import 'scan_fx_tunables.dart';

/// The complete visual configuration of a [QrScanFx] overlay.
///
/// `QrScanFxTheme` is a [ThemeExtension], so it can be installed globally and
/// overridden per widget:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const <ThemeExtension<dynamic>>[QrScanFxTheme.dark],
///   ),
/// );
/// ```
///
/// Resolution order inside the overlay is:
///
/// 1. `QrScanFx(theme: ...)` — an explicit per-widget override wins.
/// 2. `Theme.of(context).extension<QrScanFxTheme>()` — the app-wide theme.
/// 3. [QrScanFxTheme.dark] — the fallback (a light fallback is chosen
///    automatically when the ambient brightness is light).
///
/// Every field is `const`-friendly and every [copyWith] argument is documented
/// in the getter it mirrors. Live tuning of intensity/speed/glow/radius should
/// go through [tunables] rather than [copyWith], because tunables are picked up
/// without resetting the animation.
@immutable
class QrScanFxTheme extends ThemeExtension<QrScanFxTheme> {
  /// Creates a theme. Prefer a named constructor such as
  /// [QrScanFxTheme.dark], [QrScanFxTheme.fromColorScheme] or a preset.
  const QrScanFxTheme({
    this.frameColor = const Color(0xFFE8F1FF),
    this.frameGlowColor = const Color(0xFF4D9DFF),
    this.cornerColor = const Color(0xFFFFFFFF),
    this.beamColor = const Color(0xFF7CC2FF),
    this.beamAccentColor = const Color(0xFFFFFFFF),
    this.backdropColor = const Color(0xFF050A14),
    this.successColor = const Color(0xFF35D07F),
    this.errorColor = const Color(0xFFFF5A5F),
    this.invalidColor = const Color(0xFFFFB020),
    this.hintBackgroundColor = const Color(0xCC0B1220),
    this.hintTextColor = const Color(0xFFFFFFFF),
    this.scrimColor = const Color(0x00000000),
    this.glowStrength = 0.65,
    this.squircleExponent = 4,
    this.frameShape = ScanFrameShape.roundedSquare,
    this.cornerStyle = ScanCornerStyle.rounded,
    this.cornerRadius = 28,
    this.frameStrokeWidth = 2,
    this.cornerStrokeWidth = 4,
    this.cornerArmFraction = 0.18,
    this.backdropStyle = ScanBackdropStyle.solidDim,
    this.beamStyle = ScanBeamStyle.softGradientBar,
    this.lockStyle = ScanLockStyle.springSnap,
    this.successStyle = ScanSuccessStyle.checkMorph,
    this.errorStyle = ScanErrorStyle.shake,
    this.idleStyle = ScanIdleStyle.breathing,
    this.backdrop = const ScanBackdropOptions(),
    this.beam = const ScanBeamOptions(),
    this.lock = const ScanLockOptions(),
    this.success = const ScanSuccessOptions(),
    this.error = const ScanErrorOptions(),
    this.motion = ScanFxMotion.defaults,
    this.tunables = ScanFxTunables.defaults,
    this.hintTextStyle = const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
    this.labels = const ScanFxSemanticsLabels(),
  });

  /// The dark theme, tuned for a camera preview at night.
  static const QrScanFxTheme dark = QrScanFxTheme();

  /// The light theme, tuned for bright environments and light app shells.
  static const QrScanFxTheme light = QrScanFxTheme(
    frameColor: Color(0xFF0A2A43),
    frameGlowColor: Color(0xFF2E7DD1),
    cornerColor: Color(0xFF0A2A43),
    beamColor: Color(0xFF2E7DD1),
    beamAccentColor: Color(0xFF0A2A43),
    backdropColor: Color(0xFFF4F7FB),
    successColor: Color(0xFF12805C),
    errorColor: Color(0xFFB3261E),
    invalidColor: Color(0xFF8A5300),
    hintBackgroundColor: Color(0xE6FFFFFF),
    hintTextColor: Color(0xFF0A2A43),
    glowStrength: 0.3,
    frameStrokeWidth: 2.5,
    cornerStrokeWidth: 4.5,
    hintTextStyle: TextStyle(
      color: Color(0xFF0A2A43),
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
  );

  /// A calm, neutral blue theme intended for banking and payment flows.
  ///
  /// No neon, no particles, a critically damped lock-on and durations capped
  /// well below 400 ms. See [QrScanFx.banking] for the full mode.
  static const QrScanFxTheme bankingBlue = QrScanFxTheme(
    frameColor: Color(0xFFE6EEF8),
    frameGlowColor: Color(0xFF1B4F8F),
    cornerColor: Color(0xFFF2F6FC),
    beamColor: Color(0xFF7EA6D6),
    beamAccentColor: Color(0xFFF2F6FC),
    backdropColor: Color(0xFF04070D),
    successColor: Color(0xFF3FBF8F),
    errorColor: Color(0xFFE0605F),
    invalidColor: Color(0xFFE0A33F),
    hintBackgroundColor: Color(0xFF0B1220),
    hintTextColor: Color(0xFFF2F6FC),
    glowStrength: 0.22,
    frameStrokeWidth: 2,
    cornerStrokeWidth: 4,
    cornerArmFraction: 0.16,
    backdropStyle: ScanBackdropStyle.solidDim,
    beamStyle: ScanBeamStyle.softGradientBar,
    lockStyle: ScanLockStyle.smoothMorph,
    successStyle: ScanSuccessStyle.colorWash,
    errorStyle: ScanErrorStyle.fadeBlink,
    idleStyle: ScanIdleStyle.breathing,
    backdrop:
        ScanBackdropOptions(dimOpacity: 0.6, deepenedOpacity: 0.7, feather: 20),
    beam: ScanBeamOptions(
      period: Duration(milliseconds: 2400),
      thickness: 2.5,
      trail: 0.32,
      glow: 0.4,
    ),
    lock: ScanLockOptions(padding: 14, cornerFollow: 0.85, pulseStrength: 0.28),
    success: ScanSuccessOptions(checkStrokeWidth: 4.5),
    error: ScanErrorOptions(shakeAmplitude: 0, pulseCount: 2),
    motion: ScanFxMotion.banking,
    labels: ScanFxSemanticsLabels(
      idle: 'Ready to scan',
      scanning: 'Scanning',
      detected: 'Code detected',
      locked: 'Code detected',
      success: 'Code scanned',
      error: 'Could not scan code',
      invalid: 'Unsupported or invalid QR code',
    ),
  );

  /// Aurora: cool teal-cyan with a drifting curtain of light.
  static const QrScanFxTheme aurora = QrScanFxTheme(
    frameColor: Color(0xFFE6FFFB),
    frameGlowColor: Color(0xFF3DDCFF),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFF64FFDA),
    beamAccentColor: Color(0xFFFFFFFF),
    backdropColor: Color(0xFF061826),
    successColor: Color(0xFF35D07F),
    errorColor: Color(0xFFFF5A5F),
    invalidColor: Color(0xFFFFB020),
    glowStrength: 0.38,
    frameStrokeWidth: 2.5,
    cornerStrokeWidth: 4,
    beamStyle: ScanBeamStyle.aurora,
    lockStyle: ScanLockStyle.smoothMorph,
    backdropStyle: ScanBackdropStyle.gradientFade,
  );

  /// Neon cyberpunk: electric cyan and violet.
  static const QrScanFxTheme neonCyber = QrScanFxTheme(
    frameColor: Color(0xFFF5E6FF),
    frameGlowColor: Color(0xFF7C4DFF),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFF40C4FF),
    beamAccentColor: Color(0xFFFFFFFF),
    backdropColor: Color(0xFF050510),
    successColor: Color(0xFF39FF14),
    errorColor: Color(0xFFFF3366),
    invalidColor: Color(0xFFFFB020),
    glowStrength: 0.5,
    frameStrokeWidth: 2,
    beamStyle: ScanBeamStyle.doubleLaser,
    lockStyle: ScanLockStyle.glitchLock,
    backdropStyle: ScanBackdropStyle.vignette,
    cornerStyle: ScanCornerStyle.glowing,
  );

  /// Mono glass: clean white hairlines over a deep black scrim.
  static const QrScanFxTheme monoGlass = QrScanFxTheme(
    frameColor: Color(0xFFFFFFFF),
    frameGlowColor: Color(0x80FFFFFF),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFFFFFFFF),
    beamAccentColor: Color(0xFFFFFFFF),
    backdropColor: Color(0xFF000000),
    successColor: Color(0xFF4CAF50),
    errorColor: Color(0xFFF44336),
    invalidColor: Color(0xFFFFC107),
    glowStrength: 0.25,
    frameStrokeWidth: 1.5,
    beamStyle: ScanBeamStyle.softGradientBar,
    backdropStyle: ScanBackdropStyle.blurredFrost,
    cornerStyle: ScanCornerStyle.rounded,
  );

  /// Sunset gradient: warm amber fading to rose.
  static const QrScanFxTheme sunsetGradient = QrScanFxTheme(
    frameColor: Color(0xFFFFF3E0),
    frameGlowColor: Color(0xFFFF7043),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFFFFA726),
    beamAccentColor: Color(0xFFFFCC80),
    backdropColor: Color(0xFF1A0E08),
    successColor: Color(0xFF81C784),
    errorColor: Color(0xFFE57373),
    invalidColor: Color(0xFFFFB74D),
    glowStrength: 0.4,
    frameStrokeWidth: 2.5,
    beamStyle: ScanBeamStyle.waveform,
    backdropStyle: ScanBackdropStyle.gradientFade,
    cornerStyle: ScanCornerStyle.chamfered,
  );

  /// Ocean deep: layered blues with a soft pulse.
  static const QrScanFxTheme oceanDeep = QrScanFxTheme(
    frameColor: Color(0xFFE8F1FF),
    frameGlowColor: Color(0xFF1565C0),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFF4FC3F7),
    beamAccentColor: Color(0xFFB3E5FC),
    backdropColor: Color(0xFF060B1F),
    successColor: Color(0xFF66BB6A),
    errorColor: Color(0xFFEF5350),
    invalidColor: Color(0xFFFFCA28),
    glowStrength: 0.32,
    frameStrokeWidth: 2,
    beamStyle: ScanBeamStyle.softGradientBar,
    backdropStyle: ScanBackdropStyle.solidDim,
    lockStyle: ScanLockStyle.pulseLock,
  );

  /// Matrix green: terminal phosphor.
  static const QrScanFxTheme matrixGreen = QrScanFxTheme(
    frameColor: Color(0xFFB9F6CA),
    frameGlowColor: Color(0xFF00C853),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFF69F0AE),
    beamAccentColor: Color(0xFFB9F6CA),
    backdropColor: Color(0xFF020F08),
    successColor: Color(0xFF69F0AE),
    errorColor: Color(0xFFFF5252),
    invalidColor: Color(0xFFFFD740),
    glowStrength: 0.42,
    frameStrokeWidth: 2,
    beamStyle: ScanBeamStyle.line,
    cornerStyle: ScanCornerStyle.sharp,
    backdropStyle: ScanBackdropStyle.gradientFade,
    frameShape: ScanFrameShape.fullBorder,
  );

  /// Rose gold: warm, premium, low-key.
  static const QrScanFxTheme roseGold = QrScanFxTheme(
    frameColor: Color(0xFFFDEAE6),
    frameGlowColor: Color(0xFFF48FB1),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFFF8BBD9),
    beamAccentColor: Color(0xFFFFFFFF),
    backdropColor: Color(0xFF14040C),
    successColor: Color(0xFF80CBC4),
    errorColor: Color(0xFFF06292),
    invalidColor: Color(0xFFFFD54F),
    glowStrength: 0.36,
    frameStrokeWidth: 2.5,
    cornerStyle: ScanCornerStyle.chamfered,
    backdropStyle: ScanBackdropStyle.vignette,
    beamStyle: ScanBeamStyle.waveform,
  );

  /// Midnight purple: cinematic and calm.
  static const QrScanFxTheme midnightPurple = QrScanFxTheme(
    frameColor: Color(0xFFEDE7F6),
    frameGlowColor: Color(0xFF9575CD),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFFB39DDB),
    beamAccentColor: Color(0xFFFEFEFE),
    backdropColor: Color(0xFF08040F),
    successColor: Color(0xFF81C784),
    errorColor: Color(0xFFEF5350),
    invalidColor: Color(0xFFFFD54F),
    glowStrength: 0.4,
    frameStrokeWidth: 2,
    beamStyle: ScanBeamStyle.pulseRings,
    backdropStyle: ScanBackdropStyle.spotlight,
    lockStyle: ScanLockStyle.ringContract,
  );

  /// Clean white: maximum legibility over any preview.
  static const QrScanFxTheme cleanWhite = QrScanFxTheme(
    frameColor: Color(0xFFFFFFFF),
    frameGlowColor: Color(0x33000000),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFFFFFFFF),
    beamAccentColor: Color(0xFFFAFAFA),
    backdropColor: Color(0x80000000),
    successColor: Color(0xFF2E7D32),
    errorColor: Color(0xFFC62828),
    invalidColor: Color(0xFFF9A825),
    glowStrength: 0.15,
    frameStrokeWidth: 2,
    beamStyle: ScanBeamStyle.line,
    backdropStyle: ScanBackdropStyle.solidDim,
    cornerStyle: ScanCornerStyle.rounded,
  );

  /// High contrast: WCAG-friendly flat colours for accessibility testing.
  static const QrScanFxTheme highContrast = QrScanFxTheme(
    frameColor: Color(0xFFFFFFFF),
    frameGlowColor: Color(0xFFFFFFFF),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFFFFFF00),
    beamAccentColor: Color(0xFFFFFFFF),
    backdropColor: Color(0xFF000000),
    successColor: Color(0xFF00FF00),
    errorColor: Color(0xFFFF0000),
    invalidColor: Color(0xFFFFC107),
    glowStrength: 0.6,
    frameStrokeWidth: 3,
    cornerStrokeWidth: 6,
    beamStyle: ScanBeamStyle.doubleLaser,
    backdropStyle: ScanBackdropStyle.solidDim,
    cornerStyle: ScanCornerStyle.sharp,
    frameShape: ScanFrameShape.fullBorder,
    lockStyle: ScanLockStyle.springSnap,
  );

  /// A high-contrast, minimal light theme with thin strokes.
  static const QrScanFxTheme minimalLight = QrScanFxTheme(
    frameColor: Color(0xFF111827),
    frameGlowColor: Color(0x33000000),
    cornerColor: Color(0xFF111827),
    beamColor: Color(0xFF111827),
    beamAccentColor: Color(0xFFFFFFFF),
    backdropColor: Color(0xFFFFFFFF),
    successColor: Color(0xFF0F766E),
    errorColor: Color(0xFFB91C1C),
    invalidColor: Color(0xFF92400E),
    hintBackgroundColor: Color(0xFFFFFFFF),
    hintTextColor: Color(0xFF111827),
    glowStrength: 0,
    frameStrokeWidth: 2,
    cornerStrokeWidth: 3,
    cornerRadius: 20,
    backdropStyle: ScanBackdropStyle.solidDim,
    beamStyle: ScanBeamStyle.line,
    lockStyle: ScanLockStyle.smoothMorph,
    successStyle: ScanSuccessStyle.colorWash,
    errorStyle: ScanErrorStyle.fadeBlink,
    idleStyle: ScanIdleStyle.breathing,
    backdrop: ScanBackdropOptions(
      dimOpacity: 0.34,
      deepenedOpacity: 0.42,
      feather: 10,
      tintOpacity: 0.05,
    ),
    beam: ScanBeamOptions(thickness: 2, trail: 0.12, glow: 0),
    hintTextStyle: TextStyle(
      color: Color(0xFF111827),
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
  );

  /// Derives an overlay theme from a Material 3 [ColorScheme].
  ///
  /// Frame and beam take the scheme's primary; the backdrop takes the surface's
  /// brightness so the overlay sits naturally on the app's background. Overlay
  /// text is passed through [ScanFxPalette.ensureContrast] so it always clears
  /// WCAG AA.
  factory QrScanFxTheme.fromColorScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final backdrop = isDark ? const Color(0xFF050A14) : const Color(0xFFF7F9FC);
    final frame = ScanFxPalette.ensureContrast(scheme.primary, backdrop);
    final hintBackground =
        isDark ? const Color(0xCC0B1220) : const Color(0xE6FFFFFF);
    return QrScanFxTheme(
      frameColor: frame,
      frameGlowColor: scheme.primary,
      cornerColor: frame,
      beamColor: scheme.primary,
      beamAccentColor: isDark ? Colors.white : backdrop,
      backdropColor: backdrop,
      successColor: ScanFxPalette.ensureContrast(scheme.tertiary, backdrop),
      errorColor: ScanFxPalette.ensureContrast(scheme.error, backdrop),
      invalidColor:
          ScanFxPalette.ensureContrast(scheme.secondary, backdrop, ratio: 3),
      hintBackgroundColor: hintBackground,
      hintTextColor: ScanFxPalette.ensureContrast(
        isDark ? Colors.white : scheme.onSurface,
        hintBackground,
      ),
      glowStrength: isDark ? 0.6 : 0.3,
      hintTextStyle: TextStyle(
        color: ScanFxPalette.ensureContrast(
          isDark ? Colors.white : scheme.onSurface,
          hintBackground,
        ),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
  }

  /// A deterministic random theme, for demos and the Style Studio.
  ///
  /// Colours are picked in HSL around a random hue and then forced through
  /// [ScanFxPalette.ensureContrast], so even random themes stay readable.
  factory QrScanFxTheme.random(
      {int? seed, Brightness brightness = Brightness.dark}) {
    final random = math.Random(seed);
    final isDark = brightness == Brightness.dark;
    final hue = random.nextDouble() * 360;
    final accent =
        HSLColor.fromAHSL(1, hue, 0.72, isDark ? 0.62 : 0.42).toColor();
    final backdrop = isDark ? const Color(0xFF06090F) : const Color(0xFFF8FAFC);
    final hintBackground =
        isDark ? const Color(0xCC0B1220) : const Color(0xE6FFFFFF);
    return QrScanFxTheme(
      frameColor: ScanFxPalette.ensureContrast(accent, backdrop),
      frameGlowColor: accent,
      cornerColor: isDark
          ? Colors.white
          : ScanFxPalette.ensureContrast(accent, backdrop),
      beamColor: HSLColor.fromAHSL(1, (hue + 30) % 360, 0.8, 0.7).toColor(),
      beamAccentColor: isDark ? Colors.white : backdrop,
      backdropColor: backdrop,
      successColor: ScanFxPalette.ensureContrast(
        const HSLColor.fromAHSL(1, 152, 0.6, 0.5).toColor(),
        backdrop,
      ),
      errorColor: ScanFxPalette.ensureContrast(
        const HSLColor.fromAHSL(1, 4, 0.7, 0.55).toColor(),
        backdrop,
      ),
      invalidColor: ScanFxPalette.ensureContrast(
        const HSLColor.fromAHSL(1, 38, 0.8, 0.55).toColor(),
        backdrop,
      ),
      hintBackgroundColor: hintBackground,
      hintTextColor: ScanFxPalette.ensureContrast(
          isDark ? Colors.white : accent, hintBackground),
      glowStrength: isDark ? 0.6 : 0.3,
      cornerRadius: 20 + random.nextDouble() * 24,
      frameShape:
          ScanFrameShape.values[random.nextInt(ScanFrameShape.values.length)],
      cornerStyle:
          ScanCornerStyle.values[random.nextInt(ScanCornerStyle.values.length)],
      backdropStyle: ScanBackdropStyle
          .values[random.nextInt(ScanBackdropStyle.values.length)],
      beamStyle:
          ScanBeamStyle.values[random.nextInt(ScanBeamStyle.values.length)],
      lockStyle:
          ScanLockStyle.values[random.nextInt(ScanLockStyle.values.length)],
      successStyle: ScanSuccessStyle
          .values[random.nextInt(ScanSuccessStyle.values.length)],
      errorStyle:
          ScanErrorStyle.values[random.nextInt(ScanErrorStyle.values.length)],
      idleStyle:
          ScanIdleStyle.values[random.nextInt(ScanIdleStyle.values.length)],
    );
  }

  /// The frame outline colour.
  final Color frameColor;

  /// The colour of the frame's bloom.
  final Color frameGlowColor;

  /// The colour of the corner brackets.
  final Color cornerColor;

  /// The primary beam colour.
  final Color beamColor;

  /// The beam's bright core.
  final Color beamAccentColor;

  /// The colour the backdrop dims towards.
  final Color backdropColor;

  /// The colour used for a successful read.
  final Color successColor;

  /// The colour used for a failed read.
  final Color errorColor;

  /// The colour used for an unacceptable code.
  final Color invalidColor;

  /// The background of the hint pill.
  final Color hintBackgroundColor;

  /// The colour of hint text and host-facing overlay text.
  final Color hintTextColor;

  /// An optional flat wash drawn over the whole overlay.
  final Color scrimColor;

  /// Global bloom strength, `0..1`.
  final double glowStrength;

  /// Superellipse exponent when [frameShape] is [ScanFrameShape.squircle].
  final double squircleExponent;

  /// How the frame body is drawn.
  final ScanFrameShape frameShape;

  /// How corner brackets are drawn.
  final ScanCornerStyle cornerStyle;

  /// Frame corner radius in logical pixels.
  final double cornerRadius;

  /// Frame outline stroke width.
  final double frameStrokeWidth;

  /// Corner bracket stroke width.
  final double cornerStrokeWidth;

  /// Bracket arm length as a fraction of the shortest frame side.
  final double cornerArmFraction;

  /// How the area outside the target is treated.
  final ScanBackdropStyle backdropStyle;

  /// How the beam is drawn.
  final ScanBeamStyle beamStyle;

  /// How the reticle settles onto a target.
  final ScanLockStyle lockStyle;

  /// What happens on a successful read.
  final ScanSuccessStyle successStyle;

  /// What happens on a failed read.
  final ScanErrorStyle errorStyle;

  /// Ambient motion while scanning.
  final ScanIdleStyle idleStyle;

  /// Backdrop tunables.
  final ScanBackdropOptions backdrop;

  /// Beam tunables.
  final ScanBeamOptions beam;

  /// Lock-on tunables.
  final ScanLockOptions lock;

  /// Success tunables.
  final ScanSuccessOptions success;

  /// Error tunables.
  final ScanErrorOptions error;

  /// The timing spec. Motion is *not* interpolated by `lerp`; it switches
  /// discretely at the midpoint of a theme transition.
  final ScanFxMotion motion;

  /// Live-tunable knobs. Change these at runtime — they never reset the
  /// animation.
  final ScanFxTunables tunables;

  /// The style used for host-facing overlay text.
  ///
  /// This carries the typography only. The colour is applied from
  /// [hintTextColor] by [resolvedHintStyle], so a host can recolour the hint with
  /// one field instead of rebuilding a `TextStyle`.
  final TextStyle hintTextStyle;

  /// Screen-reader strings.
  final ScanFxSemanticsLabels labels;

  /// The hint text style actually painted.
  ///
  /// Merges [hintTextStyle] with [hintTextColor], which is what lets a preset
  /// declare its hint colour once and have it apply to every text attribute it
  /// did not override.
  TextStyle get resolvedHintStyle =>
      hintTextStyle.copyWith(color: hintTextColor);

  /// The corner radius after applying any tunable override.
  double get resolvedCornerRadius => tunables.cornerRadius ?? cornerRadius;

  /// The glow strength after applying any tunable override.
  double get resolvedGlow => tunables.glow ?? glowStrength;

  /// The beam thickness after applying any tunable override.
  double get resolvedBeamThickness => tunables.beamThickness ?? beam.thickness;

  /// The backdrop blur radius after applying any tunable override.
  double get resolvedBlurSigma => tunables.blurSigma ?? backdrop.blurSigma;

  /// The lock spring this theme should use, accounting for the lock style and
  /// reduce-motion.
  ///
  /// Reduce-motion wins over the style: the point of the reduced spring is that
  /// it settles in a few frames, and a style that swapped in a softer spring
  /// would quietly opt back out of that.
  SpringDescription get lockSpring => motion.reduceMotion
      ? motion.reducedSpring
      : switch (lockStyle) {
          ScanLockStyle.smoothMorph => motion.calmLockSpring,
          ScanLockStyle.zoomIn => motion.zoomSpring,
          ScanLockStyle.ringContract => motion.ringSpring,
          ScanLockStyle.pulseLock ||
          ScanLockStyle.particleBurst =>
            motion.snapSpring,
          ScanLockStyle.glitchLock => motion.glitchSpring,
          ScanLockStyle.scanlineSweepOver ||
          ScanLockStyle.springSnap ||
          ScanLockStyle.none =>
            motion.lockSpring,
        };

  /// Returns a copy with the frame composited over [overlay].
  ///
  /// Used by [ThemeExtension.lerp] and by hosts that want to tint an existing
  /// theme without rebuilding it.
  QrScanFxTheme tint(Color overlay, double amount) => copyWith(
        frameColor: ScanFxPalette.mix(frameColor, overlay, amount),
        cornerColor: ScanFxPalette.mix(cornerColor, overlay, amount),
        beamColor: ScanFxPalette.mix(beamColor, overlay, amount),
      );

  @override
  QrScanFxTheme copyWith({
    Color? frameColor,
    Color? frameGlowColor,
    Color? cornerColor,
    Color? beamColor,
    Color? beamAccentColor,
    Color? backdropColor,
    Color? successColor,
    Color? errorColor,
    Color? invalidColor,
    Color? hintBackgroundColor,
    Color? hintTextColor,
    Color? scrimColor,
    double? glowStrength,
    double? squircleExponent,
    ScanFrameShape? frameShape,
    ScanCornerStyle? cornerStyle,
    double? cornerRadius,
    double? frameStrokeWidth,
    double? cornerStrokeWidth,
    double? cornerArmFraction,
    ScanBackdropStyle? backdropStyle,
    ScanBeamStyle? beamStyle,
    ScanLockStyle? lockStyle,
    ScanSuccessStyle? successStyle,
    ScanErrorStyle? errorStyle,
    ScanIdleStyle? idleStyle,
    ScanBackdropOptions? backdrop,
    ScanBeamOptions? beam,
    ScanLockOptions? lock,
    ScanSuccessOptions? success,
    ScanErrorOptions? error,
    ScanFxMotion? motion,
    ScanFxTunables? tunables,
    TextStyle? hintTextStyle,
    ScanFxSemanticsLabels? labels,
  }) =>
      QrScanFxTheme(
        frameColor: frameColor ?? this.frameColor,
        frameGlowColor: frameGlowColor ?? this.frameGlowColor,
        cornerColor: cornerColor ?? this.cornerColor,
        beamColor: beamColor ?? this.beamColor,
        beamAccentColor: beamAccentColor ?? this.beamAccentColor,
        backdropColor: backdropColor ?? this.backdropColor,
        successColor: successColor ?? this.successColor,
        errorColor: errorColor ?? this.errorColor,
        invalidColor: invalidColor ?? this.invalidColor,
        hintBackgroundColor: hintBackgroundColor ?? this.hintBackgroundColor,
        hintTextColor: hintTextColor ?? this.hintTextColor,
        scrimColor: scrimColor ?? this.scrimColor,
        glowStrength: glowStrength ?? this.glowStrength,
        squircleExponent: squircleExponent ?? this.squircleExponent,
        frameShape: frameShape ?? this.frameShape,
        cornerStyle: cornerStyle ?? this.cornerStyle,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        frameStrokeWidth: frameStrokeWidth ?? this.frameStrokeWidth,
        cornerStrokeWidth: cornerStrokeWidth ?? this.cornerStrokeWidth,
        cornerArmFraction: cornerArmFraction ?? this.cornerArmFraction,
        backdropStyle: backdropStyle ?? this.backdropStyle,
        beamStyle: beamStyle ?? this.beamStyle,
        lockStyle: lockStyle ?? this.lockStyle,
        successStyle: successStyle ?? this.successStyle,
        errorStyle: errorStyle ?? this.errorStyle,
        idleStyle: idleStyle ?? this.idleStyle,
        backdrop: backdrop ?? this.backdrop,
        beam: beam ?? this.beam,
        lock: lock ?? this.lock,
        success: success ?? this.success,
        error: error ?? this.error,
        motion: motion ?? this.motion,
        tunables: tunables ?? this.tunables,
        hintTextStyle: hintTextStyle ?? this.hintTextStyle,
        labels: labels ?? this.labels,
      );

  @override
  QrScanFxTheme lerp(covariant QrScanFxTheme? other, double t) {
    if (other == null) return this;
    if (identical(this, other)) return this;
    final discrete = t < 0.5;
    return QrScanFxTheme(
      frameColor: Color.lerp(frameColor, other.frameColor, t)!,
      frameGlowColor: Color.lerp(frameGlowColor, other.frameGlowColor, t)!,
      cornerColor: Color.lerp(cornerColor, other.cornerColor, t)!,
      beamColor: Color.lerp(beamColor, other.beamColor, t)!,
      beamAccentColor: Color.lerp(beamAccentColor, other.beamAccentColor, t)!,
      backdropColor: Color.lerp(backdropColor, other.backdropColor, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      invalidColor: Color.lerp(invalidColor, other.invalidColor, t)!,
      hintBackgroundColor:
          Color.lerp(hintBackgroundColor, other.hintBackgroundColor, t)!,
      hintTextColor: Color.lerp(hintTextColor, other.hintTextColor, t)!,
      scrimColor: Color.lerp(scrimColor, other.scrimColor, t)!,
      glowStrength: lerpDouble(glowStrength, other.glowStrength, t)!,
      squircleExponent:
          lerpDouble(squircleExponent, other.squircleExponent, t)!,
      frameShape: discrete ? frameShape : other.frameShape,
      cornerStyle: discrete ? cornerStyle : other.cornerStyle,
      cornerRadius: lerpDouble(cornerRadius, other.cornerRadius, t)!,
      frameStrokeWidth:
          lerpDouble(frameStrokeWidth, other.frameStrokeWidth, t)!,
      cornerStrokeWidth:
          lerpDouble(cornerStrokeWidth, other.cornerStrokeWidth, t)!,
      cornerArmFraction:
          lerpDouble(cornerArmFraction, other.cornerArmFraction, t)!,
      backdropStyle: discrete ? backdropStyle : other.backdropStyle,
      beamStyle: discrete ? beamStyle : other.beamStyle,
      lockStyle: discrete ? lockStyle : other.lockStyle,
      successStyle: discrete ? successStyle : other.successStyle,
      errorStyle: discrete ? errorStyle : other.errorStyle,
      idleStyle: discrete ? idleStyle : other.idleStyle,
      backdrop: ScanBackdropOptions.lerp(backdrop, other.backdrop, t),
      beam: ScanBeamOptions.lerp(beam, other.beam, t),
      lock: ScanLockOptions.lerp(lock, other.lock, t),
      success: ScanSuccessOptions.lerp(success, other.success, t),
      error: ScanErrorOptions.lerp(error, other.error, t),
      motion: discrete ? motion : other.motion,
      tunables: ScanFxTunables.lerp(tunables, other.tunables, t),
      hintTextStyle: TextStyle.lerp(hintTextStyle, other.hintTextStyle, t) ??
          hintTextStyle,
      labels: discrete ? labels : other.labels,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QrScanFxTheme &&
      other.frameColor == frameColor &&
      other.frameGlowColor == frameGlowColor &&
      other.cornerColor == cornerColor &&
      other.beamColor == beamColor &&
      other.beamAccentColor == beamAccentColor &&
      other.backdropColor == backdropColor &&
      other.successColor == successColor &&
      other.errorColor == errorColor &&
      other.invalidColor == invalidColor &&
      other.hintBackgroundColor == hintBackgroundColor &&
      other.hintTextColor == hintTextColor &&
      other.scrimColor == scrimColor &&
      other.glowStrength == glowStrength &&
      other.squircleExponent == squircleExponent &&
      other.frameShape == frameShape &&
      other.cornerStyle == cornerStyle &&
      other.cornerRadius == cornerRadius &&
      other.frameStrokeWidth == frameStrokeWidth &&
      other.cornerStrokeWidth == cornerStrokeWidth &&
      other.cornerArmFraction == cornerArmFraction &&
      other.backdropStyle == backdropStyle &&
      other.beamStyle == beamStyle &&
      other.lockStyle == lockStyle &&
      other.successStyle == successStyle &&
      other.errorStyle == errorStyle &&
      other.idleStyle == idleStyle &&
      other.backdrop == backdrop &&
      other.beam == beam &&
      other.lock == lock &&
      other.success == success &&
      other.error == error &&
      other.motion == motion &&
      other.tunables == tunables &&
      other.hintTextStyle == hintTextStyle &&
      other.labels == labels;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        frameColor,
        frameGlowColor,
        cornerColor,
        beamColor,
        beamAccentColor,
        backdropColor,
        successColor,
        errorColor,
        invalidColor,
        hintBackgroundColor,
        hintTextColor,
        scrimColor,
        glowStrength,
        squircleExponent,
        frameShape,
        cornerStyle,
        cornerRadius,
        frameStrokeWidth,
        cornerStrokeWidth,
        cornerArmFraction,
        backdropStyle,
        beamStyle,
        lockStyle,
        successStyle,
        errorStyle,
        idleStyle,
        backdrop,
        beam,
        lock,
        success,
        error,
        motion,
        tunables,
        hintTextStyle,
        labels,
      ]);
}
