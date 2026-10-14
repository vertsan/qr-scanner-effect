import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_paint_cache.dart';
import 'scan_backdrop_layer.dart';

/// A follow-spot: the scan area stays clear, the surround dims, and a soft rim
/// of light marks the edge of the spot.
///
/// Unlike [VignetteBackdrop], whose centre is fixed to the middle of the screen,
/// the spotlight tracks the *target quad*. That makes it read as a light being
/// aimed at the code, which is a strong cue when the overlay sits over a busy
/// preview.
///
/// The gradient is rebuilt only when the centre or the radius crosses a
/// half-pixel, so the lock-on morph does not allocate a shader per frame.
class SpotlightBackdrop extends ScanBackdropLayer {
  /// Creates the style.
  SpotlightBackdrop();

  late final ScanPaintCache _cache = ScanPaintCache();

  Shader? _shader;
  int _shaderKey = -1;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final options = frame.theme.backdrop;
    final opacity = (options.dimOpacity +
            (options.deepenedOpacity - options.dimOpacity) * frame.dim) *
        frame.intensity;
    if (opacity <= 0.002) return;

    final quad = frame.quad;
    final center = quad.center;
    final radius = (quad.shortestSide * 0.95).clamp(8.0, 1e6);
    final key = Object.hash(
      (center.dx * 2).round(),
      (center.dy * 2).round(),
      radius.round(),
      (opacity * 100).round(),
    );
    if (_shader == null || _shaderKey != key) {
      _shaderKey = key;
      final outer = ScanFxPalette.mix(
        frame.theme.backdropColor,
        frame.theme.beamColor,
        options.tintOpacity,
      );
      final rim = ScanFxPalette.mix(
        frame.theme.frameGlowColor,
        frame.theme.beamColor,
        0.4,
      );
      _shader = Gradient.radial(
        center,
        radius,
        <Color>[
          ScanFxPalette.withAlpha(outer, 0),
          ScanFxPalette.withAlpha(outer, 0),
          ScanFxPalette.withAlpha(rim, opacity.clamp(0.0, 0.9) * 0.35),
          ScanFxPalette.withAlpha(outer, opacity.clamp(0.0, 0.96)),
        ],
        <double>[0, 0.58, 0.74, 1],
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
