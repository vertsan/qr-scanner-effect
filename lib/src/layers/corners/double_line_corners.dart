import 'dart:ui' show Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';
import 'scan_corner_layer.dart';

/// Two concentric arms per edge.
///
/// The outer arm sits on the frame and the inner one steps towards the centre,
/// which thickens the bracket without a heavier stroke. It is the densest corner
/// style and pairs naturally with a thin frame stroke, so the corners read as
/// the deliberate part of the composition.
class DoubleLineCorners extends ScanCornerLayer {
  /// Creates the style.
  DoubleLineCorners();

  /// The gap between the two lines, as a multiple of the stroke width.
  static const double gapFactor = 1.7;

  /// The inner arm's length, as a fraction of the outer arm's.
  static const double innerFactor = 0.68;

  Path? _path;
  ScanFxQuad? _quad;
  double _arm = -1;
  double _inset = -1;
  double _gap = -1;

  @override
  Path bracketPath(ScanFxFrame frame) {
    final quad = frame.quad;
    final arm = armFor(frame);
    final inset = insetFor(frame);
    final gap = frame.theme.cornerStrokeWidth * gapFactor;
    if (_path != null &&
        _quad == quad &&
        _arm == arm &&
        _inset == inset &&
        _gap == gap) {
      return _path!;
    }

    final path = _path ??= Path();
    path.reset();
    ScanFxShapes.addQuadCornerArms(path, quad, inset, arm);
    ScanFxShapes.addQuadCornerArms(path, quad, inset + gap, arm * innerFactor);

    _quad = quad;
    _arm = arm;
    _inset = inset;
    _gap = gap;
    return path;
  }
}
