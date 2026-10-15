// The scanner screen's look: a neutral, near-black room for the camera, plus the
// `qr_scan_fx` theme that draws the reference's four-bracket frame.
//
// The palette is deliberately neutral — black and charcoal, as the reference
// asks — rather than the blue-tinted `AppTheme` surfaces. The accent and text
// colours are still taken from `AppTheme`, so the screen stays part of the same
// app without inventing a second brand. All copy here is English.

import 'package:flutter/material.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

import '../theme.dart';

/// Colors, metrics and the overlay theme used by the scanner screen.
abstract final class ScannerStyle {
  // ---------------------------------------------------------------------------
  // Palette
  // ---------------------------------------------------------------------------

  /// The page behind the preview: pure black, as the reference asks.
  static const Color background = Color(0xFF000000);

  /// Resting fill of a pill action button.
  static const Color pill = Color(0xFF1C1C1E);

  /// Hairline around a resting pill.
  static const Color pillBorder = Color(0xFF2E2E30);

  /// Fill of a pill in its active state — the flashlight is on.
  static const Color pillActive = AppTheme.accent;

  /// Content on [pillActive].
  static const Color onPillActive = AppTheme.onAccent;

  /// Content on a resting pill.
  static const Color onPill = Color(0xFFFFFFFF);

  /// Content on a control that cannot be used right now.
  static const Color onDisabled = Color(0x66FFFFFF);

  /// Fill of one payment-provider tile.
  static const Color providerTile = Color(0xFF141416);

  /// Hairline around a payment-provider tile.
  static const Color providerTileBorder = Color(0xFF28282A);

  /// Label inside a payment-provider tile.
  static const Color providerLabel = Color(0xFFE6E6E8);

  /// The small caption above the provider grid.
  static const Color caption = AppTheme.onSurfaceVariant;

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------

  /// Radius of the preview's rounded bottom corners.
  static const double previewRadius = 28;

  /// Side margin of the preview card. Small, so the preview reads as nearly
  /// full-width.
  static const double previewInset = 8;

  /// Height of a pill action button. Comfortably past the 48 dp touch target.
  static const double pillHeight = 52;

  /// Horizontal margin shared by everything below the preview.
  static const double gutter = 20;

  /// The largest the scan frame will grow.
  static const double frameMaxSide = 330;

  /// A frame this small no longer reads as a scanner.
  static const double frameFloor = 120;

  /// Space kept clear below the frame for the hint pill and the status notice.
  static const double frameFootroom = 140;

  /// Height reserved for a payment-provider tile.
  static const double providerTileHeight = 36;

  /// Width reserved for a payment-provider tile, so labels and logos line up.
  static const double providerTileWidth = 84;

  // ---------------------------------------------------------------------------
  // Overlay theme
  // ---------------------------------------------------------------------------

  /// A minimal white scanner: four corner brackets and no frame outline, with a
  /// soft white sweep.
  ///
  /// `cornersOnly` is the reference's frame — the camera is never boxed in. The
  /// wording stays neutral everywhere: this app reads codes, it never claims a
  /// payment.
  static const QrScanFxTheme overlay = QrScanFxTheme(
    frameColor: Color(0xFFFFFFFF),
    frameGlowColor: Color(0xFFBBD4FF),
    cornerColor: Color(0xFFFFFFFF),
    beamColor: Color(0xFFD8E6FF),
    beamAccentColor: Color(0xFFFFFFFF),
    backdropColor: Color(0xFF000000),
    successColor: AppTheme.positive,
    errorColor: AppTheme.negative,
    invalidColor: Color(0xFFFFC24B),
    hintBackgroundColor: Color(0xB30B1220),
    hintTextColor: Color(0xFFF2F6FC),
    glowStrength: 0.18,
    frameShape: ScanFrameShape.cornersOnly,
    cornerStyle: ScanCornerStyle.rounded,
    cornerRadius: 24,
    cornerStrokeWidth: 4.5,
    cornerArmFraction: 0.2,
    backdropStyle: ScanBackdropStyle.solidDim,
    backdrop: ScanBackdropOptions(
      dimOpacity: 0.44,
      deepenedOpacity: 0.56,
      feather: 24,
    ),
    beamStyle: ScanBeamStyle.softGradientBar,
    lockStyle: ScanLockStyle.smoothMorph,
    successStyle: ScanSuccessStyle.colorWash,
    errorStyle: ScanErrorStyle.fadeBlink,
    idleStyle: ScanIdleStyle.breathing,
    hintTextStyle: TextStyle(
      color: Color(0xFFF2F6FC),
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.25,
    ),
    labels: ScanFxSemanticsLabels(
      scanning: 'Scanning for a QR code',
    ),
  );
}
