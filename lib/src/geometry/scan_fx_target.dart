import 'dart:ui' show Offset, Rect;

/// A detection result expressed as **geometry only**.
///
/// This is the single input type for target tracking. There is intentionally no
/// constructor, field, or setter anywhere on this class (or on the public
/// controller) that accepts decoded QR text: the overlay is a pure rendering
/// surface and must never hold payload data.
///
/// Two forms are supported:
///
/// * [ScanFxTarget.rect] for detectors that report an axis-aligned bounding box
///   (ML Kit, ZXing).
/// * [ScanFxTarget.corners] for detectors that report four corner points, which
///   allows rotated and perspective-skewed codes to be framed correctly.
///
/// Both accept sensor-space pixels, or normalized `0..1` coordinates when
/// [normalized] is `true` (set this when you only have `videoWidth`/
/// `videoHeight`-relative values, as on the web).
class ScanFxTarget {
  /// Creates a target from an axis-aligned bounding box.
  const ScanFxTarget.rect(
    Rect this.rect, {
    this.normalized = false,
    this.flipX = false,
    this.flipY = false,
    this.quarterTurns = 0,
  })  : corners = null,
        assert(quarterTurns >= 0 && quarterTurns < 4,
            'quarterTurns must be 0..3');

  /// Creates a target from four corner points.
  ///
  /// The points do not have to be ordered; they are re-ordered into a stable
  /// ring (see `ScanFxQuad.fromCorners`) before being animated, so a detector
  /// that reports bottom-left first produces an identical result.
  ScanFxTarget.corners(
    List<Offset> this.corners, {
    this.normalized = false,
    this.flipX = false,
    this.flipY = false,
    this.quarterTurns = 0,
  })  : rect = null,
        assert(quarterTurns >= 0 && quarterTurns < 4,
            'quarterTurns must be 0..3') {
    if (corners!.length != 4) {
      throw ArgumentError.value(
        corners,
        'corners',
        'A QR target needs exactly 4 corner points',
      );
    }
  }

  /// The bounding box form, or `null` when this target uses [corners].
  final Rect? rect;

  /// The corner form, or `null` when this target uses [rect].
  final List<Offset>? corners;

  /// Whether coordinates are normalized `0..1` against the sensor frame rather
  /// than expressed in sensor pixels.
  final bool normalized;

  /// Mirrors the target horizontally (front-camera previews).
  final bool flipX;

  /// Mirrors the target vertically.
  final bool flipY;

  /// Rotates the target by this many clockwise quarter turns.
  ///
  /// Use this when the camera sensor orientation differs from the preview's.
  final int quarterTurns;

  /// Whether this target carries an axis-aligned rectangle.
  bool get isRect => rect != null;

  /// The four corner points in the target's own coordinate space, ordered
  /// `topLeft, topRight, bottomRight, bottomLeft` for a rectangle.
  ///
  /// For [ScanFxTarget.corners] the raw point order is preserved here; ordered
  /// ring construction happens in `ScanFxQuad`.
  List<Offset> get rawCorners {
    final r = rect;
    if (r != null) {
      return <Offset>[r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    }
    return corners!;
  }

  @override
  String toString() => rect != null
      ? 'ScanFxTarget.rect($rect, normalized: $normalized, '
          'flipX: $flipX, flipY: $flipY, turns: $quarterTurns)'
      : 'ScanFxTarget.corners(${corners!.map((o) => o.toString()).join(', ')}, '
          'normalized: $normalized, flipX: $flipX, flipY: $flipY, '
          'turns: $quarterTurns)';
}
