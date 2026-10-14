import '../../theme/scan_fx_style.dart';
import 'scan_frame_layer.dart';

/// A straight-edged border with no rounding.
///
/// Where [RoundedSquareFrame] and [SquircleFrame] soften the scan area, this
/// style states it: the tightest, most technical outline, and the natural partner
/// for [ScanCornerStyle.sharp]. Because it still follows the quad, a rotated code
/// gets a rotated border rather than an axis-aligned box.
class FullBorderFrame extends ScanFrameLayer {
  /// Creates the style.
  FullBorderFrame();

  @override
  ScanFrameShape get shape => ScanFrameShape.fullBorder;
}
