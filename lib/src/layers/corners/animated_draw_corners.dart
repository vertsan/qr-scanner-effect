import 'dart:ui' show Offset, Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';
import 'scan_corner_layer.dart';

/// Bracket arms that draw themselves on as the lock settles.
///
/// The four arms grow out of their corners together, driven by the same focus
/// spring as the frame, so the brackets appear to be *built* by the lock rather
/// than switched on. While nothing is tracked the arms stay fully drawn, which
/// keeps the scanning state legible.
///
/// Trimming a path means walking its metrics, which allocates, so the draw-on is
/// quantised into [steps] positions: at most a few dozen rebuilds across the
/// whole lock instead of one per frame. Reduce-motion jumps straight to the
/// finished arms.
class AnimatedDrawCorners extends ScanCornerLayer {
  /// Creates the style.
  AnimatedDrawCorners();

  /// How many distinct draw-on positions the lock is divided into.
  static const int steps = 32;

  Path? _path;
  Path? _source;
  ScanFxQuad? _quad;
  double _arm = -1;
  double _inset = -1;
  int _step = -1;

  @override
  Path bracketPath(ScanFxFrame frame) {
    final quad = frame.quad;
    final arm = armFor(frame);
    final inset = insetFor(frame);
    final progress = _progress(frame);
    final step = (progress * steps).round();
    if (_path != null &&
        _quad == quad &&
        _arm == arm &&
        _inset == inset &&
        _step == step) {
      return _path!;
    }

    final source = _source ??= Path();
    source.reset();
    ScanFxShapes.addQuadCornerArms(source, quad, inset, arm);

    final path = _path ??= Path();
    path.reset();
    final t = step / steps;
    if (t > 0) {
      for (final metric in source.computeMetrics()) {
        path.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
      }
    }

    _quad = quad;
    _arm = arm;
    _inset = inset;
    _step = step;
    return path;
  }

  double _progress(ScanFxFrame frame) {
    if (frame.reduceMotion || !frame.hasTarget) return 1;
    return frame.focus.clamp(0.0, 1.0);
  }
}
