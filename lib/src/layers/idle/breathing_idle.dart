import 'dart:math' as math;

import 'scan_fx_idle_modifier.dart';

/// Gently scales the frame and its glow in and out — the "alive but calm"
/// default.
///
/// A period of 3600 ms with a 1.2 % amplitude reads as breathing rather than
/// pulsing, and stops the moment a target is detected because the director
/// fades the amplitude to zero.
class BreathingIdle extends ScanFxIdleModifier {
  /// Creates the modifier.
  const BreathingIdle();

  /// One full breath, in milliseconds.
  static const double periodMs = 3600;

  /// Peak scale deviation.
  static const double amplitude = 0.012;

  @override
  ScanFxIdleTransform transform(double ambientSeconds) {
    final phase = (ambientSeconds * 1000 / periodMs) % 1;
    return ScanFxIdleTransform(
      scale: amplitude * math.sin(2 * math.pi * phase),
    );
  }
}
