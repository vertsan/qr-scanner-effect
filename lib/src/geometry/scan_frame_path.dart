import 'dart:ui' show Offset, Path, Rect;

import '../theme/scan_fx_style.dart';
import 'scan_fx_quad.dart';
import 'scan_fx_shapes.dart';

/// Builds the outline of the scan area for a [ScanFrameShape].
///
/// Three places need "the shape of the scan area": the frame layer strokes it,
/// the backdrop layer cuts it out of the dim, and the path cache hands it to the
/// burst effects. Routing all three through one function is what keeps a new
/// frame shape a one-line change instead of three switches that can drift apart.
///
/// Every shape is expressed in the quad's own space, so a rotated or
/// perspective-skewed target is framed exactly rather than enclosed in a loose
/// axis-aligned box.
abstract final class ScanFramePath {
  /// The outline of [quad] as [shape].
  ///
  /// [radius] applies to the shapes with rounding ([ScanFrameShape.roundedSquare],
  /// [ScanFrameShape.cornersOnly], [ScanFrameShape.dashedBorder],
  /// [ScanFrameShape.viewfinderCross]) and [exponent] to
  /// [ScanFrameShape.squircle].
  static Path of(
    ScanFxQuad quad,
    ScanFrameShape shape,
    double radius, {
    double exponent = 4,
  }) =>
      switch (shape) {
        ScanFrameShape.circle => ScanFxShapes.oval(quad.bounds),
        ScanFrameShape.squircle => ScanFxShapes.superellipse(
            quad.bounds,
            exponent: exponent,
          ),
        ScanFrameShape.hexagon || ScanFrameShape.diamond =>
          ScanFxShapes.quadPolygon(quad, unitPolygon(shape)),
        ScanFrameShape.fullBorder => ScanFxShapes.sharpQuad(quad),
        ScanFrameShape.roundedSquare ||
        ScanFrameShape.cornersOnly ||
        ScanFrameShape.dashedBorder ||
        ScanFrameShape.viewfinderCross =>
          ScanFxShapes.roundedQuad(quad, radius),
      };

  /// Whether [shape] is described by a polygon of [unitPolygon] rather than a
  /// rectangle or conic section.
  static bool isPolygon(ScanFrameShape shape) =>
      shape == ScanFrameShape.hexagon || shape == ScanFrameShape.diamond;

  /// The unit-square vertices of [shape], in `0..1` coordinates.
  ///
  /// Working in the unit square and then mapping through the quad means the same
  /// six numbers produce a correct hexagon on an axis-aligned box, a rotated code
  /// and a perspective-skewed one.
  static List<Offset> unitPolygon(ScanFrameShape shape) => switch (shape) {
        // A flat-topped hexagon inscribed in the square.
        ScanFrameShape.hexagon => const <Offset>[
            Offset(0.25, 0),
            Offset(0.75, 0),
            Offset(1, 0.5),
            Offset(0.75, 1),
            Offset(0.25, 1),
            Offset(0, 0.5),
          ],
        // A diamond touching all four edge midpoints.
        ScanFrameShape.diamond => const <Offset>[
            Offset(0.5, 0),
            Offset(1, 0.5),
            Offset(0.5, 1),
            Offset(0, 0.5),
          ],
        _ => const <Offset>[],
      };

  /// A dashed version of [source], with dashes of [dash] separated by [gap].
  ///
  /// [offset] slides the pattern along the path, which is how a dashed border
  /// marches. Walks the path's metrics, which is the only way to dash an
  /// arbitrarily curved or rotated outline without approximating it. Callers
  /// cache the result: this allocates, so it never belongs in a `paint` fast
  /// path.
  static Path dashed(
    Path source, {
    required double dash,
    required double gap,
    double offset = 0,
  }) {
    final out = Path();
    final period = dash + gap;
    if (period <= 0) return out;
    for (final metric in source.computeMetrics()) {
      final length = metric.length;
      // Walk backwards from `offset` so a negative offset still produces a dash
      // that straddles the path start.
      final first = offset % period;
      var distance = first > 0 ? first - period : first;
      while (distance < length) {
        final start = distance < 0 ? 0.0 : distance;
        final end = distance + dash;
        if (end > 0 && start < length) {
          out.addPath(
            metric.extractPath(start, end > length ? length : end),
            Offset.zero,
          );
        }
        distance += period;
      }
    }
    return out;
  }

  /// The axis-aligned bounding rectangle of the quad's corners, which is what
  /// the conic shapes are inscribed in.
  static Rect boundsOf(ScanFxQuad quad) => quad.bounds;
}
