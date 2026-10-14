import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/painting.dart' show Size;

/// An animatable quadrilateral in overlay space.
///
/// Frames, corner brackets, beams and the focus reticle all read the *same*
/// [ScanFxQuad] instance for a given frame, which is what makes the lock-on
/// animation read as one rigid object rather than four layers chasing each
/// other.
///
/// The class is immutable. The animation core allocates exactly one new quad
/// per tick (outside of `paint`), so painters can treat it as a plain value.
class ScanFxQuad {
  /// Creates a quad from four corner points in `topLeft, topRight,
  /// bottomRight, bottomLeft` order.
  const ScanFxQuad(
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
  );

  /// Creates an axis-aligned quad from a rectangle.
  factory ScanFxQuad.fromRect(Rect r) =>
      ScanFxQuad(r.topLeft, r.topRight, r.bottomRight, r.bottomLeft);

  /// Creates a quad from four unordered points.
  ///
  /// Points are sorted by their angle around the centroid to form a convex
  /// ring, then rotated so the ring starts at the corner closest to the
  /// top-left. This makes rotated and perspective targets stable and free of
  /// self-intersections regardless of the detector's point order.
  factory ScanFxQuad.fromCorners(List<Offset> points) {
    assert(points.length == 4, 'ScanFxQuad.fromCorners needs 4 points');
    var cx = 0.0;
    var cy = 0.0;
    for (final p in points) {
      cx += p.dx;
      cy += p.dy;
    }
    final center = Offset(cx / 4, cy / 4);

    final sorted = List<Offset>.of(points)
      ..sort((a, b) {
        final aa = math.atan2(a.dy - center.dy, a.dx - center.dx);
        final ab = math.atan2(b.dy - center.dy, b.dx - center.dx);
        return aa.compareTo(ab);
      });

    // Rotate the ring so it starts at the top-left-most point, which keeps the
    // corner <-> corner correspondence stable across frames.
    var start = 0;
    var best = double.infinity;
    for (var i = 0; i < 4; i++) {
      final s = sorted[i].dx + sorted[i].dy;
      if (s < best) {
        best = s;
        start = i;
      }
    }
    final ring = <Offset>[
      sorted[start],
      sorted[(start + 1) % 4],
      sorted[(start + 2) % 4],
      sorted[(start + 3) % 4],
    ];
    return ScanFxQuad(ring[0], ring[1], ring[2], ring[3]);
  }

  /// Top-left corner, or the nearest equivalent for a rotated quad.
  final Offset topLeft;

  /// Top-right corner.
  final Offset topRight;

  /// Bottom-right corner.
  final Offset bottomRight;

  /// Bottom-left corner.
  final Offset bottomLeft;

  /// The corners in `topLeft, topRight, bottomRight, bottomLeft` order.
  List<Offset> get points => <Offset>[topLeft, topRight, bottomRight, bottomLeft];

  /// The axis-aligned bounding box of the quad.
  Rect get bounds {
    final minX = math.min(
      math.min(topLeft.dx, topRight.dx),
      math.min(bottomRight.dx, bottomLeft.dx),
    );
    final maxX = math.max(
      math.max(topLeft.dx, topRight.dx),
      math.max(bottomRight.dx, bottomLeft.dx),
    );
    final minY = math.min(
      math.min(topLeft.dy, topRight.dy),
      math.min(bottomRight.dy, bottomLeft.dy),
    );
    final maxY = math.max(
      math.max(topLeft.dy, topRight.dy),
      math.max(bottomRight.dy, bottomLeft.dy),
    );
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// The mean of the four corners.
  Offset get center => Offset(
        (topLeft.dx + topRight.dx + bottomRight.dx + bottomLeft.dx) / 4,
        (topLeft.dy + topRight.dy + bottomRight.dy + bottomLeft.dy) / 4,
      );

  /// The length of the shortest edge.
  double get shortestSide {
    final a = (topRight - topLeft).distance;
    final b = (bottomRight - topRight).distance;
    final c = (bottomLeft - bottomRight).distance;
    final d = (topLeft - bottomLeft).distance;
    return math.min(math.min(a, b), math.min(c, d));
  }

  /// The mean edge length.
  double get meanSide {
    final a = (topRight - topLeft).distance;
    final b = (bottomRight - topRight).distance;
    final c = (bottomLeft - bottomRight).distance;
    final d = (topLeft - bottomLeft).distance;
    return (a + b + c + d) / 4;
  }

  /// The clockwise rotation of the top edge, in radians.
  double get rotation => math.atan2(
        topRight.dy - topLeft.dy,
        topRight.dx - topLeft.dx,
      );

  /// Linearly interpolates between two quads, corner by corner.
  ///
  /// [t] is intentionally **not** clamped: the spring-driven lock-on relies on
  /// values slightly above `1` to produce a natural overshoot.
  static ScanFxQuad lerp(ScanFxQuad a, ScanFxQuad b, double t) {
    Offset mix(Offset x, Offset y) => Offset(
          x.dx + (y.dx - x.dx) * t,
          x.dy + (y.dy - x.dy) * t,
        );
    return ScanFxQuad(
      mix(a.topLeft, b.topLeft),
      mix(a.topRight, b.topRight),
      mix(a.bottomRight, b.bottomRight),
      mix(a.bottomLeft, b.bottomLeft),
    );
  }

  /// Uniformly scales the quad around [origin].
  ScanFxQuad scaleAbout(Offset origin, double scale) {
    Offset s(Offset p) => origin + (p - origin) * scale;
    return ScanFxQuad(s(topLeft), s(topRight), s(bottomRight), s(bottomLeft));
  }

  /// Translates every corner by [delta].
  ScanFxQuad translate(Offset delta) => ScanFxQuad(
        topLeft + delta,
        topRight + delta,
        bottomRight + delta,
        bottomLeft + delta,
      );

  /// Expands the quad outwards by [pad] along each edge normal.
  ///
  /// Unlike [Rect.inflate] this follows the quad's rotation, so a skewed code
  /// gains an even margin on all four sides.
  ScanFxQuad inflateAlongNormals(double pad) {
    if (pad == 0) return this;
    return ScanFxQuad(
      _offsetCorner(topLeft, topRight, bottomLeft, pad),
      _offsetCorner(topRight, bottomRight, topLeft, pad),
      _offsetCorner(bottomRight, bottomLeft, topRight, pad),
      _offsetCorner(bottomLeft, topLeft, bottomRight, pad),
    );
  }

  /// Offsets [corner] by [pad] along the outward bisector of its two edges.
  static Offset _offsetCorner(
    Offset corner,
    Offset next,
    Offset previous,
    double pad,
  ) {
    final n1 = _outwardNormal(corner, next);
    final n2 = _outwardNormal(previous, corner);
    var bisector = n1 + n2;
    final length = bisector.distance;
    if (length < 1e-6) {
      // Degenerate (collinear) corner: fall back to a single normal.
      return corner + n1 * pad;
    }
    bisector = bisector / length;
    // Miter correction keeps the visual padding uniform on sharp corners.
    final dot = n1.dx * bisector.dx + n1.dy * bisector.dy;
    final stretch = dot.abs() < 0.2 ? 1 / 0.2 : 1 / dot;
    return corner + bisector * (pad * (stretch > 2 ? 2 : stretch));
  }

  /// The unit normal pointing away from the quad on the edge [a] -> [b].
  ///
  /// "Away" is derived from the polygon's winding direction, so this works for
  /// both clockwise and counter-clockwise rings produced by detectors.
  static Offset _outwardNormal(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return Offset.zero;
    // Screen space has y pointing down; (dy, -dx) points outward for a
    // clockwise ring, ( -dy, dx) for counter-clockwise.
    return Offset(dy, -dx) / len;
  }

  /// Whether the quad is convex (or degenerate), which the animator requires.
  bool get isConvex {
    final pts = points;
    var positive = 0;
    var negative = 0;
    for (var i = 0; i < 4; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % 4];
      final c = pts[(i + 2) % 4];
      final cross = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
      if (cross > 1e-6) positive++;
      if (cross < -1e-6) negative++;
    }
    return positive == 0 || negative == 0;
  }

  /// Clamps the quad so it stays inside [area], scaling about its center when
  /// necessary and preserving its aspect ratio.
  ScanFxQuad fitInside(Rect area) {
    final b = bounds;
    if (area.contains(b.topLeft) && area.contains(b.bottomRight)) return this;
    final scale = math.min(
      1.0,
      math.min(area.width / math.max(b.width, 1e-6),
          area.height / math.max(b.height, 1e-6)),
    );
    return scaleAbout(center, scale).translate(area.center - bounds.center);
  }

  @override
  String toString() =>
      'ScanFxQuad($topLeft, $topRight, $bottomRight, $bottomLeft)';

  @override
  bool operator ==(Object other) =>
      other is ScanFxQuad &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);
}
