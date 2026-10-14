import '../../theme/scan_fx_style.dart';
import 'scan_frame_layer.dart';

/// A circle inscribed in the scan area.
///
/// Reads as a lens or a shutter, which suits camera-forward UIs. Pair it with
/// [ScanCornerStyle.dot] and [ScanBeamDirection.radial] for a full "radar" look,
/// and expect it to be generous: a circular frame around a square code leaves
/// the code's corners outside the outline, which is a deliberate, attractive
/// choice rather than a bug.
class CircleFrame extends ScanFrameLayer {
  /// Creates the style.
  CircleFrame();

  @override
  ScanFrameShape get shape => ScanFrameShape.circle;
}
