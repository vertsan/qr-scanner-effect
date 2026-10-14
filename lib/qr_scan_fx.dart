/// A premium QR-scanner overlay for Flutter: focus frames, corner brackets,
/// scan beams, a spring-driven lock-on reticle, and success/error effects — all
/// canvas-drawn, all themeable, and all built from small composable layers.
///
/// ### The package is a renderer, not a scanner
///
/// `qr_scan_fx` never owns the camera, never decodes anything, and never sees a
/// QR payload. It accepts **geometry only** — a bounding box or four corner
/// points — and returns pixels. Nothing here reads, stores, logs or transmits
/// decoded content, and there is no API that would let it.
///
/// ### Quick start
///
/// ```dart
/// final controller = QrScanFxController();
///
/// Stack(
///   children: [
///     MobileScanner(
///       onDetect: (capture) {
///         final code = capture.barcodes.firstOrNull;
///         if (code == null) return;
///         final corners = code.corners;
///         controller.lockOn(
///           corners == null
///               ? ScanFxTarget.rect(code.boundingBox!, normalized: true)
///               : ScanFxTarget.corners(corners, normalized: true),
///         );
///         // Your own decoder decides what the code *means*:
///         controller.success();
///       },
///     ),
///     QrScanFx(controller: controller),
///   ],
/// )
/// ```
///
/// ### Learn more
///
/// * [QrScanFx] — the overlay widget, and its declarative mode.
/// * [QrScanFxTheme] — the full visual configuration, plus twelve presets.
/// * [ScanLayerStack] — reorder, hide or replace any layer.
/// * `doc/architecture.md` — layering, performance budget, security boundary.
library;

export 'src/animation/scan_fx_frame.dart' show ScanFxFrame;
export 'src/controller/qr_scan_fx_controller.dart' show QrScanFxController;
export 'src/geometry/scan_fx_quad.dart' show ScanFxQuad;
export 'src/geometry/scan_fx_shapes.dart' show ScanFxShapes;
export 'src/geometry/scan_fx_target.dart' show ScanFxTarget;
export 'src/geometry/scan_geometry_mapper.dart' show ScanGeometryMapper;
export 'src/layers/backdrop/scan_backdrop_layer.dart' show ScanBackdropLayer;
export 'src/layers/beam/scan_beam_layer.dart' show ScanBeamLayer;
export 'src/layers/corners/scan_corner_layer.dart' show ScanCornerLayer;
export 'src/layers/effects/scan_effect_layer.dart'
    show NoEffectLayer, ScanEffectLayer, ScanFaultEffect, ScanSuccessEffect;
export 'src/layers/frame/scan_frame_layer.dart' show ScanFrameLayer;
export 'src/layers/hint/scan_hint_layer.dart' show ScanHintLayer, ScanHintView;
export 'src/layers/idle/scan_fx_idle_modifier.dart'
    show ScanFxIdleModifier, ScanFxIdleTransform;
export 'src/layers/reticle/scan_reticle_layer.dart' show ScanReticleLayer;
export 'src/layers/scan_fx_registry.dart' show ScanFxRegistry;
export 'src/layers/scan_layer.dart' show CustomScanLayer, ScanLayer;
export 'src/layers/scan_layer_stack.dart' show ScanLayerEntry, ScanLayerStack;
export 'src/state/scan_fx_state.dart' show ScanFxState;
export 'src/state/scan_fx_state_machine.dart'
    show ScanFxStateMachine, ScanFxTrigger;
export 'src/theme/qr_scan_fx_theme.dart' show QrScanFxTheme;
export 'src/theme/scan_fx_labels.dart' show ScanFxSemanticsLabels;
export 'src/theme/scan_fx_motion.dart' show ScanFxEasing, ScanFxMotion;
export 'src/theme/scan_fx_recipe.dart' show ScanFxRecipes, ScanPreset;
export 'src/theme/scan_fx_style.dart'
    show
        ScanBackdropOptions,
        ScanBackdropStyle,
        ScanBeamDirection,
        ScanBeamMotion,
        ScanBeamOptions,
        ScanBeamStyle,
        ScanCornerStyle,
        ScanErrorOptions,
        ScanErrorStyle,
        ScanFrameShape,
        ScanIdleStyle,
        ScanLayerKind,
        ScanLockOptions,
        ScanLockStyle,
        ScanSuccessOptions,
        ScanSuccessStyle;
export 'src/theme/scan_fx_tunables.dart' show ScanFxPalette, ScanFxTunables;
export 'src/widget/qr_scan_fx.dart' show QrScanFx, ScanLayersBuilder;
export 'src/widget/scan_fx_status_notice.dart' show ScanFxStatusNotice;
