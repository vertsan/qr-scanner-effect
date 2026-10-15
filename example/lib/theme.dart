// One calm banking look for the example screens.
//
// A near-black palette with a single blue accent, so the UI sits comfortably
// over a dark camera preview and matches the `banking` preset of the overlay.
// Everything here is English — the example ships one language and does not carry
// a second.

import 'package:flutter/material.dart';

/// The example's shared colors and [ThemeData].
abstract final class AppTheme {
  /// Page background.
  static const Color bg = Color(0xFF05080F);

  /// Card and sheet background.
  static const Color surface = Color(0xFF0B1220);

  /// Raised surfaces: fields, selected rows, snackbars.
  static const Color surfaceHigh = Color(0xFF13253C);

  /// Hairlines: borders, dividers, field outlines.
  static const Color outline = Color(0xFF1E3A5F);

  /// The single accent: primary actions and the selected tint.
  static const Color accent = Color(0xFF7CB0FF);

  /// Text on [accent].
  static const Color onAccent = Color(0xFF04213F);

  /// Tinted surface for a selected accent element.
  static const Color accentContainer = Color(0xFF14345C);

  /// Text on [accentContainer].
  static const Color onAccentContainer = Color(0xFFD6E6FF);

  /// Primary text.
  static const Color onSurface = Color(0xFFF2F6FC);

  /// Secondary text.
  static const Color onSurfaceVariant = Color(0xFF9FB3CC);

  /// Success.
  static const Color positive = Color(0xFF34D399);

  /// Fault.
  static const Color negative = Color(0xFFF98A8A);

  /// Builds the shared [ThemeData].
  ///
  /// Only stable, version-proof fields are set here; widgets style the rest
  /// explicitly so the palette stays in one place without depending on the exact
  /// shape of every `*ThemeData` class.
  static ThemeData data() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
    );
  }
}
