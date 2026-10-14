import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import 'scan_backdrop_layer.dart';

/// Leaves the camera preview untouched.
///
/// The right choice when the host app already dims the preview itself, or for
/// screenshot-friendly store listings.
class NoneBackdrop extends ScanBackdropLayer {
  /// Creates the style.
  const NoneBackdrop();

  @override
  bool get animated => false;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {}
}
