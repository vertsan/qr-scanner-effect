import 'scan_fx_idle_modifier.dart';

/// Sweeps a specular highlight across the frame.
///
/// The modifier only publishes the highlight position; the frame layer decides
/// how to draw it. This keeps `shimmer` composable with any frame shape.
class ShimmerIdle extends ScanFxIdleModifier {
  /// Creates the modifier.
  const ShimmerIdle();

  /// One full sweep, in milliseconds.
  static const double periodMs = 2400;

  @override
  ScanFxIdleTransform transform(double ambientSeconds) {
    final phase = (ambientSeconds * 1000 / periodMs) % 1;
    return ScanFxIdleTransform(shimmer: phase);
  }
}
