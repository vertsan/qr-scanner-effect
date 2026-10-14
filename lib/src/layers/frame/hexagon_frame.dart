import '../../theme/scan_fx_style.dart';
import 'scan_frame_layer.dart';

/// A flat-topped hexagon inscribed in the scan area.
///
/// The hexagon is described once in unit-square space and mapped onto the quad,
/// so it follows a rotated or perspective-skewed code exactly. It reads as
/// technical and slightly futuristic without the aggressiveness of sharp
/// corners — a good partner for [ScanBeamStyle.gridScan].
class HexagonFrame extends ScanFrameLayer {
  /// Creates the style.
  HexagonFrame();

  @override
  ScanFrameShape get shape => ScanFrameShape.hexagon;
}
