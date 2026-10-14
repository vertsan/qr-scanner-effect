import 'dart:math' as math;
import 'dart:ui';

import 'scan_fx_quad.dart';

/// Path geometry for squircle cutouts, frame shapes and polygons.
///
/// Every function is pure, so a layer can cache the resulting [Path] and only
/// rebuild it when the geometry actually changed. Nothing here mutates shared
/// state, and nothing allocates on behalf of a `paint` call.
class ScanFxShapes {
  const ScanFxShapes._();

  /// A rounded-rectangle path.
  static Path roundedRect(Rect rect, double radius) {
    final r = clampRadius(radius, rect.size);
    return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
  }

  /// An ellipse inscribed in [rect].
  static Path oval(Rect rect) => Path()..addOval(rect);

  /// A superellipse ("squircle") inscribed in [rect].
  ///
  /// [exponent] controls squareness: `2` is an ellipse, `4` is close to the iOS
  /// continuous corner, `6+` approaches a rounded rectangle with long, straight
  /// edges. [segmentsPerQuadrant] trades smoothness for cost; 16 keeps the
  /// chord error under a tenth of a pixel at typical overlay sizes.
  static Path superellipse(
    Rect rect, {
    double exponent = 4,
    int segmentsPerQuadrant = 16,
  }) {
    final points = superellipsePoints(
      rect,
      exponent: exponent,
      segmentsPerQuadrant: segmentsPerQuadrant,
    );
    return Path()..addPolygon(points, true);
  }

  /// The sample points of a superellipse, useful when a caller wants to reuse
  /// one point list for several strokes.
  static List<Offset> superellipsePoints(
    Rect rect, {
    double exponent = 4,
    int segmentsPerQuadrant = 16,
  }) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final a = rect.width / 2;
    final b = rect.height / 2;
    final e = 2 / exponent;
    final total = segmentsPerQuadrant * 4;
    final points = List<Offset>.generate(total, (i) {
      final theta = (i / total) * 2 * math.pi;
      return Offset(
        cx + a * _signedPow(math.cos(theta), e),
        cy + b * _signedPow(math.sin(theta), e),
      );
    });
    return points;
  }

  /// A closed regular polygon inscribed in [rect].
  ///
  /// `sides: 6` with `rotation: 0` gives a flat-topped hexagon; `sides: 4` with
  /// `rotation: math.pi / 4` gives a diamond. The polygon is tightened to the
  /// inscribed circle of [rect] so it never overflows the scan area.
  static Path polygon(
    Rect rect, {
    required int sides,
    double rotation = 0,
  }) {
    assert(sides >= 3, 'A polygon needs at least 3 sides');
    final points = polygonPoints(rect, sides: sides, rotation: rotation);
    return Path()..addPolygon(points, true);
  }

  /// The points of a regular polygon inscribed in [rect].
  static List<Offset> polygonPoints(
    Rect rect, {
    required int sides,
    double rotation = 0,
  }) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final radius = math.min(rect.width, rect.height) / 2;
    return List<Offset>.generate(sides, (i) {
      final theta = rotation - math.pi / 2 + (i / sides) * 2 * math.pi;
      return Offset(
        cx + radius * math.cos(theta),
        cy + radius * math.sin(theta),
      );
    });
  }

  /// A closed polyline through [points].
  static Path polyline(List<Offset> points) => Path()..addPolygon(points, true);

  /// A rounded version of an arbitrary (possibly rotated) quad.
  ///
  /// Each corner is replaced by a quadratic curve tangent to both of its edges,
  /// which keeps the shape stable for perspective-skewed targets while giving
  /// the frame the same soft corner language as an axis-aligned rounded
  /// rectangle.
  static Path roundedQuad(ScanFxQuad quad, double radius) {
    final path = Path();
    final pts = quad.points;
    final r = math.max(0.0, radius);
    for (var i = 0; i < 4; i++) {
      final corner = pts[i];
      final next = pts[(i + 1) % 4];
      final previous = pts[(i + 3) % 4];
      final toNext = _unit(corner, next);
      final toPrevious = _unit(corner, previous);
      final edge = math.min(
        (next - corner).distance,
        (corner - previous).distance,
      );
      final rr = math.min(r, edge / 2);
      final start = corner + toPrevious * rr;
      final end = corner + toNext * rr;
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      if (rr <= 0.01) {
        path.lineTo(end.dx, end.dy);
      } else {
        path.quadraticBezierTo(corner.dx, corner.dy, end.dx, end.dy);
      }
    }
    path.close();
    return path;
  }

  /// A closed polyline through the quad's corners.
  static Path sharpQuad(ScanFxQuad quad) => polyline(quad.points);

  static Offset _unit(Offset from, Offset to) {
    final delta = to - from;
    final length = delta.distance;
    return length < 1e-6 ? Offset.zero : delta / length;
  }

  /// A single corner bracket: two edges meeting at [corner].
  ///
  /// [incoming] and [outgoing] are unit vectors from the corner along the two
  /// edges, and [length] is how far the bracket arms extend.
  static void addCornerArms(
    Path path,
    Offset corner,
    Offset incoming,
    Offset outgoing,
    double length,
  ) {
    path.moveTo(
        corner.dx + incoming.dx * length, corner.dy + incoming.dy * length);
    path.lineTo(corner.dx, corner.dy);
    path.lineTo(
        corner.dx + outgoing.dx * length, corner.dy + outgoing.dy * length);
  }

  /// Corner [index] of [quad], in `topLeft, topRight, bottomRight, bottomLeft`
  /// order (the ring order every layer uses).
  static Offset quadCorner(ScanFxQuad quad, int index) => switch (index) {
        0 => quad.topLeft,
        1 => quad.topRight,
        2 => quad.bottomRight,
        _ => quad.bottomLeft,
      };

  /// The unit vector from [from] towards [to], or [Offset.zero] when the two
  /// points coincide.
  static Offset unitVector(Offset from, Offset to) {
    final delta = to - from;
    final length = delta.distance;
    return length < 1e-6 ? Offset.zero : delta / length;
  }

  /// The point [inset] logical pixels from corner [index] of [quad] towards the
  /// quad's centre.
  ///
  /// A **negative** [inset] pushes the point outwards instead, which is how the
  /// focus brackets start outside the scan area and converge onto it. The offset
  /// follows the corner's own bisector, so it stays visually even on a rotated
  /// or perspective-skewed quad.
  static Offset insetQuadCorner(ScanFxQuad quad, int index, double inset) {
    final corner = quadCorner(quad, index);
    final towardsCenter = unitVector(corner, quad.center);
    return corner + towardsCenter * inset;
  }

  /// Adds the four corner brackets of [quad] to [path].
  ///
  /// Each bracket is placed at [inset] from its corner and grows [length] along
  /// both adjacent edges, which is the shared geometry behind the corner layer
  /// and the lock-on focus reticle.
  static void addQuadCornerArms(
    Path path,
    ScanFxQuad quad,
    double inset,
    double length,
  ) {
    for (var i = 0; i < 4; i++) {
      final origin = insetQuadCorner(quad, i, inset);
      addCornerArms(
        path,
        origin,
        unitVector(origin, quadCorner(quad, (i + 3) % 4)),
        unitVector(origin, quadCorner(quad, (i + 1) % 4)),
        length,
      );
    }
  }

  /// Clamps [radius] so it can never exceed half of the smaller side.
  static double clampRadius(double radius, Size size) => math.max(
        0,
        math.min(radius, math.min(size.width, size.height) / 2),
      );

  static double _signedPow(double value, double exponent) {
    final magnitude = math.pow(value.abs(), exponent).toDouble();
    return value.isNegative ? -magnitude : magnitude;
  }
}
