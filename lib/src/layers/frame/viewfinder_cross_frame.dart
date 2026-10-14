import 'dart:ui' show Canvas, Path, Size;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../../theme/scan_fx_style.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import '../paint/scan_paint_cache.dart';
import 'scan_frame_layer.dart';

/// A rounded outline with tick marks at the four edge midpoints.
///
/// The ticks reach *outwards* from the frame, so the composition reads like a
/// camera viewfinder rather than a box. They inherit the frame's colour, bloom
/// and reveal, which is why this is a [paint] override on top of the base rather
/// than a separate layer that could drift out of sync.
class ViewfinderCrossFrame extends ScanFrameLayer {
  /// Creates the style.
  ViewfinderCrossFrame();

  /// Tick length as a fraction of the quad's shortest side.
  static const double tickLength = 0.14;

  @override
  ScanFrameShape get shape => ScanFrameShape.viewfinderCross;

  late final ScanPaintCache _cache = ScanPaintCache();

  Path? _ticks;
  ScanFxQuad? _ticksQuad;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    super.paint(canvas, size, frame);

    final width = frame.theme.frameStrokeWidth;
    final alpha = (frame.reveal * (1 + 0.14 * frame.focus)).clamp(0.0, 1.0);
    final color = ScanFxPalette.fade(frame.stateColor, alpha);
    if (color.a <= 0.004) return;

    ScanGlow.strokePath(
      canvas,
      _tickPath(frame),
      color,
      width,
      ScanGlow.sigmaFor(frame.glow, width),
      _cache,
    );
  }

  Path _tickPath(ScanFxFrame frame) {
    final quad = frame.quad;
    if (_ticks != null && _ticksQuad == quad) return _ticks!;
    // The tick reaches outwards along each edge normal, expressed in unit-square
    // space so it follows rotation, perspective and scale for free.
    final out = Path();
    _edge(out, quad, 0.5, 0, 0.5, -tickLength);
    _edge(out, quad, 0.5, 1, 0.5, 1 + tickLength);
    _edge(out, quad, 0, 0.5, -tickLength, 0.5);
    _edge(out, quad, 1, 0.5, 1 + tickLength, 0.5);
    _ticks = out;
    _ticksQuad = quad;
    return out;
  }

  void _edge(
    Path path,
    ScanFxQuad quad,
    double u0,
    double v0,
    double u1,
    double v1,
  ) {
    final a = ScanFxShapes.quadPoint(quad, u0, v0);
    final b = ScanFxShapes.quadPoint(quad, u1, v1);
    path.moveTo(a.dx, a.dy);
    path.lineTo(b.dx, b.dy);
  }
}
