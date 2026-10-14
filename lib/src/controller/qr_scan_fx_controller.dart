import 'package:flutter/foundation.dart';

import '../animation/scan_fx_director.dart';
import '../geometry/scan_fx_target.dart';
import '../state/scan_fx_state.dart';
import '../state/scan_fx_state_machine.dart';
import '../theme/scan_fx_tunables.dart';

/// The imperative handle for a `QrScanFx` overlay.
///
/// A controller is a [ChangeNotifier] **and** a `ValueListenable<ScanFxState>`,
/// so it works with both `AnimatedBuilder` and `ValueListenableBuilder`:
///
/// ```dart
/// final controller = QrScanFxController();
///
/// // From your camera plugin's detection callback:
/// controller.lockOn(ScanFxTarget.corners(barcode.corners, normalized: true));
/// ```
///
/// ### What this class deliberately does not do
///
/// There is no method here that accepts, stores, or forwards decoded QR text.
/// The only string this controller will ever hold is host-supplied UI copy
/// passed to [error] or [invalid], and it is never logged, persisted, or
/// transmitted. The package cannot leak a payload it never receives — see
/// `doc/architecture.md`, "Security boundary".
class QrScanFxController extends ChangeNotifier
    implements ValueListenable<ScanFxState> {
  /// Creates a controller.
  ///
  /// [initialState] lets a host open the overlay already scanning; [autoLock]
  /// mirrors [ScanFxStateMachine.autoLock]; [tunables] sets the initial live
  /// tuning values.
  QrScanFxController({
    ScanFxState initialState = ScanFxState.idle,
    this.autoLock = true,
    ScanFxTunables? tunables,
  })  : _machine = ScanFxStateMachine(
          initial: initialState,
          autoLock: autoLock,
        ),
        _state = initialState,
        _tunables = ValueNotifier<ScanFxTunables>(
          tunables ?? ScanFxTunables.defaults,
        );

  /// Whether the state machine promotes [ScanFxState.detected] to
  /// [ScanFxState.locked] automatically after the hold window.
  final bool autoLock;

  final ScanFxStateMachine _machine;
  final ValueNotifier<ScanFxTunables> _tunables;
  final ValueNotifier<double> _focus = ValueNotifier<double>(0);
  final ValueNotifier<bool> _paused = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _message = ValueNotifier<String?>(null);

  ScanFxState _state;
  ScanFxTarget? _target;
  ScanFxDirector? _director;

  @override
  ScanFxState get value => _state;

  /// Lock-on progress, `0` while scanning and `1` when settled on a target.
  ///
  /// Useful for hosts that want to drive their own chrome from the same spring.
  ValueListenable<double> get focus => _focus;

  /// Whether the overlay is paused.
  ValueListenable<bool> get isPaused => _paused;

  /// Host-supplied copy for the last [error] or [invalid] call, if any.
  ///
  /// This is the *only* string the package holds, and it is never logged.
  ValueListenable<String?> get message => _message;

  /// The live tuning values.
  ScanFxTunables get tunables => _tunables.value;

  /// A listenable for the live tuning values, for hosts that want to rebuild
  /// only when tuning changes.
  ValueListenable<ScanFxTunables> get tunablesListenable => _tunables;

  /// The most recent target, or `null` when nothing is tracked.
  ScanFxTarget? get target => _target;

  /// Whether a target is currently tracked.
  bool get hasTarget => _target != null;

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Focuses the overlay on a detected target, with spring physics.
  ///
  /// Calling this repeatedly with fresh geometry is the intended usage: the
  /// spring is seeded from its current value and velocity, so a target that
  /// moves every frame tracks smoothly instead of snapping.
  void lockOn(ScanFxTarget target) {
    _target = target;
    _director?.onTargetChanged(target);
    if (_machine.state == ScanFxState.idle) {
      _fire(ScanFxTrigger.start);
    }
    _fire(ScanFxTrigger.targetDetected);
  }

  /// Starts a scan session without a target.
  void start() => _fire(ScanFxTrigger.start);

  /// Reports a successful read.
  ///
  /// In banking mode this means "the code was scanned" and never "the payment
  /// succeeded" — the package does not know, and must not imply, the latter.
  void success() {
    _message.value = null;
    _fire(ScanFxTrigger.succeed);
  }

  /// Reports a failed read, with optional host copy for the overlay.
  void error([String? message]) {
    _message.value = message;
    _fire(ScanFxTrigger.fail);
  }

  /// Reports a code the host refuses to accept (unsupported schema, expired,
  /// a merchant mismatch), with optional host copy.
  void invalid([String? message]) {
    _message.value = message;
    _fire(ScanFxTrigger.invalidate);
  }

  /// Clears the target and returns to scanning.
  void reset() {
    _target = null;
    _message.value = null;
    _director?.onTargetChanged(null);
    _fire(ScanFxTrigger.reset);
  }

  /// Freezes all motion, keeping the last painted frame.
  ///
  /// Use this when the app is backgrounded or when the camera preview is
  /// obscured; the ticker stops entirely, so a paused overlay costs nothing.
  void pause() {
    if (_paused.value) return;
    _paused.value = true;
    _director?.pause();
  }

  /// Resumes after [pause].
  void resume() {
    if (!_paused.value) return;
    _paused.value = false;
    _director?.resume();
  }

  /// Replaces the live tuning values.
  ///
  /// The change is picked up on the next frame and **never** resets the
  /// animation: a speed change rescales the remaining distance rather than
  /// restarting it.
  void setTunables(ScanFxTunables tunables) {
    _tunables.value = tunables;
  }

  /// Forces a state, bypassing the transition table.
  ///
  /// Used by the declarative `QrScanFx(state: ...)` mode. Prefer the semantic
  /// methods ([lockOn], [success], [error], [invalid], [reset]) everywhere else.
  void applyDeclaredState(ScanFxState state) {
    if (state == _state) return;
    final before = _machine.state;
    _machine.jumpTo(state);
    _state = state;
    notifyListeners();
    _director?.onStateChanged(before, state);
  }

  // ---------------------------------------------------------------------------
  // Wiring used by the overlay
  // ---------------------------------------------------------------------------

  /// Attaches the animation core. Called by the overlay widget.
  void attachDirector(ScanFxDirector director) {
    _director = director;
    if (director.isPaused != _paused.value) {
      _paused.value = director.isPaused;
    }
  }

  /// Detaches the animation core. Called by the overlay widget on dispose.
  void detachDirector() => _director = null;

  /// Updates the published lock-on progress. Called by the animation core.
  void updateFocus(double focus) => _focus.value = focus;

  /// Signals that the `detected` hold window elapsed. Called by the core.
  void notifyLockHoldElapsed() => _fire(ScanFxTrigger.lockHoldElapsed);

  bool _fire(ScanFxTrigger trigger) {
    final before = _machine.state;
    final after = _machine.fire(trigger);
    if (after == before) return false;
    _state = after;
    notifyListeners();
    _director?.onStateChanged(before, after);
    return true;
  }

  @override
  void dispose() {
    _director = null;
    _focus.dispose();
    _paused.dispose();
    _message.dispose();
    _tunables.dispose();
    super.dispose();
  }
}
