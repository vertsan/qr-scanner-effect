import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../theme/scan_fx_style.dart';
import '../paint/scan_paint_cache.dart';
import '../scan_layer.dart';

/// Shared geometry for the scan-beam family.
///
/// Every beam style needs the same rail: a start point, an end point and a head.
/// Computing that once, in the quad's own rotated frame, means a beam style is
/// a handful of draw calls and nothing else.
///
/// The rail is recomputed for any head position, which is what lets a style draw
/// trailing ghosts (`t - step`) without any extra machinery:
///
/// ```dart
/// computeRail(frame, local, t - 0.05);
/// canvas.drawLine(Offset(ax, ay), Offset(bx, by), cache.stroke);
/// ```
///
/// The current values live in mutable fields rather than a returned record, so a
/// style can call [computeRail] several times per frame without allocating.
abstract class ScanBeamLayer extends ScanLayer {
  /// Creates the base.
  ScanBeamLayer();

  @override
  ScanLayerKind get kind => ScanLayerKind.beam;

  /// Paint objects shared by this layer's draws.
  @protected
  late final ScanPaintCache cache = ScanPaintCache();

  /// Rail start, in the quad's rotated local space.
  @protected
  double ax = 0;

  /// Rail start, in the quad's rotated local space.
  @protected
  double ay = 0;

  /// Rail end, in the quad's rotated local space.
  @protected
  double bx = 0;

  /// Rail end, in the quad's rotated local space.
  @protected
  double by = 0;

  /// The head of the beam, in the quad's rotated local space.
  @protected
  double headX = 0;

  /// The head of the beam, in the quad's rotated local space.
  @protected
  double headY = 0;

  /// Whether this direction produces a trailing band (the four straight
  /// directions do; `diagonal` and `radial` do not).
  @protected
  bool hasBand = false;

  /// Length of the trailing band in logical pixels.
  @protected
  double bandLength = 0;

  /// Which way the band trails from the head, along the travel axis.
  @protected
  double bandSign = -1;

  /// Whether the band is perpendicular to the x axis.
  @protected
  bool bandVertical = true;

  /// The current span across the target, `1` while scanning and `~0.15` when a
  /// target is detected.
  @protected
  double span = 1;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    if (!frame.state.showsBeam) return;
    final quad = frame.quad;
    final local = localRect(quad);
    if (local.isEmpty) return;

    span = frame.beamSpan.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(quad.center.dx, quad.center.dy);
    canvas.rotate(quad.rotation);
    final t = frame.beamPosition(frame.theme.beam);
    computeRail(frame, local, t);
    drawBeam(canvas, local, frame, t);
    canvas.restore();
  }

  /// The axis-aligned rectangle the quad becomes once the canvas is rotated onto
  /// it. The beam is computed here and the canvas transform puts it back.
  @protected
  Rect localRect(ScanFxQuad quad) {
    final width = (quad.topRight - quad.topLeft).distance;
    final height = (quad.bottomLeft - quad.topLeft).distance;
    return Rect.fromCenter(center: Offset.zero, width: width, height: height);
  }

  /// Fills the rail fields for a head at [t] (`0..1`) inside [local].
  ///
  /// Called once per draw, and any number of extra times for trailing ghosts.
  @protected
  void computeRail(ScanFxFrame frame, Rect local, double t) {
    final options = frame.theme.beam;
    final width = local.width;
    final height = local.height;
    final cx = local.center.dx;
    final cy = local.center.dy;
    final s = span;
    hasBand = false;
    bandSign = -1;
    bandVertical = true;

    switch (options.direction) {
      case ScanBeamDirection.down:
        final y = cy + (t - 0.5) * height * s;
        ax = local.left;
        ay = y;
        bx = local.right;
        by = y;
        headX = cx;
        headY = y;
        hasBand = true;
        bandVertical = true;
        bandSign = -1;
        bandLength = height * s * options.trail;

      case ScanBeamDirection.up:
        final y = cy - (t - 0.5) * height * s;
        ax = local.left;
        ay = y;
        bx = local.right;
        by = y;
        headX = cx;
        headY = y;
        hasBand = true;
        bandVertical = true;
        bandSign = 1;
        bandLength = height * s * options.trail;

      case ScanBeamDirection.right:
        final x = cx + (t - 0.5) * width * s;
        ax = x;
        ay = local.top;
        bx = x;
        by = local.bottom;
        headX = x;
        headY = cy;
        hasBand = true;
        bandVertical = false;
        bandSign = -1;
        bandLength = width * s * options.trail;

      case ScanBeamDirection.left:
        final x = cx - (t - 0.5) * width * s;
        ax = x;
        ay = local.top;
        bx = x;
        by = local.bottom;
        headX = x;
        headY = cy;
        hasBand = true;
        bandVertical = false;
        bandSign = 1;
        bandLength = width * s * options.trail;

      case ScanBeamDirection.diagonal:
        // The rail always runs at 45 degrees to the quad's own axes, so it
        // rotates with a rotated code instead of cutting across it.
        const unit = 0.7071067811865476;
        final travelled = (t - 0.5) * s * (width + height) * 0.5;
        headX = travelled * unit;
        headY = travelled * unit;
        final half = math.min(width, height) * unit;
        ax = headX - unit * half;
        ay = headY - unit * half;
        bx = headX + unit * half;
        by = headY + unit * half;

      case ScanBeamDirection.radial:
        final angle = t * 2 * math.pi - math.pi / 2;
        final dx = math.cos(angle);
        final dy = math.sin(angle);
        final radius = math.min(width, height) * 0.5;
        ax = dx * radius * 0.12;
        ay = dy * radius * 0.12;
        bx = dx * radius;
        by = dy * radius;
        headX = bx;
        headY = by;
    }
  }

  /// Draws the beam with the rail already filled by [computeRail].
  @protected
  void drawBeam(Canvas canvas, Rect local, ScanFxFrame frame, double t);
}
