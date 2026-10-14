import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'scan_fx_idle_modifier.dart';

/// Drifts the frame vertically by a few pixels, as if the viewfinder were
/// floating. Slower and larger than [BreathingIdle], so pair it with a thin
/// frame rather than a heavy one.
class FloatingIdle extends ScanFxIdleModifier {
  /// Creates the modifier.
  const FloatingIdle();

  /// One full drift cycle, in milliseconds.
  static const double periodMs = 5200;

  /// Peak vertical displacement, in logical pixels.
  static const double amplitude = 3;

  @override
  ScanFxIdleTransform transform(double ambientSeconds) {
    final phase = (ambientSeconds * 1000 / periodMs) % 1;
    return ScanFxIdleTransform(
      offset: Offset(0, amplitude * math.sin(2 * math.pi * phase)),
    );
  }
}
