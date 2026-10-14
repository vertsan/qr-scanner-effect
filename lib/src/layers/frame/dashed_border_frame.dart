import 'dart:ui' show Path;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_frame_path.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../../theme/scan_fx_style.dart';
import 'scan_frame_layer.dart';

/// A marching dashed border.
///
/// The dashes walk around the outline while scanning, which gives the frame a
/// sense of direction without adding a second element to the composition.
///
/// Dashing an arbitrary outline means walking its path metrics, which allocates,
/// so the pattern is quantised into [buckets] steps per loop: the outline is
/// rebuilt a bounded number of times per cycle rather than on every tick, and it
/// freezes entirely under reduce-motion.
class DashedBorderFrame extends ScanFrameLayer {
  /// Creates the style.
  DashedBorderFrame();

  /// How many distinct dash positions one loop is divided into.
  static const int buckets = 24;

  /// One full march, in milliseconds.
  static const double periodMs = 3200;

  @override
  ScanFrameShape get shape => ScanFrameShape.dashedBorder;

  @override
  bool get animated => true;

  @override
  int outlinePhaseKey(ScanFxFrame frame) =>
      frame.reduceMotion ? 0 : (frame.channel(periodMs) * buckets).floor();

  @override
  Path buildOutline(ScanFxFrame frame) {
    final solid = ScanFxShapes.roundedQuad(frame.quad, frame.cornerRadius);
    final side = frame.quad.shortestSide;
    final dash = (side * 0.075).clamp(4.0, 26.0);
    final gap = (side * 0.05).clamp(3.0, 18.0);
    final phase = frame.reduceMotion ? 0.0 : frame.channel(periodMs);
    return ScanFramePath.dashed(
      solid,
      dash: dash,
      gap: gap,
      offset: -phase * (dash + gap),
    );
  }
}
