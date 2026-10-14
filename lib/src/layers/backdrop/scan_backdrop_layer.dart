import 'dart:ui' show Offset, Path, PathFillType, Size;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../../theme/scan_fx_style.dart';
import '../scan_layer.dart';

/// Shared geometry for the backdrop family.
///
/// Every backdrop style needs the same thing: a path describing "the overlay,
/// minus the scan area". Building it once, with an even-odd fill rule (which
/// punches the hole without `Path.combine`), keeps all six backdrop styles to a
/// handful of lines each.
///
/// The path is cached and rebuilt only when the quad, radius, shape or size
/// actually changes, so a still frame allocates nothing.
abstract class ScanBackdropLayer extends ScanLayer {
  /// Creates the base.
  ScanBackdropLayer();

  @override
  ScanLayerKind get kind => ScanLayerKind.backdrop;

  Path? _path;
  ScanFxQuad? _pathQuad;
  double _pathRadius = -1;
  double _pathOuter = -1;
  double _pathInner = -1;
  Size _pathSize = Size.zero;
  ScanFrameShape? _pathShape;
  double _pathExponent = -1;

  /// The overlay with the scan area removed, filled with the even-odd rule.
  ///
  /// [outerInflate] pushes the outer rectangle off-canvas so a blurred fill
  /// does not produce a pale fringe at the screen edge; [innerInflate] grows
  /// the hole so the dim never sits on top of the frame stroke.
  Path cutoutPath(
    ScanFxFrame frame, {
    double outerInflate = 0,
    double innerInflate = 0,
  }) {
    final quad = frame.quad;
    final radius = frame.cornerRadius;
    final shape = frame.theme.frameShape;
    final exponent = frame.theme.squircleExponent;
    if (_path != null &&
        _pathQuad == quad &&
        _pathRadius == radius &&
        _pathShape == shape &&
        _pathOuter == outerInflate &&
        _pathInner == innerInflate &&
        _pathSize == frame.size &&
        _pathExponent == exponent) {
      return _path!;
    }

    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(frame.overlay.inflate(outerInflate));

    switch (shape) {
      case ScanFrameShape.circle:
        path.addOval(quad.bounds.inflate(innerInflate));
      case ScanFrameShape.squircle:
        path.addPolygon(
          ScanFxShapes.superellipsePoints(
            quad.bounds.inflate(innerInflate),
            exponent: exponent,
          ),
          true,
        );
      case ScanFrameShape.roundedSquare:
      case ScanFrameShape.cornersOnly:
        final rounded = ScanFxShapes.roundedQuad(
          innerInflate == 0 ? quad : quad.inflateAlongNormals(innerInflate),
          radius,
        );
        path.addPath(rounded, Offset.zero);
    }

    _path = path;
    _pathQuad = quad;
    _pathRadius = radius;
    _pathShape = shape;
    _pathOuter = outerInflate;
    _pathInner = innerInflate;
    _pathSize = frame.size;
    _pathExponent = exponent;
    return path;
  }
}
