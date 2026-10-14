import 'package:flutter/animation.dart' show Curve, Curves;

/// A simple eased transition between two values, driven by `dt`.
///
/// Where [ScanFxSpringValue] gives motion its weight, this gives it its *timing*
/// — the cross-fades, beam retracts and progress fills that should land exactly
/// when the motion spec says they do. It is mutable and allocation-free when
/// ticked.
class ScanFxTimedValue {
  /// Creates a timed value resting at [value].
  ScanFxTimedValue({double value = 0}) : _value = value;

  double _value;
  double _from = 0;
  double _to = 0;
  double _elapsedSeconds = 0;
  double _durationSeconds = 0;
  Curve _curve = Curves.linear;
  bool _active = false;

  /// The current eased value.
  double get value => _value;

  /// Whether the transition is still running.
  bool get isAnimating => _active;

  /// The value this transition is heading towards.
  double get target => _to;

  /// The 0..1 progress of the current transition.
  double get progress => _durationSeconds <= 0
      ? 1
      : (_elapsedSeconds / _durationSeconds).clamp(0, 1);

  /// Snaps to [value] and stops.
  void jumpTo(double value) {
    _value = value;
    _from = value;
    _to = value;
    _active = false;
    _elapsedSeconds = 0;
    _durationSeconds = 0;
  }

  /// Starts an eased transition towards [to].
  ///
  /// A [Duration.zero] (or a negative duration) snaps immediately, which is how
  /// reduce-motion keeps the same code path with no animation.
  void animateTo(
    double to, {
    Duration duration = Duration.zero,
    Curve curve = Curves.linear,
  }) {
    if (_active && _to == to) return;
    if (duration <= Duration.zero) {
      jumpTo(to);
      return;
    }
    _from = _value;
    _to = to;
    _curve = curve;
    _elapsedSeconds = 0;
    _durationSeconds = duration.inMicroseconds / 1e6;
    _active = true;
  }

  /// Advances by [dt] seconds and returns `true` while still animating.
  bool tick(double dt) {
    if (!_active) return false;
    _elapsedSeconds += dt;
    final t = progress;
    _value = _from + (_to - _from) * _curve.transform(t);
    if (t >= 1) {
      _value = _to;
      _active = false;
      return false;
    }
    return true;
  }
}
