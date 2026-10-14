import 'scan_fx_state.dart';

/// Inputs that can move a [ScanFxStateMachine] between states.
///
/// Triggers are host- or timer-driven; the machine itself performs no timing.
enum ScanFxTrigger {
  /// A scan session started.
  start,

  /// A target quad became available (or changed).
  targetDetected,

  /// The hold window for the [ScanFxState.detected] state elapsed.
  lockHoldElapsed,

  /// The read succeeded.
  succeed,

  /// The read failed.
  fail,

  /// The read produced an unacceptable code.
  invalidate,

  /// The host asked to return to scanning.
  reset,
}

/// A small, dependency-free state machine for scanner overlays.
///
/// The machine is deliberately pure Dart with no Flutter imports so it can be
/// unit tested without pumping widgets. Illegal transitions are *ignored* and
/// leave the state untouched, which keeps a noisy detection source from ever
/// throwing inside a host app's frame callback.
///
/// ```dart
/// final machine = ScanFxStateMachine();
/// machine.fire(ScanFxTrigger.start);
/// machine.fire(ScanFxTrigger.targetDetected);
/// machine.fire(ScanFxTrigger.lockHoldElapsed); // -> ScanFxState.locked
/// ```
class ScanFxStateMachine {
  /// Creates a machine, optionally starting in a non-idle state.
  ScanFxStateMachine({
    ScanFxState initial = ScanFxState.idle,
    this.autoLock = true,
  }) : _state = initial;

  /// Whether [ScanFxTrigger.lockHoldElapsed] promotes [ScanFxState.detected]
  /// into [ScanFxState.locked].
  ///
  /// When `false`, [ScanFxState.detected] is sticky and the host drives the
  /// transition to [ScanFxState.locked] implicitly through `success`/`error`.
  final bool autoLock;

  ScanFxState _state;

  /// The current state.
  ScanFxState get state => _state;

  /// Returns the state that [trigger] would produce **without** committing it.
  ScanFxState resolve(ScanFxTrigger trigger) {
    final next = resolveTransition(_state, trigger, autoLock: autoLock);
    return next ?? _state;
  }

  /// Whether [trigger] would change the current state.
  bool canFire(ScanFxTrigger trigger) => resolve(trigger) != _state;

  /// Applies [trigger] and returns the (possibly unchanged) resulting state.
  ScanFxState fire(ScanFxTrigger trigger) {
    _state = resolve(trigger);
    return _state;
  }

  /// Forces the state, bypassing the transition table.
  ///
  /// Used by tests and by the declarative `QrScanFx(state: ...)` mode. Prefer
  /// [fire] everywhere else.
  void jumpTo(ScanFxState state) => _state = state;

  /// The transition table: `(from, trigger) -> to`, or `null` when the
  /// transition is not legal.
  ///
  /// Keeping the table in one place documents the whole lifecycle and makes it
  /// cheap to test exhaustively.
  static ScanFxState? resolveTransition(
    ScanFxState from,
    ScanFxTrigger trigger, {
    bool autoLock = true,
  }) {
    switch (trigger) {
      case ScanFxTrigger.start:
        return from == ScanFxState.idle || from.isTerminal
            ? ScanFxState.scanning
            : null;
      case ScanFxTrigger.targetDetected:
        return switch (from) {
          ScanFxState.idle || ScanFxState.scanning => ScanFxState.detected,
          // A repeat detection while already tracking only refreshes geometry.
          // It must *not* restart the hold timer, because a detector that fires
          // thirty times a second would then never let `detected` settle into
          // `locked` and the lock-on animation would never complete.
          ScanFxState.detected || ScanFxState.locked => from,
          // A fresh target after a burst starts the cycle over.
          ScanFxState.success ||
          ScanFxState.error ||
          ScanFxState.invalid =>
            ScanFxState.detected,
        };
      case ScanFxTrigger.lockHoldElapsed:
        if (from != ScanFxState.detected || !autoLock) return null;
        return ScanFxState.locked;
      case ScanFxTrigger.succeed:
        return _fromTracked(from, ScanFxState.success);
      case ScanFxTrigger.fail:
        return _fromTracked(from, ScanFxState.error);
      case ScanFxTrigger.invalidate:
        return _fromTracked(from, ScanFxState.invalid);
      case ScanFxTrigger.reset:
        return switch (from) {
          ScanFxState.idle => ScanFxState.idle,
          ScanFxState.scanning ||
          ScanFxState.detected ||
          ScanFxState.locked ||
          ScanFxState.success ||
          ScanFxState.error ||
          ScanFxState.invalid =>
            ScanFxState.scanning,
        };
    }
  }

  static ScanFxState? _fromTracked(ScanFxState from, ScanFxState to) {
    return switch (from) {
      ScanFxState.scanning || ScanFxState.detected || ScanFxState.locked => to,
      // A terminal state may be overwritten (e.g. a second code read fails).
      ScanFxState.success || ScanFxState.error || ScanFxState.invalid => to,
      ScanFxState.idle => null,
    };
  }
}
