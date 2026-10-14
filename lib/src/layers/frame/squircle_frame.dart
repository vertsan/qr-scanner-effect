import '../../theme/scan_fx_style.dart';
import 'scan_frame_layer.dart';

/// The iOS-style continuous corner.
///
/// A superellipse is sampled rather than approximated with arcs, so the straight
/// edges and the corners blend continuously. The exponent is part of the theme
/// (`QrScanFxTheme.squircleExponent`); `4` matches the platform's continuous
/// corner closely, and higher values square it up further.
class SquircleFrame extends ScanFrameLayer {
  /// Creates the style.
  SquircleFrame();

  @override
  ScanFrameShape get shape => ScanFrameShape.squircle;
}
