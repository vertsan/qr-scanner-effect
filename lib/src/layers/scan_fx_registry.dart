import '../theme/qr_scan_fx_theme.dart';
import '../theme/scan_fx_style.dart';
import 'backdrop/blurred_frost_backdrop.dart';
import 'backdrop/gradient_fade_backdrop.dart';
import 'backdrop/none_backdrop.dart';
import 'backdrop/scan_backdrop_layer.dart';
import 'backdrop/solid_dim_backdrop.dart';
import 'backdrop/spotlight_backdrop.dart';
import 'backdrop/vignette_backdrop.dart';
import 'beam/aurora_beam.dart';
import 'beam/dot_matrix_beam.dart';
import 'beam/double_laser_beam.dart';
import 'beam/glowing_laser_beam.dart';
import 'beam/grid_scan_beam.dart';
import 'beam/line_beam.dart';
import 'beam/none_beam.dart';
import 'beam/pulse_rings_beam.dart';
import 'beam/radar_beam.dart';
import 'beam/scan_beam_layer.dart';
import 'beam/soft_gradient_bar_beam.dart';
import 'beam/waveform_beam.dart';
import 'corners/animated_draw_corners.dart';
import 'corners/chamfered_corners.dart';
import 'corners/dot_corners.dart';
import 'corners/double_line_corners.dart';
import 'corners/glowing_corners.dart';
import 'corners/pill_corners.dart';
import 'corners/rounded_corners.dart';
import 'corners/scan_corner_layer.dart';
import 'corners/sharp_corners.dart';
import 'effects/error/cross_morph_effect.dart';
import 'effects/error/fade_blink_effect.dart';
import 'effects/error/glitch_effect.dart';
import 'effects/error/red_pulse_effect.dart';
import 'effects/error/shake_error_effect.dart';
import 'effects/scan_effect_layer.dart';
import 'effects/success/check_morph_effect.dart';
import 'effects/success/color_wash_effect.dart';
import 'effects/success/confetti_effect.dart';
import 'effects/success/corners_flash_effect.dart';
import 'effects/success/glow_flash_effect.dart';
import 'effects/success/ripple_waves_effect.dart';
import 'frame/circle_frame.dart';
import 'frame/corners_only_frame.dart';
import 'frame/dashed_border_frame.dart';
import 'frame/diamond_frame.dart';
import 'frame/full_border_frame.dart';
import 'frame/hexagon_frame.dart';
import 'frame/rounded_square_frame.dart';
import 'frame/scan_frame_layer.dart';
import 'frame/squircle_frame.dart';
import 'frame/viewfinder_cross_frame.dart';
import 'hint/scan_hint_layer.dart';
import 'idle/breathing_idle.dart';
import 'idle/floating_idle.dart';
import 'idle/scan_fx_idle_modifier.dart';
import 'idle/shimmer_idle.dart';
import 'idle/still_idle.dart';
import 'reticle/focus_bracket_reticle.dart';
import 'reticle/glitch_lock_reticle.dart';
import 'reticle/morph_reticle.dart';
import 'reticle/particle_burst_reticle.dart';
import 'reticle/pulse_lock_reticle.dart';
import 'reticle/ring_contract_reticle.dart';
import 'reticle/scan_reticle_layer.dart';
import 'reticle/scanline_sweep_over_reticle.dart';
import 'reticle/zoom_reticle.dart';
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
        ScanFrameShape.hexagon => HexagonFrame(),
        ScanFrameShape.diamond => DiamondFrame(),
        ScanFrameShape.fullBorder => FullBorderFrame(),
        ScanFrameShape.dashedBorder => DashedBorderFrame(),
        ScanFrameShape.viewfinderCross => ViewfinderCrossFrame(),
      };

  /// The corner-bracket layer for [style].
  static ScanCornerLayer corners(ScanCornerStyle style) => switch (style) {
        ScanCornerStyle.rounded => RoundedCorners(),
        ScanCornerStyle.sharp => SharpCorners(),
        ScanCornerStyle.dot => DotCorners(),
        ScanCornerStyle.chamfered => ChamferedCorners(),
        ScanCornerStyle.pill => PillCorners(),
        ScanCornerStyle.doubleLine => DoubleLineCorners(),
        ScanCornerStyle.glowing => GlowingCorners(),
        ScanCornerStyle.animatedDraw => AnimatedDrawCorners(),
      };

  /// The beam layer for [style].
  static ScanBeamLayer beam(ScanBeamStyle style) => switch (style) {
        ScanBeamStyle.line => LineBeam(),
        ScanBeamStyle.softGradientBar => SoftGradientBarBeam(),
        ScanBeamStyle.glowingLaser => GlowingLaserBeam(),
        ScanBeamStyle.doubleLaser => DoubleLaserBeam(),
        ScanBeamStyle.radar => RadarBeam(),
        ScanBeamStyle.gridScan => GridScanBeam(),
        ScanBeamStyle.dotMatrix => DotMatrixBeam(),
        ScanBeamStyle.waveform => WaveformBeam(),
        ScanBeamStyle.pulseRings => PulseRingsBeam(),
        ScanBeamStyle.aurora => AuroraBeam(),
        ScanBeamStyle.none => NoneBeam(),
      };

  /// The backdrop layer for [style].
  static ScanBackdropLayer backdrop(ScanBackdropStyle style) => switch (style) {
        ScanBackdropStyle.solidDim => SolidDimBackdrop(),
        ScanBackdropStyle.blurredFrost => BlurredFrostBackdrop(),
        ScanBackdropStyle.vignette => VignetteBackdrop(),
        ScanBackdropStyle.gradientFade => GradientFadeBackdrop(),
        ScanBackdropStyle.spotlight => SpotlightBackdrop(),
        ScanBackdropStyle.none => NoneBackdrop(),
      };

  /// The lock-on reticle for [style].
  ///
  /// The style picks the *focus flourish* — the thing that moves while the
  /// spring is in flight. The confirmation ring that plays once the lock
  /// settles is not a style: every reticle draws it, through
  /// [ScanReticleLayer].
  static ScanLayer reticle(ScanLockStyle style) => switch (style) {
        ScanLockStyle.springSnap => FocusBracketReticle(),
        ScanLockStyle.smoothMorph => MorphReticle(),
        ScanLockStyle.zoomIn => ZoomReticle(),
        ScanLockStyle.pulseLock => PulseLockReticle(),
        ScanLockStyle.ringContract => RingContractReticle(),
        ScanLockStyle.scanlineSweepOver => ScanlineSweepOverReticle(),
        ScanLockStyle.particleBurst => ParticleBurstReticle(),
        ScanLockStyle.glitchLock => GlitchLockReticle(),
        ScanLockStyle.none => NoEffectLayer(ScanLayerKind.reticle),
      };

  /// The success effect for [style].
  static ScanLayer success(ScanSuccessStyle style) => switch (style) {
        ScanSuccessStyle.checkMorph => CheckMorphEffect(),
        ScanSuccessStyle.colorWash => ColorWashEffect(),
        ScanSuccessStyle.glowFlash => GlowFlashEffect(),
        ScanSuccessStyle.rippleWaves => RippleWavesEffect(),
        ScanSuccessStyle.confetti => ConfettiEffect(),
        ScanSuccessStyle.cornersFlash => CornersFlashEffect(),
        ScanSuccessStyle.none => NoEffectLayer(ScanLayerKind.success),
      };

  /// The fault effect for [style].
  ///
  /// One layer covers both the `error` and `invalid` states: the effect is
  /// identical, only the colour differs, and the colour comes from the frame.
  /// Styles that would be a lie on an invalid read soften themselves — see
  /// [GlitchEffect] and [ShakeErrorEffect].
  static ScanLayer error(ScanErrorStyle style) => switch (style) {
        ScanErrorStyle.shake => ShakeErrorEffect(),
        ScanErrorStyle.redPulse => RedPulseEffect(),
        ScanErrorStyle.fadeBlink => FadeBlinkEffect(),
        ScanErrorStyle.glitch => GlitchEffect(),
        ScanErrorStyle.crossMorph => CrossMorphEffect(),
        ScanErrorStyle.none => NoEffectLayer(ScanLayerKind.error),
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
