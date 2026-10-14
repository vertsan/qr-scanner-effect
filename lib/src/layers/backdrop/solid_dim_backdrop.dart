import 'dart:ui' show Canvas, Size;

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_paint_cache.dart';
import 'scan_backdrop_layer.dart';

/// A uniform dim with a feathered squircle cutout.
///
/// The feather is produced by blurring the cutout path itself rather than by
/// rendering to an offscreen layer, and the outer rectangle is pushed off-canvas
/// so the blur cannot create a pale fringe at the screen edge. Setting
/// `feather` to `0` removes the blur entirely, which is the documented fast
/// path for low-end devices.
class SolidDimBackdrop extends ScanBackdropLayer {
  /// Creates the style.
  SolidDimBackdrop();

  late final ScanPaintCache _cache = ScanPaintCache();

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final options = frame.theme.backdrop;
    final opacity = (options.dimOpacity +
            (options.deepenedOpacity - options.dimOpacity) * frame.dim) *
        frame.intensity;
    if (opacity <= 0.002) return;

    final feather = options.feather * frame.intensity;
    final path = cutoutPath(
      frame,
      outerInflate: feather > 0 ? feather * 3 : 0,
      innerInflate: frame.theme.frameStrokeWidth + 2,
    );

    final base = ScanFxPalette.mix(
      frame.theme.backdropColor,
      frame.theme.beamColor,
      options.tintOpacity,
    );

    canvas.save();
    canvas.clipRect(frame.overlay);
    final paint = _cache.scratch
      ..color = ScanFxPalette.withAlpha(base, opacity.clamp(0.0, 0.96))
      ..maskFilter = _cache.fillFilter(feather * 0.55);
    canvas.drawPath(path, paint);
    canvas.restore();
  }
}
