import 'dart:ui';

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../theme/scan_fx_style.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import '../paint/scan_paint_cache.dart';
import '../scan_layer.dart';

/// Shared behaviour for the frame family.
///
/// Every frame style answers one question — "what path outlines the scan area?"
/// — and inherits the rest: bloom, the state tint, the reveal fade and the
/// [ScanIdleStyle.shimmer] highlight. That is why a new frame shape is a
/// ten-line class rather than a hundred-line painter.
abstract class ScanFrameLayer extends ScanLayer {
  /// Const constructor.
  const ScanFrameLayer();

  @override
  ScanLayerKind get kind => ScanLayerKind.frame;

  late final ScanPaintCache _cache = ScanPaintCache();

  Path? _outline;
  ScanFxQuad? _outlineQuad;
  double _outlineRadius = -1;
  double _outlineExponent = -1;
  ScanFrameShape? _outlineShape;

  /// The outline path for [frame], rebuilt only when the geometry changed.
  ///
  /// The cache is keyed on the quad itself (which compares by corner position),
  /// so a still overlay — a paused scanner, a terminal state — allocates no
  /// paths at all, while an animating lock rebuilds exactly one path per frame.
  Path outline(ScanFxFrame frame) {
    final quad = frame.quad;
    final radius = frame.cornerRadius;
    final shape = frame.theme.frameShape;
    final exponent = frame.theme.squircleExponent;
    if (_outline != null &&
        _outlineQuad == quad &&
        _outlineRadius == radius &&
        _outlineShape == shape &&
        _outlineExponent == exponent) {
      return _outline!;
    }
    final path = buildOutline(frame);
    _outline = path;
    _outlineQuad = quad;
    _outlineRadius = radius;
    _outlineShape = shape;
    _outlineExponent = exponent;
    return path;
  }

  /// Builds the outline for [frame]'s current quad. Called only on a cache miss.
  Path buildOutline(ScanFxFrame frame);

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final path = outline(frame);
    final width = frame.theme.frameStrokeWidth;
    final focusBoost = 0.14 * frame.focus;
    final alpha = (frame.reveal * (1 + focusBoost)).clamp(0.0, 1.0);
    final color = ScanFxPalette.fade(frame.stateColor, alpha);

    ScanGlow.strokePath(
      canvas,
      path,
      color,
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      _cache,
    );

    if (frame.shimmer > 0) {
      _paintShimmer(canvas, path, frame);
    }
  }

  Shader? _shimmer;
  int _shimmerKey = -1;
  Size _shimmerSize = Size.zero;

  void _paintShimmer(Canvas canvas, Path clip, ScanFxFrame frame) {
    final rect = frame.overlay;
    if (rect.isEmpty) return;
    final key = (frame.shimmer * 50).floor();
    if (_shimmer == null || _shimmerSize != rect.size || _shimmerKey != key) {
      _shimmerSize = rect.size;
      _shimmerKey = key;
      final t = key / 50;
      final centerX = rect.left - rect.width * 0.35 + rect.width * 1.7 * t;
      final band = rect.width * 0.22;
      _shimmer = Gradient.linear(
        Offset(centerX - band, rect.top),
        Offset(centerX + band, rect.bottom),
        <Color>[
          ScanFxPalette.withAlpha(frame.stateColor, 0),
          ScanFxPalette.withAlpha(frame.stateColor, 0.28),
          ScanFxPalette.withAlpha(frame.stateColor, 0),
        ],
        const <double>[0, 0.5, 1],
      );
    }
    canvas.save();
    canvas.clipPath(clip);
    _cache.scratch
      ..shader = _shimmer
      ..color = const Color(0xFFFFFFFF)
      ..maskFilter = null;
    canvas.drawRect(rect, _cache.scratch);
    _cache.scratch.shader = null;
    canvas.restore();
  }
}
