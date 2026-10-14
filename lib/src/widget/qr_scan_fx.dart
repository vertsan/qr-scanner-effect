import 'package:flutter/material.dart';

import '../animation/scan_fx_director.dart';
import '../controller/qr_scan_fx_controller.dart';
import '../geometry/scan_fx_target.dart';
import '../layers/scan_fx_registry.dart';
import '../layers/scan_layer_painter.dart';
import '../layers/scan_layer_stack.dart';
import '../state/scan_fx_state.dart';
import '../theme/qr_scan_fx_theme.dart';
import '../theme/scan_fx_tunables.dart';

/// Lets a host reorder, hide, replace or extend the default layer stack.
///
/// Called on every rebuild with the stack the theme produced, and must return the
/// stack to paint. Returning the same instances keeps every layer's paint cache
/// warm; returning fresh layers simply costs one geometry rebuild on the next
/// frame.
typedef ScanLayersBuilder = ScanLayerStack Function(
  BuildContext context,
  ScanLayerStack stack,
);

/// The QR scanner overlay.
///
/// `QrScanFx` draws a focus effect over whatever the host puts behind it — the
/// package never owns the camera, never decodes anything, and never sees QR
/// content. It receives **geometry only** and returns pixels.
///
/// ```dart
/// Stack(
///   children: [
///     MobileScanner(controller: camera, onDetect: (capture) {
///       final code = capture.barcodes.firstOrNull;
///       final corners = code?.corners;
///       controller.lockOn(corners == null
///           ? ScanFxTarget.rect(code!.boundingBox!, normalized: true)
///           : ScanFxTarget.corners(corners, normalized: true));
///     }),
///     QrScanFx(controller: controller),
///   ],
/// )
/// ```
///
/// ### Two ways to drive it
///
/// * **Imperative** — pass a [controller] and call `lockOn`, `success`, `error`,
///   `invalid` and `reset` from wherever detections arrive. This is the right
///   choice for a real camera: geometry changes many times a second and the
///   spring tracks it continuously.
/// * **Declarative** — pass `state`, and optionally [detectedBounds] or
///   [detectedCorners], and let the widget do the calling. This is the right
///   choice for tests, previews and screenshots.
///
/// Both can be combined: [state] stays authoritative while the geometry inputs
/// keep the quad tracking. A *repeated* detection never restarts the lock-on
/// hold, so an overlay driven from a 30 fps detector still reaches `locked`.
///
/// ### What it costs
///
/// Exactly one [Ticker] for the whole overlay and exactly one [CustomPaint].
/// Layers read a shared immutable frame snapshot, so a tick repaints without
/// rebuilding a single widget. The ticker stops whenever nothing is moving, in
/// every terminal state, and while [QrScanFxController.pause] is in effect.
class QrScanFx extends StatefulWidget {
  /// Creates an overlay.
  const QrScanFx({
    super.key,
    this.controller,
    this.state,
    this.detectedBounds,
    this.detectedCorners,
    this.normalized = false,
    this.flipX = false,
    this.flipY = false,
    this.quarterTurns = 0,
    this.scanAreaSize,
    this.sensorSize,
    this.previewFit = BoxFit.cover,
    this.theme,
    this.tunables,
    this.autoLock = true,
    this.layers,
    this.onStateChanged,
    this.child,
  }) : assert(
          quarterTurns >= 0 && quarterTurns < 4,
          'quarterTurns must be 0..3',
        );

  /// The imperative handle. When omitted the widget creates and owns one.
  final QrScanFxController? controller;

  /// Forces a lifecycle state. When non-null it is authoritative.
  ///
  /// Setting it back to `null` leaves the overlay wherever the controller last
  /// was; the declarative mode never silently resets.
  final ScanFxState? state;

  /// A detected target as an axis-aligned box, in sensor space.
  final Rect? detectedBounds;

  /// A detected target as four corners, in sensor space.
  ///
  /// Corners allow rotated and perspective-skewed codes to be framed exactly,
  /// which is most of the reason the lock-on animation exists.
  final List<Offset>? detectedCorners;

  /// Whether [detectedBounds] and [detectedCorners] are normalized `0..1`
  /// against the sensor frame.
  final bool normalized;

  /// Mirrors detection geometry horizontally (front-camera previews).
  final bool flipX;

  /// Mirrors detection geometry vertically.
  final bool flipY;

  /// Rotates detection geometry by this many clockwise quarter turns.
  final int quarterTurns;

  /// A fixed scan area size. When `null` the overlay picks a comfortable
  /// fraction of its own size.
  final Size? scanAreaSize;

  /// The resolution of the camera frame that produced the detections.
  ///
  /// Supplying it (together with [previewFit]) is what keeps the overlay aligned
  /// with a cropped preview. When omitted, detection coordinates are treated as
  /// already living in overlay space.
  final Size? sensorSize;

  /// How the preview is fitted into the overlay. Must match the host's preview
  /// widget or the frame will be offset. Defaults to [BoxFit.cover].
  final BoxFit previewFit;

  /// An explicit theme. Falls back to the ambient [QrScanFxTheme] extension, then
  /// to [QrScanFxTheme.dark] or [QrScanFxTheme.light] by brightness.
  final QrScanFxTheme? theme;

  /// Live tuning values, equivalent to writing to the controller.
  final ScanFxTunables? tunables;

  /// Whether an overlay that owns its own controller should auto-promote
  /// `detected` to `locked`. Ignored when a [controller] is supplied.
  final bool autoLock;

  /// A hook for reordering, hiding, replacing or extending the layer stack.
  final ScanLayersBuilder? layers;

  /// Called whenever the lifecycle state changes.
  final ValueChanged<ScanFxState>? onStateChanged;

  /// The camera preview (or any other widget) to draw the overlay on top of.
  ///
  /// When `null` the overlay renders standalone over whatever is behind it,
  /// which is what lets it be screenshot-tested without a camera.
  final Widget? child;

  @override
  State<QrScanFx> createState() => _QrScanFxState();
}

class _QrScanFxState extends State<QrScanFx>
    with SingleTickerProviderStateMixin {
  late QrScanFxController _controller;
  bool _ownsController = false;
  bool _reporting = false;

  ScanFxDirector? _director;
  TextDirection _textDirection = TextDirection.ltr;
  ScanFxState? _lastReportedState;
  bool _tunablesSeeded = false;

  ScanLayerStack? _baseStack;
  QrScanFxTheme? _baseStackTheme;

  ScanFxDirector get _core => _director!;

  @override
  void initState() {
    super.initState();
    final provided = widget.controller;
    _controller = provided ?? QrScanFxController(autoLock: widget.autoLock);

    // The initial geometry and declared state are applied *before* the listener
    // is attached, so opening an overlay already in a declared state does not
    // fire a spurious `onStateChanged` or an announcement.
    _syncTargets(null);
    _syncDeclaredState(null);
    _lastReportedState = _controller.value;
    _controller.addListener(_handleControllerChanged);
    _reporting = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _director ??= ScanFxDirector(
      vsync: this,
      controller: _controller,
      theme: _resolveTheme(context),
    );
    _controller.attachDirector(_core);

    if (_ownsController && !_tunablesSeeded) {
      _tunablesSeeded = true;
      final seed = widget.tunables ?? _resolveTheme(context).tunables;
      if (seed != _controller.tunables) _controller.setTunables(seed);
    }
  }

  @override
  void didUpdateWidget(QrScanFx oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      _detachController();
      final provided = widget.controller;
      _controller = provided ?? QrScanFxController(autoLock: widget.autoLock);
      _tunablesSeeded = false;
      _director?.dispose();
      _director = ScanFxDirector(
        vsync: this,
        controller: _controller,
        theme: _resolveTheme(context),
      );
      _controller.attachDirector(_core);
      _syncTargets(null);
      _syncDeclaredState(null);
      _lastReportedState = _controller.value;
      _controller.addListener(_handleControllerChanged);
      return;
    }

    if (widget.tunables != null && widget.tunables != oldWidget.tunables) {
      _controller.setTunables(widget.tunables!);
    }
    _syncTargets(oldWidget);
    _syncDeclaredState(oldWidget);
  }

  @override
  void dispose() {
    _detachController();
    _director?.dispose();
    _director = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------------------------

  void _syncTargets(QrScanFx? old) {
    if (old != null &&
        old.detectedBounds == widget.detectedBounds &&
        identical(old.detectedCorners, widget.detectedCorners) &&
        old.normalized == widget.normalized &&
        old.flipX == widget.flipX &&
        old.flipY == widget.flipY &&
        old.quarterTurns == widget.quarterTurns) {
      return;
    }

    final corners = widget.detectedCorners;
    if (corners != null && corners.length == 4) {
      _controller.lockOn(
        ScanFxTarget.corners(
          corners,
          normalized: widget.normalized,
          flipX: widget.flipX,
          flipY: widget.flipY,
          quarterTurns: widget.quarterTurns,
        ),
      );
      return;
    }

    final bounds = widget.detectedBounds;
    if (bounds != null) {
      _controller.lockOn(
        ScanFxTarget.rect(
          bounds,
          normalized: widget.normalized,
          flipX: widget.flipX,
          flipY: widget.flipY,
          quarterTurns: widget.quarterTurns,
        ),
      );
      return;
    }

    // Nothing is tracked. In declarative mode the declared state decides what
    // that means, so only an imperative overlay resets itself.
    if (widget.state == null) _controller.reset();
  }

  void _syncDeclaredState(QrScanFx? old) {
    final declared = widget.state;
    if (declared == null) return;
    if (old != null && old.state == declared) return;
    _controller.applyDeclaredState(declared);
  }

  // ---------------------------------------------------------------------------
  // Wiring
  // ---------------------------------------------------------------------------

  void _detachController() {
    _reporting = false;
    _controller.removeListener(_handleControllerChanged);
    _controller.detachDirector();
    if (_ownsController) _controller.dispose();
    _ownsController = false;
  }

  // ---------------------------------------------------------------------------
  // State reporting
  // ---------------------------------------------------------------------------

  void _handleControllerChanged() {
    if (!_reporting) return;
    final state = _controller.value;
    if (state == _lastReportedState) return;
    _lastReportedState = state;
    widget.onStateChanged?.call(state);
    // The geometry animates through the painter, which the director drives
    // without touching the widget tree. Only the *state* has widget-level
    // consequences — the semantics label (which is what announces the state) and
    // the hint overlay — so only the state triggers a rebuild. That happens a
    // handful of times per scan, never per frame.
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Resolution
  // ---------------------------------------------------------------------------

  /// The registry stack for [theme], built once per distinct theme.
  ///
  /// Keeping the instances alive across rebuilds is what makes the layers' paint
  /// caches worth having: a rebuild that does not change the theme reuses the
  /// exact same objects, so `updateMetrics` sees no change and no path is
  /// rebuilt.
  ScanLayerStack _baseStackFor(QrScanFxTheme theme) {
    final cached = _baseStack;
    if (cached != null && _baseStackTheme == theme) return cached;
    final built = ScanFxRegistry.buildStack(theme);
    _baseStack = built;
    _baseStackTheme = theme;
    return built;
  }

  QrScanFxTheme _resolveTheme(BuildContext context) {
    final ambient = Theme.of(context);
    final base = widget.theme ??
        ambient.extension<QrScanFxTheme>() ??
        (ambient.brightness == Brightness.dark
            ? QrScanFxTheme.dark
            : QrScanFxTheme.light);
    final tunables = _controller.tunables;
    return tunables == base.tunables ? base : base.copyWith(tunables: tunables);
  }

  @override
  Widget build(BuildContext context) {
    _textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final theme = _resolveTheme(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final baseStack = _baseStackFor(theme);
    final stack = widget.layers?.call(context, baseStack) ?? baseStack;

    return LayoutBuilder(
      builder: (context, constraints) {
        final raw = constraints.biggest;
        final size = Size(
          raw.width.isFinite ? raw.width : 0,
          raw.height.isFinite ? raw.height : 0,
        );

        _core.updateMetrics(
          size: size,
          textDirection: _textDirection,
          reduceMotion: reduceMotion,
          theme: theme,
          stack: stack,
          scanAreaSize: widget.scanAreaSize,
          sensorSize: widget.sensorSize,
          previewFit: widget.previewFit,
        );
        final frame = _core.frameFor(size);

        // The lifecycle state is exposed as a live region rather than through an
        // imperative announcement: Flutter's own guidance is to let `Semantics`
        // trigger announcements implicitly, which is also the only variant that
        // behaves on Android and across multiple windows. `detected` and `locked`
        // share wording, so the 140 ms hold does not double-speak.
        return Semantics(
          container: true,
          liveRegion: true,
          label: theme.labels.labelFor(frame.state),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              if (widget.child != null) widget.child!,
              ...stack.buildUnderlays(context, frame),
              RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  willChange: stack.hasAnimatedLayers,
                  painter: ScanLayerPainter(director: _core, stack: stack),
                ),
              ),
              ...stack.buildOverlays(context, frame),
            ],
          ),
        );
      },
    );
  }
}
