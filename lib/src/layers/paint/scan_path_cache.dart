import 'dart:ui' show Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';

/// Caches a single [Path] against the frame geometry it was built from.
///
/// Effect layers rebuild their outline every frame while a lock or a burst is
/// running, but must allocate **nothing** once the overlay settles. This class
/// makes that explicit at the call site:
///
/// ```dart
/// final path = _path.roundedQuad(frame);
/// ```
///
/// The builders are only invoked on a cache miss, so a still overlay performs
/// zero path construction.
class ScanQuadPathCache {
  /// Creates an empty cache.
  ScanQuadPathCache();

  /// The cached path, or `null` before the first build.
  Path? path;

  ScanFxQuad? _quad;
  double _radius = -1;
  double _exponent = -1;

  /// Whether the cached path is stale for [frame].
  bool stale(ScanFxFrame frame, {double? radius, double? exponent}) {
    final r = radius ?? frame.cornerRadius;
    final e = exponent ?? frame.theme.squircleExponent;
    return path == null || _quad != frame.quad || _radius != r || _exponent != e;
  }

  /// Stores [value] as the path for [frame].
  void store(ScanFxFrame frame, Path value, {double? radius, double? exponent}) {
    path = value;
    _quad = frame.quad;
    _radius = radius ?? frame.cornerRadius;
    _exponent = exponent ?? frame.theme.squircleExponent;
  }

  /// Invalidates the cache.
  void clear() {
    path = null;
    _quad = null;
    _radius = -1;
    _exponent = -1;
  }

  /// A rounded outline following the frame quad, rebuilt only when needed.
  Path roundedQuad(ScanFxFrame frame, {double? radius}) {
    final r = radius ?? frame.cornerRadius;
    if (path == null || _quad != frame.quad || _radius != r) {
      store(frame, ScanFxShapes.roundedQuad(frame.quad, r), radius: r);
    }
    return path!;
  }

  /// A superellipse inscribed in the frame bounds, rebuilt only when needed.
  Path superellipse(ScanFxFrame frame) {
    final e = frame.theme.squircleExponent;
    if (stale(frame, exponent: e)) {
      store(
        frame,
        ScanFxShapes.superellipse(frame.quad.bounds, exponent: e),
        exponent: e,
      );
    }
    return path!;
  }

  /// An oval inscribed in the frame bounds, rebuilt only when needed.
  Path oval(ScanFxFrame frame) {
    if (stale(frame)) {
      store(frame, ScanFxShapes.oval(frame.quad.bounds));
    }
    return path!;
  }
}
