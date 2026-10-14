import 'dart:ui' show Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../../theme/scan_fx_style.dart';

/// Caches one [Path] against the geometry it was built from.
///
/// Effect layers rebuild an outline every frame while a burst is running, but
/// must allocate **nothing** once the overlay settles. This class makes the fast
/// path explicit and free of closures at the call site:
///
/// ```dart
/// final path = _paths.outline(frame);
/// ```
///
/// Builders run only on a cache miss, and the staleness check is a handful of
/// value comparisons against the quad — which compares by corner position.
class ScanQuadPathCache {
  /// Creates an empty cache.
  ScanQuadPathCache();

  /// The cached path, or `null` before the first build.
  Path? path;

  ScanFxQuad? _quad;
  double _radius = -1;
  double _exponent = -1;
  double _scale = 1;
  ScanFrameShape? _shape;

  /// Whether the cached path is stale for [frame].
  bool stale(ScanFxFrame frame, {double scale = 1}) =>
      path == null ||
      _quad != frame.quad ||
      _radius != frame.cornerRadius ||
      _exponent != frame.theme.squircleExponent ||
      _scale != scale ||
      _shape != frame.theme.frameShape;

  void _store(ScanFxFrame frame, Path value, double radius, double scale) {
    path = value;
    _quad = frame.quad;
    _radius = radius;
    _exponent = frame.theme.squircleExponent;
    _scale = scale;
    _shape = frame.theme.frameShape;
  }

  /// Invalidates the cache.
  void clear() {
    path = null;
    _quad = null;
    _radius = -1;
    _exponent = -1;
    _scale = 1;
    _shape = null;
  }

  /// The outline of the scan area, matching [ScanFrameShape].
  ///
  /// Effects that should read as "the frame is reacting" all use this, which is
  /// why a `circle` theme gets circular washes and a `squircle` theme gets
  /// continuous-corner ones without a line of per-style code.
  Path outline(ScanFxFrame frame) {
    if (stale(frame)) {
      _store(
        frame,
        switch (frame.theme.frameShape) {
          ScanFrameShape.circle => ScanFxShapes.oval(frame.quad.bounds),
          ScanFrameShape.squircle => ScanFxShapes.superellipse(
              frame.quad.bounds,
              exponent: frame.theme.squircleExponent,
            ),
          ScanFrameShape.roundedSquare ||
          ScanFrameShape.cornersOnly =>
            ScanFxShapes.roundedQuad(frame.quad, frame.cornerRadius),
        },
        frame.cornerRadius,
        1,
      );
    }
    return path!;
  }

  /// A rounded outline following the frame quad, optionally scaled about its
  /// centre.
  ///
  /// The scaled form is what the lock-on reticle uses: one quad, one radius, one
  /// path, expanding and fading.
  Path roundedQuad(ScanFxFrame frame, {double? radius, double scale = 1}) {
    final r = radius ?? frame.cornerRadius;
    if (stale(frame, scale: scale) || _radius != r) {
      _store(
        frame,
        ScanFxShapes.roundedQuad(
          scale == 1
              ? frame.quad
              : frame.quad.scaleAbout(frame.quad.center, scale),
          r,
        ),
        r,
        scale,
      );
    }
    return path!;
  }
}
