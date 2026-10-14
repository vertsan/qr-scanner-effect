import 'qr_scan_fx_theme.dart';
import 'scan_fx_style.dart';

/// A one-line look, combining a palette with a matching set of styles.
///
/// A preset is deliberately *not* a theme: it is a named opinion about which
/// palette, frame, corners, beam and lock-on belong together. That is why
/// [ScanFxRecipes.theme] can return a fully-typed [QrScanFxTheme] for each one
/// while still being allowed to pick styles no single theme constant would.
///
/// Use them through the widget, which is the one-liner:
///
/// ```dart
/// QrScanFx.preset(ScanPreset.cyberpunk, controller: controller)
/// ```
///
/// Every preset is a starting point, not a cage — read it back with
/// [ScanFxRecipes.theme] and `copyWith` whatever you disagree with.
enum ScanPreset {
  /// Electric cyan and violet, a glitched lock-on and a hard-edged beam.
  cyberpunk,

  /// Soft, lens-like and calm: a continuous-corner frame over a follow-spot,
  /// with brackets alone doing the framing.
  appleVision,

  /// Reassuring and neutral: bank-blue, a soft beam and a critically damped
  /// lock-on. The safe default for anything involving money.
  minimalBank,

  /// Green phosphor, a straight-edged frame and a scanline sweep. Retro-future
  /// without the neon bloom.
  retroLaser,

  /// Warm, rounded and friendly, with capsule corners and confetti on success.
  playfulPop,
}

/// Resolves a [ScanPreset] into a complete theme.
///
/// Keeping the mapping in one place means `QrScanFx.preset` is a two-line
/// factory, and a host who wants the look without the widget is one call away
/// from the same theme.
abstract final class ScanFxRecipes {
  /// The theme for [preset].
  static QrScanFxTheme theme(ScanPreset preset) => switch (preset) {
        ScanPreset.cyberpunk => QrScanFxTheme.neonCyber,
        ScanPreset.appleVision => QrScanFxTheme.monoGlass.copyWith(
            frameShape: ScanFrameShape.squircle,
            cornerStyle: ScanCornerStyle.rounded,
            beamStyle: ScanBeamStyle.softGradientBar,
            backdropStyle: ScanBackdropStyle.spotlight,
            lockStyle: ScanLockStyle.smoothMorph,
            successStyle: ScanSuccessStyle.glowFlash,
            errorStyle: ScanErrorStyle.fadeBlink,
            cornerRadius: 34,
          ),
        ScanPreset.minimalBank => QrScanFxTheme.bankingBlue,
        ScanPreset.retroLaser => QrScanFxTheme.matrixGreen.copyWith(
            frameShape: ScanFrameShape.fullBorder,
            cornerStyle: ScanCornerStyle.sharp,
            beamStyle: ScanBeamStyle.line,
            lockStyle: ScanLockStyle.scanlineSweepOver,
            successStyle: ScanSuccessStyle.cornersFlash,
            errorStyle: ScanErrorStyle.glitch,
          ),
        ScanPreset.playfulPop => QrScanFxTheme.roseGold.copyWith(
            cornerStyle: ScanCornerStyle.pill,
            beamStyle: ScanBeamStyle.pulseRings,
            lockStyle: ScanLockStyle.particleBurst,
            successStyle: ScanSuccessStyle.confetti,
            errorStyle: ScanErrorStyle.crossMorph,
          ),
      };
}
