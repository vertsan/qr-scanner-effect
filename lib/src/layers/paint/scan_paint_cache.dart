import 'dart:ui'
    show
        BlendMode,
        BlurStyle,
        MaskFilter,
        Paint,
        PaintingStyle,
        StrokeCap,
        StrokeJoin;

/// A per-layer bag of reusable [Paint] objects.
///
/// The performance contract for this package is that `paint()` allocates
/// nothing. Painters therefore never construct a [Paint] inline; they borrow one
/// from their own cache and mutate only the fields they need.
///
/// Fields are `late final`, so a layer can keep a `const` constructor and still
/// own a mutable cache: the cache is created on first use.
class ScanPaintCache {
  /// Creates an empty cache. Paints are created lazily.
  ScanPaintCache();

  /// A reusable antialiased stroke paint with round caps and joins.
  late final Paint stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// A reusable antialiased fill paint.
  late final Paint fill = Paint()..isAntiAlias = true;

  /// A neutral paint used for `saveLayer`, gradients and one-off draws.
  late final Paint scratch = Paint()..isAntiAlias = true;

  /// A `dstOut` paint used to punch a hole in a `saveLayer`.
  late final Paint cutout = Paint()
    ..isAntiAlias = true
    ..blendMode = BlendMode.dstOut;

  double _fillSigma = -1;
  MaskFilter? _fillFilter;

  /// Returns a cached blur filter for [sigma], or `null` when blurring is off.
  ///
  /// Caching here matters: `MaskFilter.blur` is not free to construct, and a
  /// layer that rebuilds it every frame would allocate on every paint.
  MaskFilter? fillFilter(double sigma) {
    if (sigma <= 0) return null;
    if (sigma != _fillSigma) {
      _fillSigma = sigma;
      _fillFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }
    return _fillFilter;
  }

  /// A paint reserved for blurred "glow" passes.
  late final Paint glow = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  double _glowSigma = -1;

  /// Applies a blur of [sigma] to [glow], reusing the existing [MaskFilter] when
  /// the sigma is unchanged.
  ///
  /// Returns `false` when no blur should be drawn (sigma `<= 0`), which is the
  /// fast path that lets hosts dial glow down to zero cost.
  bool applyGlowBlur(double sigma) {
    if (sigma <= 0) {
      if (_glowSigma != -1) {
        glow.maskFilter = null;
        _glowSigma = -1;
      }
      return false;
    }
    if (sigma != _glowSigma) {
      glow.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      _glowSigma = sigma;
    }
    return true;
  }
}
