import 'dart:math' as math;

import '../../animation/scan_fx_frame.dart';
import 'scan_corner_layer.dart';

/// Bracket arms with a forced wide bloom.
///
/// The brackets keep the base geometry and simply refuse to be dim: the glow is
/// clamped to a minimum, so the corners stay luminous even on a theme that has
/// dialled bloom down. That makes this the style to reach for when the overlay
/// sits over a busy or bright camera preview.
class GlowingCorners extends ScanCornerLayer {
  /// Creates the style.
  GlowingCorners();

  /// The glow strength this style will not fall below.
  static const double minGlow = 0.5;

  @override
  double glowFor(ScanFxFrame frame) => math.max(frame.glow, minGlow);
}
