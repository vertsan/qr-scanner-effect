import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart' show SpringDescription;
import 'package:flutter/scheduler.dart' show Ticker, TickerProvider;
import 'package:flutter/widgets.dart'
    show BoxFit, Offset, Rect, Size, TextDirection;

import '../controller/qr_scan_fx_controller.dart';
import '../geometry/scan_fx_quad.dart';
import '../geometry/scan_fx_target.dart';
import '../geometry/scan_geometry_mapper.dart';
import '../layers/idle/scan_fx_idle_modifier.dart';
import '../layers/scan_fx_registry.dart';
import '../layers/scan_layer_stack.dart';
import '../physics/scan_fx_spring.dart';
import '../physics/scan_fx_timed_value.dart';
import '../state/scan_fx_state.dart';
import '../theme/qr_scan_fx_theme.dart';
import '../theme/scan_fx_motion.dart';
import '../theme/scan_fx_style.dart';
import 'scan_fx_frame.dart';

/// The animation core: one [Ticker], one frame snapshot, no widget rebuilds.
///
/// The director is created by the `QrScanFx` state and lives for as long as the
/// overlay does. It owns a small, fixed set of animated values — never one per
/// layer — and it stops its ticker the moment nothing is moving, which is what
/// keeps an idle scanner at zero cost.
///
/// Everything a layer can read is funnelled into a single [ScanFxFrame] built by
/// [frameFor]. Layers never see the springs, the ticker, or the raw timings.
class ScanFxDirector extends ChangeNotifier {
  /// Creates a director. Called by the widget state, never by host apps.
  ScanFxDirector({
    required TickerProvider vsync,
    required this.controller,
    required QrScanFxTheme theme,
  })  : _theme = theme,
        _idle = ScanFxRegistry.idleModifier(theme.idleStyle),
        _focus = ScanFxSpringValue(
          description: theme.lockSpring,
        ),
        _beamSpan = ScanFxTimedValue(value: 1),
        _breath = ScanFxTimedValue(value: 1),
        _dim = ScanFxTimedValue(value: 0),
        _feedback = ScanFxTimedValue(value: 0),
        _pulse = ScanFxTimedValue(value: 1),
        _hint = ScanFxTimedValue(value: 0),
        _reveal = ScanFxTimedValue(value: 1),
        _hold = ScanFxTimedValue(value: 0) {
    _ticker = vsync.createTicker(_onTick);
    _applyState(controller.value, controller.value, animate: false);
  }

  /// The controller this director animates.
  final QrScanFxController controller;

  late final Ticker _ticker;

  QrScanFxTheme _theme;
  ScanFxIdleModifier _idle;
  ScanLayerStack _stack = const ScanLayerStack(<ScanLayerEntry>[]);

  final ScanFxSpringValue _focus;
  final ScanFxTimedValue _beamSpan;
  final ScanFxTimedValue _breath;
  final ScanFxTimedValue _dim;
  final ScanFxTimedValue _feedback;
  final ScanFxTimedValue _pulse;
  final ScanFxTimedValue _hint;
  final ScanFxTimedValue _reveal;
  final ScanFxTimedValue _hold;

  ScanFxMotion? _cachedMotion;

  ScanFxTarget? _target;
  ScanFxQuad? _lockedQuad;
  ScanFxQuad? _defaultQuad;

  Size _size = Size.zero;
  Size? _scanAreaSize;
  Size? _sensorSize;
  BoxFit _previewFit = BoxFit.cover;
  TextDirection _textDirection = TextDirection.ltr;
  bool _reduceMotion = false;
  bool _paused = false;
  bool _holdArmed = false;

  Duration _lastTick = Duration.zero;
  double _ambientSeconds = 0;
  ScanFxFrame? _frame;
  bool _frameDirty = true;
  int _revision = 0;

  /// Monotonic counter bumped whenever anything a layer reads changes.
  ///
  /// Painters capture it at construction time and use it in `shouldRepaint`,
  /// which is how a metric change (size, theme, direction) triggers a repaint
  /// while an unchanged rebuild does not.
  int get revision => _revision;

  /// Whether the overlay is currently paused.
  bool get isPaused => _paused;

  /// Whether the ticker is running. Exposed for tests and the Style Studio.
  bool get isTicking => _ticker.isActive;

  /// Whether reduce-motion is in effect.
  bool get reduceMotion => _reduceMotion;

  /// The motion spec after speed and reduce-motion are applied.
  ScanFxMotion get _motion => _cachedMotion ??= _theme.motion.scale(
        speedMultiplier: _theme.tunables.speed,
        reduceMotion: _reduceMotion,
      );

  // ---------------------------------------------------------------------------
  // Commands from the controller
  // ---------------------------------------------------------------------------

  /// Called by the controller after the state machine commits a change.
  void onStateChanged(ScanFxState from, ScanFxState to) =>
      _applyState(from, to, animate: true);

  /// Called by the controller after the target geometry changed.
  void onTargetChanged(ScanFxTarget? target) {
    _target = target;
    _rebuildLockedQuad();
    _frameDirty = true;
    _revision++;
    final state = controller.value;
    if (target != null &&
        (state == ScanFxState.detected ||
            state == ScanFxState.locked ||
            state.isTerminal)) {
      // Seeded from the current value and velocity, so a target that moves
      // while the spring is mid-flight continues instead of snapping.
      _focus.animateTo(1, description: _theme.lockSpring);
    }
    _syncTicker();
  }

  /// Stops all motion and freezes the last painted frame.
  void pause() {
    _paused = true;
    _syncTicker();
  }

  /// Resumes after [pause].
  void resume() {
    _paused = false;
    _syncTicker();
  }

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------

  /// Updates the layout and configuration the director animates against.
  ///
  /// Safe to call from `build`: it never notifies listeners synchronously. The
  /// frame is rebuilt lazily by [frameFor] and the repaint is triggered through
  /// [revision].
  void updateMetrics({
    required Size size,
    required TextDirection textDirection,
    required bool reduceMotion,
    required QrScanFxTheme theme,
    required ScanLayerStack stack,
    Size? scanAreaSize,
    Size? sensorSize,
    BoxFit previewFit = BoxFit.cover,
  }) {
    var changed = false;

    if (theme != _theme) {
      _theme = theme;
      _cachedMotion = null;
      _idle = ScanFxRegistry.idleModifier(theme.idleStyle);
      changed = true;
    }
    if (!identical(stack, _stack) && stack != _stack) {
      _stack = stack;
      changed = true;
    }
    if (textDirection != _textDirection) {
      _textDirection = textDirection;
      changed = true;
    }
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _cachedMotion = null;
      changed = true;
    }
    if (size != _size) {
      _size = size;
      _defaultQuad = null;
      // The overlay may have had no size at all when the target arrived (the
      // controller is often driven from a detection callback that fires before
      // the first layout), so the locked quad has to be re-mapped here too.
      _rebuildLockedQuad();
      changed = true;
    }
    if (scanAreaSize != _scanAreaSize) {
      _scanAreaSize = scanAreaSize;
      _defaultQuad = null;
      changed = true;
    }
    if (sensorSize != _sensorSize || previewFit != _previewFit) {
      _sensorSize = sensorSize;
      _previewFit = previewFit;
      _rebuildLockedQuad();
      changed = true;
    }
    if (changed) {
      _frameDirty = true;
      _revision++;
      _syncTicker();
    }
  }

  // ---------------------------------------------------------------------------
  // Frame production
  // ---------------------------------------------------------------------------

  /// Returns the frame for [size], rebuilding it only when something changed.
  ///
  /// The returned object is reused between ticks; layers must treat it as
  /// read-only.
  ScanFxFrame frameFor(Size size) {
    if (size != _size) {
      _size = size;
      _defaultQuad = null;
      _rebuildLockedQuad();
      _frameDirty = true;
      _revision++;
      _syncTicker();
    }
    if (_frame == null || _frameDirty) {
      _frame = _buildFrame();
      _frameDirty = false;
    }
    return _frame!;
  }

  ScanFxFrame _buildFrame() {
    final theme = _theme;
    final defaultQuad = _defaultQuad ??= _computeDefaultQuad();
    final lockedQuad = _lockedQuad;

    var quad = lockedQuad == null
        ? defaultQuad
        : ScanFxQuad.lerp(defaultQuad, lockedQuad, _focus.value);

    // cornerFollow < 1 relaxes the quad towards its axis-aligned bounding box,
    // which reads as calmer on rotated targets (used by banking mode).
    final follow = theme.lock.cornerFollow.clamp(0.0, 1.0);
    if (follow < 1 && lockedQuad != null) {
      quad = ScanFxQuad.lerp(ScanFxQuad.fromRect(quad.bounds), quad, follow);
    }

    final idle = _idle.transform(_ambientSeconds);
    final breath = _breath.value;
    final idleScale = 1 + idle.scale * breath;
    final idleOffset = idle.offset * breath;
    if (idleScale != 1 || idleOffset != Offset.zero) {
      quad = quad.scaleAbout(quad.center, idleScale).translate(idleOffset);
    }

    final shake = _currentShake();
    if (shake != Offset.zero) {
      quad = quad.translate(shake);
    }

    return ScanFxFrame(
      size: _size,
      state: controller.value,
      theme: theme,
      ambientSeconds: _ambientSeconds,
      focus: _focus.value.clamp(0.0, 1.0),
      focusRaw: _focus.value,
      beamSpan: _beamSpan.value,
      breath: breath,
      dim: _dim.value,
      feedback: _feedback.value.clamp(0.0, 1.0),
      pulse: _pulse.value.clamp(0.0, 1.0),
      hint: _hint.value.clamp(0.0, 1.0),
      reveal: _reveal.value.clamp(0.0, 1.0),
      shake: shake,
      quad: quad,
      defaultQuad: defaultQuad,
      lockedQuad: lockedQuad,
      idleScale: idleScale,
      idleOffset: idleOffset,
      shimmer: idle.shimmer * breath,
      reduceMotion: _reduceMotion,
      textDirection: _textDirection,
      revision: _revision,
    );
  }

  /// The shake displacement for the current state and style.
  ///
  /// Only [ScanErrorStyle.shake] moves geometry; the other error styles are
  /// pure overlays, so the frame stays rock steady for them.
  Offset _currentShake() {
    if (controller.value != ScanFxState.error) return Offset.zero;
    if (_theme.errorStyle != ScanErrorStyle.shake) return Offset.zero;
    return ScanFxFrame.shakeFor(
      _feedback.value,
      _motion,
      _theme.error.shakeAmplitude * _theme.tunables.intensity,
    );
  }

  ScanFxQuad _computeDefaultQuad() {
    final requested = _scanAreaSize;
    final maxSide = math.min(_size.width, _size.height) * 0.82;
    final width = requested != null
        ? math.min(requested.width, maxSide)
        : math.min(_size.width * 0.68, maxSide);
    final height = requested != null
        ? math.min(requested.height, maxSide)
        : math.min(_size.height * 0.68, maxSide);
    return ScanFxQuad.fromRect(
      Rect.fromCenter(
        center: Offset(_size.width / 2, _size.height / 2),
        width: math.max(width, 24),
        height: math.max(height, 24),
      ),
    );
  }

  void _rebuildLockedQuad() {
    final target = _target;
    if (target == null) {
      _lockedQuad = null;
      return;
    }
    final overlay = _size;
    if (overlay.isEmpty) {
      _lockedQuad = null;
      return;
    }
    // With no sensor size supplied, detection coordinates are treated as
    // already living in overlay space: an identity mapping.
    final mapper = ScanGeometryMapper(
      sensorSize: _sensorSize ?? overlay,
      overlaySize: overlay,
      fit: _previewFit,
    );
    final quad = mapper.map(target);
    if (quad == null) {
      _lockedQuad = null;
      return;
    }
    final padding = _theme.lock.padding * _theme.tunables.intensity;
    _lockedQuad = quad
        .inflateAlongNormals(padding)
        .fitInside((Offset.zero & overlay).deflate(4));
  }

  // ---------------------------------------------------------------------------
  // State application
  // ---------------------------------------------------------------------------

  void _applyState(ScanFxState from, ScanFxState to, {required bool animate}) {
    final m = _motion;

    void spring(
        ScanFxSpringValue value, double target, SpringDescription spring) {
      if (animate) {
        value.animateTo(target, description: spring);
      } else {
        value.description = spring;
        value.jumpTo(target);
      }
    }

    void timed(
      ScanFxTimedValue value,
      double target,
      Duration duration,
      Curve curve,
    ) {
      if (animate) {
        value.animateTo(target, duration: m.effective(duration), curve: curve);
      } else {
        value.jumpTo(target);
      }
    }

    switch (to) {
      case ScanFxState.idle:
      case ScanFxState.scanning:
        spring(_focus, 0, m.effectiveResetSpring);
        timed(_beamSpan, 1, m.beamRetract, ScanFxEasing.converge);
        timed(_breath, 1, m.breathFade, ScanFxEasing.ambient);
        timed(_dim, 0, m.backdropDeepen, ScanFxEasing.ambient);
        timed(_feedback, 0, m.colorBlend, ScanFxEasing.wash);
        timed(_hint, 1, m.hint, ScanFxEasing.start);
        timed(
          _reveal,
          to == ScanFxState.idle ? 0.35 : 1,
          m.start,
          ScanFxEasing.start,
        );
        _holdArmed = false;

      case ScanFxState.detected:
        spring(_focus, 1, _theme.lockSpring);
        timed(_beamSpan, 0.15, m.beamRetract, ScanFxEasing.converge);
        timed(_breath, 0, m.breathFade, ScanFxEasing.ambient);
        timed(_dim, 1, m.backdropDeepen, ScanFxEasing.ambient);
        timed(_hint, 0, m.hint, ScanFxEasing.release);
        timed(_reveal, 1, m.start, ScanFxEasing.start);
        _pulse.jumpTo(0);
        // The hold is what gives a noisy 30 fps detector a stable window, so it
        // runs under reduce-motion too — a scanner that never reaches `locked`
        // is not "calmer", it is broken. Reduce-motion simply caps the hold at
        // [ScanFxMotion.microFade] instead of animating it, and `active` stays
        // true for that one tick so the state machine is still advanced.
        _holdArmed = controller.autoLock;
        if (_holdArmed) {
          _hold.jumpTo(0);
          _hold.animateTo(
            1,
            duration: m.effective(m.lockHold),
            curve: Curves.linear,
          );
        } else {
          _hold.jumpTo(1);
        }

      case ScanFxState.locked:
        spring(_focus, 1, _theme.lockSpring);
        timed(_beamSpan, 0, m.beamRetract, ScanFxEasing.converge);
        timed(_dim, 1, m.backdropDeepen, ScanFxEasing.ambient);
        timed(_hint, 0, m.hint, ScanFxEasing.release);
        _holdArmed = false;
        // The pulse is a timed `0..1` progress rather than a spring: layers ease
        // it themselves and stop drawing the moment it reaches `1`, which is what
        // makes the ring free once it has landed. `lockConverge` is the window it
        // shares with the bracket convergence.
        if (_reduceMotion) {
          _pulse.jumpTo(1);
        } else {
          _pulse.jumpTo(0);
          _pulse.animateTo(
            1,
            duration: _theme.lock.pulseStrength > 0
                ? m.effective(m.lockConverge)
                : Duration.zero,
            curve: Curves.linear,
          );
        }

      case ScanFxState.success:
      case ScanFxState.error:
      case ScanFxState.invalid:
        final burst = switch (to) {
          ScanFxState.success => m.success,
          ScanFxState.error => m.error,
          _ => m.invalid,
        };
        if (_reduceMotion) {
          // Reduce motion keeps the *result*, not the animation: the effect
          // lands immediately and stays put.
          _feedback.jumpTo(1);
        } else if (animate) {
          _feedback.jumpTo(0);
          _feedback.animateTo(1,
              duration: m.effective(burst), curve: Curves.linear);
        } else {
          _feedback.jumpTo(1);
        }
        timed(_beamSpan, 0, m.beamRetract, ScanFxEasing.converge);
        timed(_dim, 1, m.colorBlend, ScanFxEasing.ambient);
        timed(_hint, 0, m.hint, ScanFxEasing.release);
        spring(_focus, 1, m.effectiveLockSpring);
        _pulse.jumpTo(1);
        _holdArmed = false;
    }

    _frameDirty = true;
    _revision++;
    _syncTicker();
  }

  // ---------------------------------------------------------------------------
  // Ticker
  // ---------------------------------------------------------------------------

  bool get _ambientEnabled =>
      !_reduceMotion &&
      !controller.value.isTerminal &&
      _stack.hasAnimatedLayers;

  bool get _needsTick =>
      _ambientEnabled ||
      _focus.isAnimating ||
      _beamSpan.isAnimating ||
      _breath.isAnimating ||
      _dim.isAnimating ||
      _feedback.isAnimating ||
      _pulse.isAnimating ||
      _hint.isAnimating ||
      _reveal.isAnimating ||
      _hold.isAnimating;

  void _syncTicker() {
    final shouldTick = _needsTick && !_paused;
    if (shouldTick && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!shouldTick && _ticker.isActive) {
      _ticker.stop();
      _lastTick = Duration.zero;
    }
  }

  void _onTick(Duration elapsed) {
    final rawDt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // A stalled frame (debugger, app switch) must not teleport the animation.
    final dt = rawDt.clamp(0.0, 0.05);

    _ambientSeconds += dt * _theme.tunables.speed;

    _focus.tick(dt);
    _beamSpan.tick(dt);
    _breath.tick(dt);
    _dim.tick(dt);
    _feedback.tick(dt);
    _pulse.tick(dt);
    _hint.tick(dt);
    _reveal.tick(dt);

    if (_hold.isAnimating) {
      final running = _hold.tick(dt);
      if (!running && _holdArmed) {
        _holdArmed = false;
        controller.notifyLockHoldElapsed();
      }
    }

    _publishFocus();
    _frameDirty = true;
    _revision++;
    notifyListeners();
    _syncTicker();
  }

  double _lastPublishedFocus = -1;

  void _publishFocus() {
    final clamped = _focus.value.clamp(0.0, 1.0);
    final settled = !_focus.isAnimating;
    // While a spring is running, publish at a coarse resolution: hosts that
    // drive chrome from `focus` do not need 120 notifications per second.
    if (!settled && (clamped - _lastPublishedFocus).abs() < 0.002) return;
    if (settled && clamped == _lastPublishedFocus) return;
    _lastPublishedFocus = clamped;
    controller.updateFocus(clamped);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
