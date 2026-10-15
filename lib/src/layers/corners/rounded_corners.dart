import '../../animation/scan_fx_frame.dart';
import 'scan_corner_layer.dart';

/// Rounded bracket arms.
///
/// The default: soft enough to sit next to a squircle frame, precise enough to
/// still read as a technical reticle.
class RoundedCorners extends ScanCornerLayer {
  /// Creates the style.
  RoundedCorners();

  @override
  double bendRadiusFor(ScanFxFrame frame) => frame.cornerRadius;
}
