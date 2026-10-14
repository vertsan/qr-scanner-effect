import 'dart:ui' show Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_shapes.dart';
import 'scan_frame_layer.dart';

/// A rounded rectangle that follows the target's rotation.
///
/// Because the outline is built from the quad itself rather than from its
/// bounding box, a code held at an angle is framed tightly instead of being
/// enclosed in a loose axis-aligned box.
class RoundedSquareFrame extends ScanFrameLayer {
  /// Creates the style.
  RoundedSquareFrame();

  @override
  Path buildOutline(ScanFxFrame frame) =>
      ScanFxShapes.roundedQuad(frame.quad, frame.cornerRadius);
}
