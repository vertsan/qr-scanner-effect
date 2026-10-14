import 'dart:ui' show Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../../theme/scan_fx_style.dart';
import '../scan_layer.dart';

/// The iOS-style continuous corner.
///
/// A superellipse is sampled rather than approximated with arcs, so the
/// straight edges and the corners blend continuously. The exponent is part of
/// the theme ([QrScanFxTheme.squircleExponent]); `4` matches the platform
/// continuous corner closely, and higher values square it up further.
class SquircleFrame extends ScanFrameLayer {
  /// Creates the style.
  const SquircleFrame();

  @override
  Path buildOutline(ScanFxFrame frame) => ScanFxShapes.superellipse(
        frame.quad.bounds,
        exponent: frame.theme.squircleExponent,
      );
}

/// A circle inscribed in the scan area.
///
/// Reads as a lens or a shutter, which suits camera-forward UIs. Pair it with
/// [ScanCornerStyle.dot] and [ScanBeamDirection.radial] for a full "radar"
/// look.
class CircleFrame extends ScanFrameLayer {
  /// Creates the style.
  const CircleFrame();

  @override
  Path buildOutline(ScanFxFrame frame) =>
      ScanFxShapes.oval(frame.quad.bounds);
}

/// Draws no outline at all, leaving the corner brackets to describe the frame.
///
/// This is a real style, not an omission: many premium scanners frame a code
/// with brackets alone. The layer keeps its slot in the stack so hosts can
/// still address `ScanLayerKind.frame` when restyling.
class CornersOnlyFrame extends ScanLayer {
  /// Creates the style.
  const CornersOnlyFrame();

  @override
  ScanLayerKind get kind => ScanLayerKind.frame;

  @override
  bool get animated => false;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {}
}
