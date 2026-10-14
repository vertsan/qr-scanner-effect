import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/painting.dart' show BoxFit, applyBoxFit;

import 'scan_fx_quad.dart';
import 'scan_fx_target.dart';

/// Converts detection geometry from **sensor space** into **overlay space**.
///
/// This is the piece most scanner overlays get wrong: the camera preview is
/// usually cropped (`BoxFit.cover`), mirrored on front cameras, and rotated
/// relative to the sensor. This mapper applies all three, in one place, as a
/// pure function so it can be unit tested without a camera.
///
/// ```dart
/// final mapper = ScanGeometryMapper(
///   sensorSize: const Size(1920, 1080),
///   overlaySize: const Size(390, 844),
/// );
/// final quad = mapper.map(ScanFxTarget.corners(points, normalized: true));
/// ```
class ScanGeometryMapper {
  /// Creates a mapper for one preview configuration.
  const ScanGeometryMapper({
    required this.sensorSize,
    required this.overlaySize,
    this.fit = BoxFit.cover,
  });

  /// The resolution of the camera frame that produced the detection.
  final Size sensorSize;

  /// The size of the overlay widget that will draw the detection.
  final Size overlaySize;

  /// How the preview is fitted into [overlaySize].
  ///
  /// Must match the host app's preview widget, otherwise the overlay will be
  /// offset. [BoxFit.cover] is the common case.
  final BoxFit fit;

  /// Maps [target] into overlay space, or returns `null` when the mapping is
  /// degenerate (a zero-sized sensor or overlay).
  ///
  /// The result is always a convex, stably ordered quad: corners are sorted and
  /// rotated so corner *i* always refers to the same physical corner across
  /// frames, which is what keeps the lock-on animation from twisting.
  ScanFxQuad? map(ScanFxTarget target) {
    if (sensorSize.isEmpty || overlaySize.isEmpty) return null;

    final orientedSize = orientedSensorSize(sensorSize, target.quarterTurns);
    if (orientedSize.isEmpty) return null;

    final corners = <Offset>[
      for (final raw in target.rawCorners)
        mapPoint(
          sensorPoint: target.normalized
              ? Offset(raw.dx * sensorSize.width, raw.dy * sensorSize.height)
              : raw,
          sensorSize: sensorSize,
          overlaySize: overlaySize,
          fit: fit,
          quarterTurns: target.quarterTurns,
          flipX: target.flipX,
          flipY: target.flipY,
        ),
    ];

    final quad = ScanFxQuad.fromCorners(corners);
    return quad.bounds.isEmpty ? null : quad;
  }

  /// Maps a single point between spaces. Exposed for tests and for hosts that
  /// want to draw their own geometry.
  static Offset mapPoint({
    required Offset sensorPoint,
    required Size sensorSize,
    required Size overlaySize,
    BoxFit fit = BoxFit.cover,
    int quarterTurns = 0,
    bool flipX = false,
    bool flipY = false,
  }) {
    final oriented = orient(
      sensorPoint,
      sensorSize,
      quarterTurns: quarterTurns,
      flipX: flipX,
      flipY: flipY,
    );
    final orientedSize = orientedSensorSize(sensorSize, quarterTurns);

    final fitted = applyBoxFit(fit, orientedSize, overlaySize);
    final source = fitted.source;
    final destination = fitted.destination;
    if (source.isEmpty || destination.isEmpty) return Offset.zero;

    final scaleX = destination.width / source.width;
    final scaleY = destination.height / source.height;
    final sourceOrigin = Offset(
      (orientedSize.width - source.width) / 2,
      (orientedSize.height - source.height) / 2,
    );
    final destinationOrigin = Offset(
      (overlaySize.width - destination.width) / 2,
      (overlaySize.height - destination.height) / 2,
    );

    return Offset(
      (oriented.dx - sourceOrigin.dx) * scaleX + destinationOrigin.dx,
      (oriented.dy - sourceOrigin.dy) * scaleY + destinationOrigin.dy,
    );
  }

  /// Applies mirroring and rotation to a sensor-space point.
  static Offset orient(
    Offset point,
    Size sensorSize, {
    int quarterTurns = 0,
    bool flipX = false,
    bool flipY = false,
  }) {
    var q = point;
    var size = sensorSize;
    if (flipX) q = Offset(size.width - q.dx, q.dy);
    if (flipY) q = Offset(q.dx, size.height - q.dy);
    for (var i = 0; i < quarterTurns; i++) {
      final center = Offset(size.width / 2, size.height / 2);
      final d = q - center;
      // Screen space has y pointing down, so a clockwise quarter turn maps
      // (x, y) -> (-y, x) around the centre.
      q = Offset(center.dx - d.dy, center.dy + d.dx);
      size = Size(size.height, size.width);
    }
    return q;
  }

  /// The sensor size after applying [turns] quarter turns.
  static Size orientedSensorSize(Size sensorSize, int turns) =>
      turns.isOdd ? Size(sensorSize.height, sensorSize.width) : sensorSize;

  /// Convenience wrapper for hosts that only have a bounding box.
  ScanFxQuad? mapRect(Rect bounds) => map(ScanFxTarget.rect(bounds));
}
