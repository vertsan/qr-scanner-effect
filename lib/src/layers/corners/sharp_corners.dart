import 'dart:ui' show StrokeCap;

import 'scan_corner_layer.dart';

/// Mitred bracket arms.
///
/// A crisp, instrument-like look for high-contrast and technical themes. The
/// only difference from [RoundedCorners] is the stroke cap, which is exactly the
/// kind of styling decision the [ScanCornerLayer] base is designed to isolate.
class SharpCorners extends ScanCornerLayer {
  /// Creates the style.
  const SharpCorners();

  @override
  StrokeCap get cap => StrokeCap.butt;
}
