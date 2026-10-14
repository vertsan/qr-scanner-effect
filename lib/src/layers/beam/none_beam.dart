import 'dart:ui' show Canvas, Rect, Size;

import '../../animation/scan_fx_frame.dart';
import 'scan_beam_layer.dart';

/// Draws no beam.
///
/// The scan area is still framed and the lock-on still runs; there is simply no
/// sweep. Hosts that prefer to hide the beam can equally drop the layer with
/// `stack.hide(ScanLayerKind.beam)`, but a real style keeps the theme
/// declarative — and lets a preset say "no beam" without also describing a stack.
class NoneBeam extends ScanBeamLayer {
  /// Creates the style.
  NoneBeam();

  @override
  bool get animated => false;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {}

  @override
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t) {}
}
