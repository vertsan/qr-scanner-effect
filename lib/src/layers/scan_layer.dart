import 'package:flutter/widgets.dart';

import '../animation/scan_fx_frame.dart';
import '../theme/scan_fx_style.dart';

/// A single drawable unit of the overlay.
///
/// Layers are deliberately tiny: a style is a class that turns a
/// [ScanFxFrame] into a handful of canvas calls. Splitting the overlay this way
/// is what makes "every combination works" true and what keeps each style under
/// fifty lines.
///
/// A layer **must not** allocate inside [paint]. Cached geometry lives in the
/// layer instance (which is created once), and is invalidated by comparing a
/// stored key — usually `frame.revision` — before rebuilding.
///
/// ```dart
/// class MyBeam extends ScanLayer {
///   MyBeam();
///
///   @override
///   ScanLayerKind get kind => ScanLayerKind.beam;
///
///   @override
///   void paint(Canvas canvas, Size size, ScanFxFrame frame) {
///     // ...
///   }
/// }
/// ```
abstract class ScanLayer {
  /// Creates a layer.
  ///
  /// Layers are deliberately **not** `const`: a style keeps its `Paint` and
  /// `Path` caches as mutable fields so that [paint] never allocates. The
  /// overlay builds the stack once and keeps those instances alive, which is
  /// what makes the caches worth having.
  ScanLayer();

  /// Which slot this layer occupies. Used for ordering, hiding and replacing.
  ScanLayerKind get kind;

  /// Whether this layer's output can change between frames.
  ///
  /// Returning `false` lets the animation core stop ticking entirely while the
  /// layer is on screen. It is a promise, not a hint: a static layer that reads
  /// animated values would freeze.
  bool get animated => true;

  /// Whether this layer returns a widget from [buildEffect] or [buildOverlay].
  ///
  /// Declared explicitly (rather than probed) so the overlay can decide whether
  /// it needs a widget-level effect stack without calling either hook.
  bool get wantsWidget => false;

  /// Whether this layer returns a widget from [buildOverlay].
  bool get wantsOverlay => false;

  /// Draws the layer.
  ///
  /// [size] is the overlay size; [frame] is the shared snapshot. Implementations
  /// must be pure with respect to their own allocation: mutate cached [Paint]
  /// and `Path` objects, never create new ones.
  void paint(Canvas canvas, Size size, ScanFxFrame frame);

  /// An optional widget rendered *under* the painter.
  ///
  /// This exists because a genuine frosted backdrop needs [BackdropFilter],
  /// which is a widget-level effect that cannot be expressed as canvas calls.
  /// Only backdrop layers use it, and returning `null` (the default) keeps the
  /// overlay a single `CustomPaint` plus whatever widgets it genuinely needs.
  Widget? buildEffect(BuildContext context, ScanFxFrame frame) => null;

  /// An optional widget rendered *above* the painter.
  ///
  /// The counterpart to [buildEffect]: this one draws on top of the frame and
  /// every effect, which is where host-facing chrome such as the idle hint or a
  /// banking-mode confirmation lives. It is called on state changes rather than
  /// on every tick, so an implementation that needs smooth motion should use
  /// Flutter's implicit animations.
  Widget? buildOverlay(BuildContext context, ScanFxFrame frame) => null;
}

/// Wraps a host-supplied [CustomPainter] so it can be dropped into the stack.
class CustomScanLayer extends ScanLayer {
  /// Creates a layer from a painter.
  CustomScanLayer(
    this.painter, {
    this.layerKind = ScanLayerKind.effects,
    this.isAnimated = true,
  });

  /// The painter to delegate to.
  final CustomPainter painter;

  /// The slot this layer occupies.
  final ScanLayerKind layerKind;

  /// Whether the painter depends on animated values.
  final bool isAnimated;

  @override
  ScanLayerKind get kind => layerKind;

  @override
  bool get animated => isAnimated;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) =>
      painter.paint(canvas, size);
}
