import '../../theme/scan_fx_style.dart';
import 'scan_frame_layer.dart';

/// A diamond touching the four edge midpoints of the scan area.
///
/// Like [HexagonFrame] it is built in unit-square space, so it stays symmetric on
/// a rotated code. The most decorative frame shape; it pairs well with
/// [ScanCornerStyle.dot] and a [ScanBeamStyle.pulseRings] beam.
class DiamondFrame extends ScanFrameLayer {
  /// Creates the style.
  DiamondFrame();

  @override
  ScanFrameShape get shape => ScanFrameShape.diamond;
}
