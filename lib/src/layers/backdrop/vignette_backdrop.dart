import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_paint_cache.dart';
import 'scan_backdrop_layer.dart';

/// A radial vignette: the centre of the frame stays clear while the edges fall
/// away into the dim colour.
///
/// Unlike [SolidDimBackdrop] this style does **not** cut a hole, so it costs a
/// single gradient-filled rectangle per frame and is the cheapest way to make
/// the scan area pop without touching the detector geometry.
class VignetteBackdrop extends ScanBackdropLayer {
  /// Creates the style.
  const VignetteBackdrop();

  late final ScanPaintCache _cache = ScanPaintCache();

  Shader? _shader;
  Size _shaderSize = Size.zero;
  int _shaderKey = -1;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final options = frame.theme.backdrop;
    final opacity = (options.dimOpacity +
            (options.deepenedOpacity - options.dimOpacity) * frame.dim) *
        frame.intensity;
    if (opacity <= 0.002) return;

    final outer = ScanFxPalette.mix(
      frame.theme.backdropColor,
      frame.theme.beamColor,
      options.tintOpacity,
    );
    final key = (opacity * 100).round();
    if (_shader == null || _shaderSize != size || _shaderKey != key) {
      _shaderSize = size;
      _shaderKey = key;
      _shader = Gradient.radial(
        size.center(Offset.zero),
        size.shortestSide * 0.78,
        <Color>[
          ScanFxPalette.withAlpha(outer, 0),
          ScanFxPalette.withAlpha(outer, opacity.clamp(0.0, 0.96) * 0.35),
          ScanFxPalette.withAlpha(outer, opacity.clamp(0.0, 0.96)),
        ],
        const <double>[0, 0.55, 1],
      );
    }

    _cache.scratch
      ..shader = _shader
      ..color = const Color(0xFFFFFFFF)
      ..maskFilter = null;
    canvas.drawRect(frame.overlay, _cache.scratch);
    _cache.scratch.shader = null;
  }
}
