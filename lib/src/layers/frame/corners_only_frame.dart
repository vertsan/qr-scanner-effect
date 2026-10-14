import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_style.dart';
import 'scan_frame_layer.dart';

/// Draws no outline at all, leaving the corner brackets to describe the frame.
///
/// This is a real style rather than an omission: many premium scanners frame a
/// code with brackets alone. The layer keeps its slot in the stack, so hosts can
/// still address `ScanLayerKind.frame` when restyling, and it reports
/// [animated] as `false` because it contributes no pixels.
///
/// The backdrop cutout still follows the configured corner radius, so turning
/// the outline off does not change where the dim ends — only what is drawn on
/// top of it.
class CornersOnlyFrame extends ScanFrameLayer {
  /// Creates the style.
  CornersOnlyFrame();

  @override
  ScanFrameShape get shape => ScanFrameShape.cornersOnly;

  @override
  bool get animated => false;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {}
}
