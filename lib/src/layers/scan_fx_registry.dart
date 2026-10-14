import '../theme/qr_scan_fx_theme.dart';
import '../theme/scan_fx_style.dart';
import 'backdrop/blurred_frost_backdrop.dart';
import 'backdrop/gradient_fade_backdrop.dart';
import 'backdrop/none_backdrop.dart';
import 'backdrop/scan_backdrop_layer.dart';
import 'backdrop/solid_dim_backdrop.dart';
import 'backdrop/vignette_backdrop.dart';
import 'beam/glowing_laser_beam.dart';
import 'beam/line_beam.dart';
import 'beam/scan_beam_layer.dart';
import 'beam/soft_gradient_bar_beam.dart';
import 'corners/dot_corners.dart';
import 'corners/rounded_corners.dart';
import 'corners/scan_corner_layer.dart';
import 'corners/sharp_corners.dart';
import 'effects/error/fade_blink_effect.dart';
import 'effects/error/red_pulse_effect.dart';
import 'effects/error/shake_error_effect.dart';
import 'effects/scan_effect_layer.dart';
import 'effects/success/check_morph_effect.dart';
import 'effects/success/color_wash_effect.dart';
import 'effects/success/glow_flash_effect.dart';
import 'frame/circle_frame.dart';
import 'frame/corners_only_frame.dart';
import 'frame/rounded_square_frame.dart';
import 'frame/scan_frame_layer.dart';
import 'frame/squircle_frame.dart';
import 'hint/scan_hint_layer.dart';
import 'idle/breathing_idle.dart';
import 'idle/floating_idle.dart';
import 'idle/scan_fx_idle_modifier.dart';
import 'idle/shimmer_idle.dart';
import 'idle/still_idle.dart';
import 'reticle/lock_pulse_reticle.dart';
import 'scan_layer.dart';
import 'scan_layer_stack.dart';

/// Maps the style enums onto real layer implementations.
///
/// The registry is the *only* place where an enum value and a class name appear
/// together. That is what makes three promises true at once:
///
/// * every combination of styles is drawable, because every enum has an arm;
/// * a new style is one file plus one arm here;
/// * the overlay never switches on a style at paint time.
///
/// All implementations are built once per stack, and each keeps its own cache, so
/// neither building the stack nor painting a frame allocates in the steady state.
abstract final class ScanFxRegistry {
  /// The frame layer for [shape].
  static ScanFrameLayer frame(ScanFrameShape shape) => switch (shape) {
        ScanFrameShape.roundedSquare => RoundedSquareFrame(),
        ScanFrameShape.squircle => SquircleFrame(),
        ScanFrameShape.circle => CircleFrame(),
        ScanFrameShape.cornersOnly => CornersOnlyFrame(),
      };

  /// The corner-bracket layer for [style].
  static ScanCornerLayer corners(ScanCornerStyle style) => switch (style) {
        ScanCornerStyle.rounded => RoundedCorners(),
        ScanCornerStyle.sharp => SharpCorners(),
        ScanCornerStyle.dot => DotCorners(),
      };

  /// The beam layer for [style].
  static ScanBeamLayer beam(ScanBeamStyle style) => switch (style) {
        ScanBeamStyle.line => LineBeam(),
        ScanBeamStyle.softGradientBar => SoftGradientBarBeam(),
        ScanBeamStyle.glowingLaser => GlowingLaserBeam(),
      };

  /// The backdrop layer for [style].
  static ScanBackdropLayer backdrop(ScanBackdropStyle style) => switch (style) {
        ScanBackdropStyle.solidDim => SolidDimBackdrop(),
        ScanBackdropStyle.blurredFrost => BlurredFrostBackdrop(),
        ScanBackdropStyle.vignette => VignetteBackdrop(),
        ScanBackdropStyle.gradientFade => GradientFadeBackdrop(),
        ScanBackdropStyle.none => NoneBackdrop(),
      };

  /// The lock-on reticle for [style].
  static ScanLayer reticle(ScanLockStyle style) => switch (style) {
        ScanLockStyle.none => NoEffectLayer(ScanLayerKind.reticle),
        ScanLockStyle.springSnap ||
        ScanLockStyle.smoothMorph ||
        ScanLockStyle.zoomIn =>
          LockPulseReticle(),
      };

  /// The success effect for [style].
  static ScanLayer success(ScanSuccessStyle style) => switch (style) {
        ScanSuccessStyle.checkMorph => CheckMorphEffect(),
        ScanSuccessStyle.colorWash => ColorWashEffect(),
        ScanSuccessStyle.glowFlash => GlowFlashEffect(),
        ScanSuccessStyle.none => NoEffectLayer(ScanLayerKind.effects),
      };

  /// The fault effect for [style].
  ///
  /// One layer covers both the `error` and `invalid` states: the effect is
  /// identical, only the colour differs, and the colour comes from the frame.
  static ScanLayer error(ScanErrorStyle style) => switch (style) {
        ScanErrorStyle.shake => ShakeErrorEffect(),
        ScanErrorStyle.redPulse => RedPulseEffect(),
        ScanErrorStyle.fadeBlink => FadeBlinkEffect(),
        ScanErrorStyle.none => NoEffectLayer(ScanLayerKind.effects),
      };

  /// The idle-motion modifier for [style].
  static ScanFxIdleModifier idleModifier(ScanIdleStyle style) =>
      switch (style) {
        ScanIdleStyle.breathing => BreathingIdle(),
        ScanIdleStyle.floating => FloatingIdle(),
        ScanIdleStyle.shimmer => ShimmerIdle(),
        ScanIdleStyle.still => StillIdle(),
      };

  /// The default layer stack for [theme], in paint order.
  ///
  /// The order is the answer to "what is in front of what": the backdrop is
  /// furthest back (so the cutout dims the preview), then everything that traces
  /// the scan area, then the two burst slots, then the widget-level hint, which
  /// floats above the lot.
  static ScanLayerStack buildStack(QrScanFxTheme theme) =>
      ScanLayerStack.of(<ScanLayer>[
        backdrop(theme.backdropStyle),
        frame(theme.frameShape),
        corners(theme.cornerStyle),
        beam(theme.beamStyle),
        reticle(theme.lockStyle),
        success(theme.successStyle),
        error(theme.errorStyle),
        ScanHintLayer(),
      ]);
}
