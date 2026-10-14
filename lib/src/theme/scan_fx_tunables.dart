import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

/// Live-tunable knobs for the overlay.
///
/// Every value can be changed at runtime **without resetting the animation**:
/// the director picks up the new tunables on the next tick. The Style Studio
/// example drives these directly from sliders.
///
/// Nullable fields are *overrides*: `null` means "use the theme value", so a
/// host can nudge one knob without pinning the others.
@immutable
class ScanFxTunables {
  /// Creates tunables. All values are clamped on construction and in
  /// [copyWith], so no combination can produce a broken frame.
  const ScanFxTunables({
    double intensity = 1,
    double speed = 1,
    this.glow,
    this.cornerRadius,
    this.beamThickness,
    this.blurSigma,
  })  : intensity = intensity < 0 ? 0 : (intensity > 1 ? 1 : intensity),
        speed = speed < 0.25 ? 0.25 : (speed > 3 ? 3 : speed);

  /// The identity tunables: full intensity, real-time speed, theme values for
  /// everything else.
  static const ScanFxTunables defaults = ScanFxTunables();

  /// Overall effect strength, `0..1`. Scales alpha, glow and padding.
  final double intensity;

  /// Playback rate multiplier, `0.25..3`. Divides every duration in the motion
  /// spec; the current animation position is preserved.
  final double speed;

  /// Glow strength override, `0..1`. `0` removes the blur pass entirely.
  final double? glow;

  /// Frame corner radius override, in logical pixels.
  final double? cornerRadius;

  /// Beam thickness override, in logical pixels.
  final double? beamThickness;

  /// Backdrop blur radius override. `0` degrades a frosted backdrop to a flat
  /// dim, which is the documented fast path.
  final double? blurSigma;

  /// Copy with overrides, clamping the same way the constructor does.
  ScanFxTunables copyWith({
    double? intensity,
    double? speed,
    double? glow,
    double? cornerRadius,
    double? beamThickness,
    double? blurSigma,
    bool clearGlow = false,
    bool clearCornerRadius = false,
    bool clearBeamThickness = false,
    bool clearBlurSigma = false,
  }) =>
      ScanFxTunables(
        intensity: intensity ?? this.intensity,
        speed: speed ?? this.speed,
        glow: clearGlow ? null : (glow ?? this.glow),
        cornerRadius:
            clearCornerRadius ? null : (cornerRadius ?? this.cornerRadius),
        beamThickness:
            clearBeamThickness ? null : (beamThickness ?? this.beamThickness),
        blurSigma: clearBlurSigma ? null : (blurSigma ?? this.blurSigma),
      );

  /// Interpolates between two tunable sets, preserving `null` overrides.
  static ScanFxTunables lerp(ScanFxTunables a, ScanFxTunables b, double t) =>
      ScanFxTunables(
        intensity: _lerp(a.intensity, b.intensity, t),
        speed: _lerp(a.speed, b.speed, t),
        glow: _lerpNullable(a.glow, b.glow, t),
        cornerRadius: _lerpNullable(a.cornerRadius, b.cornerRadius, t),
        beamThickness: _lerpNullable(a.beamThickness, b.beamThickness, t),
        blurSigma: _lerpNullable(a.blurSigma, b.blurSigma, t),
      );

  @override
  bool operator ==(Object other) =>
      other is ScanFxTunables &&
      other.intensity == intensity &&
      other.speed == speed &&
      other.glow == glow &&
      other.cornerRadius == cornerRadius &&
      other.beamThickness == beamThickness &&
      other.blurSigma == blurSigma;

  @override
  int get hashCode => Object.hash(
        intensity,
        speed,
        glow,
        cornerRadius,
        beamThickness,
        blurSigma,
      );

  @override
  String toString() => 'ScanFxTunables(intensity: $intensity, speed: $speed, '
      'glow: $glow, cornerRadius: $cornerRadius, '
      'beamThickness: $beamThickness, blurSigma: $blurSigma)';
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double? _lerpNullable(double? a, double? b, double t) {
  if (a == null && b == null) return null;
  if (a == null) return b;
  if (b == null) return a;
  return _lerp(a, b, t);
}

/// Colour helpers shared by the theme presets, `fromColorScheme` and the
/// contrast guarantees required for banking mode.
abstract final class ScanFxPalette {
  /// WCAG relative luminance of [color], in `0..1`.
  static double relativeLuminance(Color color) {
    double channel(double value) => value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// WCAG contrast ratio between [a] and [b], from `1` (identical) to `21`.
  static double contrastRatio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Returns a colour derived from [foreground] that meets [ratio] against
  /// [background].
  ///
  /// This is what makes the 4.5:1 accessibility guarantee structural rather
  /// than aspirational: themes built through it cannot ship unreadable text or
  /// icon colours.
  static Color ensureContrast(
    Color foreground,
    Color background, {
    double ratio = 4.5,
  }) {
    if (contrastRatio(foreground, background) >= ratio) return foreground;
    final towardsWhite =
        relativeLuminance(background) < relativeLuminance(foreground);
    for (var step = 1; step <= 20; step++) {
      final candidate = Color.lerp(
        foreground,
        towardsWhite ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        step / 20,
      )!;
      if (contrastRatio(candidate, background) >= ratio) return candidate;
    }
    return towardsWhite ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  }

  /// Mixes two colours in linear sRGB space, which avoids the muddy midpoints
  /// that naive alpha blending produces on dark backgrounds.
  static Color mix(Color a, Color b, double t) {
    final tt = t.clamp(0.0, 1.0);
    return Color.from(
      alpha: _mixChannel(a.a, b.a, tt),
      red: _mixChannel(a.r, b.r, tt),
      green: _mixChannel(a.g, b.g, tt),
      blue: _mixChannel(a.b, b.b, tt),
    );
  }

  /// Returns [color] with its alpha replaced. Uses the non-deprecated
  /// `withValues` API so the package stays warning-free.
  static Color withAlpha(Color color, double alpha) =>
      color.withValues(alpha: alpha.clamp(0.0, 1.0));

  /// Multiplies [color]'s alpha by [factor].
  static Color fade(Color color, double factor) =>
      color.withValues(alpha: (color.a * factor).clamp(0.0, 1.0));

  static double _mixChannel(double a, double b, double t) => a + (b - a) * t;
}
