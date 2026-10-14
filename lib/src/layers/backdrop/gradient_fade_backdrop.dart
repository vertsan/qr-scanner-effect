import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_paint_cache.dart';
import 'scan_backdrop_layer.dart';

/// A linear fade from one edge, leaving the far side of the overlay clear.
///
/// Useful for overlay chrome that sits along a single edge (a title at the top,
/// a torch row at the bottom) and for hints that should stay legible without
/// dimming the whole preview.
class GradientFadeBackdrop extends ScanBackdropLayer {
  /// Creates the style.
  GradientFadeBackdrop({this.fromBottom = true});

  /// When `true` the fade is strongest at the bottom edge.
  final bool fromBottom;

  late final ScanPaintCache _cache = ScanPaintCache();

  Shader? _shader;
  Size _shaderSize = Size.zero;
  int _shaderKey = -1;
  bool _shaderFromBottom = true;

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
    if (_shader == null ||
        _shaderSize != size ||
        _shaderKey != key ||
        _shaderFromBottom != fromBottom) {
      _shaderSize = size;
      _shaderKey = key;
      _shaderFromBottom = fromBottom;
      final strong = ScanFxPalette.withAlpha(outer, opacity.clamp(0.0, 0.96));
      final clear = ScanFxPalette.withAlpha(outer, 0);
      final from = fromBottom
          ? size.bottomCenter(Offset.zero)
          : size.topCenter(Offset.zero);
      final to = fromBottom
          ? size.topCenter(Offset.zero)
          : size.bottomCenter(Offset.zero);
      _shader = Gradient.linear(
        from,
        to,
        <Color>[strong, clear],
        const <double>[0, 1],
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
