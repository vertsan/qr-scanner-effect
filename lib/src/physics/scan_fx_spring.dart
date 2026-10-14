import 'package:flutter/physics.dart';

/// A single, spring-driven animated scalar.
///
/// `AnimationController` clamps its value to `0..1`, which silently destroys the
/// overshoot that makes a lock-on feel alive. This class drives
/// [SpringSimulation] directly so the value may exceed its target, and it can be
/// **re-seeded from the current value and velocity** — the property that lets a
/// mid-flight `lockOn()` continue smoothly instead of snapping back.
///
/// Instances are allocated once (owned by the animation director) and mutated in
/// place, so ticking never allocates.
class ScanFxSpringValue {
  /// Creates a spring value resting at [value].
  ScanFxSpringValue({
    required this.description,
    double value = 0,
  })  : _value = value,
        _restValue = value;

  /// The spring used for the next [animateTo] when no override is supplied.
  SpringDescription description;

  double _value;
  double _restValue;
  double _velocity = 0;
  double _elapsedSeconds = 0;
  double? _target;
  SpringSimulation? _simulation;

  /// The current value. May overshoot the target by design.
  double get value => _value;

  /// The current rate of change, in units per second.
  double get velocity => _velocity;

  /// The value this spring is heading towards, or `null` when at rest.
  double? get target => _target;

  /// Whether the spring is still moving.
  bool get isAnimating => _simulation != null;

  /// Snaps to [value] and stops all motion. Used on construction and on reset
  /// paths that must not animate.
  void jumpTo(double value) {
    _value = value;
    _restValue = value;
    _velocity = 0;
    _elapsedSeconds = 0;
    _target = null;
    _simulation = null;
  }

  /// Starts a spring towards [target].
  ///
  /// The simulation is seeded with the current value *and* the current velocity,
  /// so retargeting mid-flight is continuous. [description] overrides the stored
  /// spring for this run only.
  void animateTo(
    double target, {
    SpringDescription? description,
    double? velocity,
  }) {
    final spring = description ?? this.description;
    if (spring != this.description) this.description = spring;
    if (_simulation != null && _target == target && _velocity == 0) return;

    _target = target;
    _velocity = velocity ?? _velocity;
    _elapsedSeconds = 0;
    _simulation = SpringSimulation(spring, _value, target, _velocity);
    if (_simulation!.isDone(0)) {
      _value = target;
      _velocity = 0;
      _target = null;
      _simulation = null;
    }
  }

  /// Advances the spring by [dt] seconds.
  ///
  /// Returns `true` while the spring is still animating.
  bool tick(double dt) {
    final simulation = _simulation;
    if (simulation == null) return false;

    _elapsedSeconds += dt;
    _value = simulation.x(_elapsedSeconds);
    _velocity = simulation.dx(_elapsedSeconds);

    if (simulation.isDone(_elapsedSeconds)) {
      _value = _target ?? _restValue;
      _restValue = _value;
      _velocity = 0;
      _target = null;
      _simulation = null;
      return false;
    }
    return true;
  }
}
