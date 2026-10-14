import 'package:flutter/rendering.dart';

import '../animation/scan_fx_director.dart';
import 'scan_layer_stack.dart';

/// Paints an entire [ScanLayerStack] from a single [ScanFxDirector] frame.
///
/// Two details matter here:
///
/// * `repaint: director` makes the render object listen to the animation core
///   directly, so a tick repaints **without rebuilding a single widget**.
/// * [shouldRepaint] compares the captured [revision] with the live one, so a
///   metric change (new size, new theme) still forces a repaint while an
///   unrelated rebuild does not.
class ScanLayerPainter extends CustomPainter {
  /// Creates a painter for [stack].
  ScanLayerPainter({
    required this.director,
    required this.stack,
  })  : revision = director.revision,
        super(repaint: director);

  /// The animation core that supplies frames.
  final ScanFxDirector director;

  /// The layers to draw, in order.
  final ScanLayerStack stack;

  /// The director revision captured when this painter was created.
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = director.frameFor(size);
    final entries = stack.entries;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (!entry.visible) continue;
      entry.layer.paint(canvas, size, frame);
    }
  }

  @override
  bool shouldRepaint(covariant ScanLayerPainter oldDelegate) =>
      oldDelegate.director != director ||
      oldDelegate.revision != revision ||
      oldDelegate.stack != stack;
}
