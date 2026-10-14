import 'dart:ui' show Canvas, Clip, ImageFilter, Size, TileMode;

import 'package:flutter/widgets.dart';

import '../../animation/scan_fx_frame.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_paint_cache.dart';
import 'scan_backdrop_layer.dart';

/// A genuine frosted backdrop: the camera preview behind the cutout is blurred
/// with a [BackdropFilter].
///
/// This is the one style that cannot be expressed as canvas calls, because it
/// samples what is *behind* the overlay. It is therefore the only style that
/// inserts a widget, and it is documented as the expensive option:
///
/// * it costs a full-screen blur pass every frame the tint animates, and
/// * setting the `blurSigma` tunable to `0` degrades it to a flat dim.
///
/// Hosts that need 120 fps on low-end hardware should prefer
/// [SolidDimBackdrop], which is the default.
class BlurredFrostBackdrop extends ScanBackdropLayer {
  /// Creates the style.
  BlurredFrostBackdrop();

  late final ScanPaintCache _cache = ScanPaintCache();

  @override
  bool get wantsWidget => true;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    // The blur already provides the softness; this pass only adds the tint so
    // the frosted area matches the theme.
    final options = frame.theme.backdrop;
    final opacity = (options.dimOpacity * 0.55 +
            (options.deepenedOpacity - options.dimOpacity) * 0.55 * frame.dim) *
        frame.intensity;
    if (opacity <= 0.002) return;

    final base = ScanFxPalette.mix(
      frame.theme.backdropColor,
      frame.theme.beamColor,
      options.tintOpacity,
    );
    final path = cutoutPath(
      frame,
      innerInflate: frame.theme.frameStrokeWidth + 2,
    );
    canvas.save();
    canvas.clipRect(frame.overlay);
    _cache.scratch
      ..color = ScanFxPalette.withAlpha(base, opacity.clamp(0.0, 0.9))
      ..maskFilter = null;
    canvas.drawPath(path, _cache.scratch);
    canvas.restore();
  }

  @override
  Widget buildEffect(BuildContext context, ScanFxFrame frame) {
    final sigma = frame.theme.resolvedBlurSigma * frame.intensity;
    if (sigma <= 0) return const SizedBox.shrink();

    final base = ScanFxPalette.mix(
      frame.theme.backdropColor,
      frame.theme.beamColor,
      frame.theme.backdrop.tintOpacity,
    );

    return ClipPath(
      clipBehavior: Clip.antiAlias,
      clipper: _CutoutClipper(
        cutoutPath(frame, innerInflate: frame.theme.frameStrokeWidth + 2),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: ColoredBox(
          color: ScanFxPalette.withAlpha(base, 0.18 * frame.intensity),
        ),
      ),
    );
  }
}

class _CutoutClipper extends CustomClipper<Path> {
  const _CutoutClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _CutoutClipper oldClipper) =>
      !identical(oldClipper.path, path);
}
