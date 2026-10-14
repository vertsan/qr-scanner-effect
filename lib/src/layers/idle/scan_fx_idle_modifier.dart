import 'dart:ui' show Offset;

import '../../theme/scan_fx_style.dart';

/// The result of an idle-motion style for one frame.
///
/// Idle styles are *modifiers*, not layers: they transform the shared quad
/// before any layer reads it. That is what makes every idle style compose with
/// every frame style, and what keeps a `circle` frame from fighting a
/// `breathing` idle.
class ScanFxIdleTransform {
  /// Creates a transform. The default is the identity.
  const ScanFxIdleTransform({
    this.scale = 0,
    this.offset = Offset.zero,
    this.shimmer = 0,
  });

  /// Uniform scale delta applied about the quad's centre.
  final double scale;

  /// Translation applied to the quad.
  final Offset offset;

  /// Specular highlight position, `0..1`, for [ScanIdleStyle.shimmer].
  final double shimmer;

  /// The identity transform.
  static const ScanFxIdleTransform none = ScanFxIdleTransform();
}

/// Computes an [ScanFxIdleTransform] from ambient time.
///
/// Implementations must be pure and allocation-free.
abstract class ScanFxIdleModifier {
  /// Const constructor so modifiers can be cached in the registry.
  const ScanFxIdleModifier();

  /// The transform for [ambientSeconds] of accumulated ambient time.
  ScanFxIdleTransform transform(double ambientSeconds);
}
