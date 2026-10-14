import 'dart:ui' show Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import 'scan_corner_layer.dart';

/// Bracket arms joined by a bevel across the corner.
///
/// Where [ScanCornerStyle.rounded] and [ScanCornerStyle.sharp] meet at the
/// corner point itself, this style cuts the corner off: the arms stop short and
/// a diagonal connects them. The result reads as a folded cardboard corner,
/// which suits material and retail themes.
class ChamferedCorners extends ScanCornerLayer {
  /// Creates the style.
  ChamferedCorners();

  /// Where the bevel starts, as a fraction of the arm length.
  static const double bevel = 0.42;

  Path? _path;
  ScanFxQuad? _quad;
  double _arm = -1;
  double _inset = -1;

  @override
  Path bracketPath(ScanFxFrame frame) {
    final quad = frame.quad;
    final arm = armFor(frame);
    final inset = insetFor(frame);
    if (_path != null && _quad == quad && _arm == arm && _inset == inset) {
      return _path!;
    }

    final cut = arm * bevel;
    final path = _path ??= Path();
    path.reset();
    for (var i = 0; i < 4; i++) {
      final origin = ScanCornerLayer.bracketOrigin(quad, i, inset);
      final back = ScanCornerLayer.unit(
        origin,
        ScanCornerLayer.cornerOf(quad, (i + 3) % 4),
      );
      final forward = ScanCornerLayer.unit(
        origin,
        ScanCornerLayer.cornerOf(quad, (i + 1) % 4),
      );
      final tipBack = origin + back * arm;
      final tipForward = origin + forward * arm;
      final bevelBack = origin + back * cut;
      final bevelForward = origin + forward * cut;
      path.moveTo(tipBack.dx, tipBack.dy);
      path.lineTo(bevelBack.dx, bevelBack.dy);
      path.lineTo(bevelForward.dx, bevelForward.dy);
      path.lineTo(tipForward.dx, tipForward.dy);
    }

    _quad = quad;
    _arm = arm;
    _inset = inset;
    return path;
  }
}
