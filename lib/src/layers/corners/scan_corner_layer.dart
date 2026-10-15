import 'dart:ui';

import 'package:flutter/foundation.dart' show protected;

import '../../animation/scan_fx_frame.dart';
import '../../geometry/scan_fx_quad.dart';
import '../../geometry/scan_fx_shapes.dart';
import '../../theme/scan_fx_style.dart';
import '../../theme/scan_fx_tunables.dart';
import '../paint/scan_glow.dart';
import '../paint/scan_paint_cache.dart';
import '../scan_layer.dart';

/// Shared behaviour for the corner-bracket family.
///
/// All three styles answer the same question — "where do the four brackets
/// sit?" — and differ only in how each bracket is inked. The geometry, the
/// convergence towards the frame as the lock settles, the state tint and the
/// reveal fade therefore live here once.
///
/// Brackets read the *live quad*, so they follow a rotated or perspective-skewed
/// target exactly, and they converge inwards as `focus` approaches `1`, which is
/// what makes the lock feel like it is closing on the code.
abstract class ScanCornerLayer extends ScanLayer {
  /// Creates the base.
  ScanCornerLayer();

  @override
  ScanLayerKind get kind => ScanLayerKind.corners;

  /// Paint objects shared by this layer's draws.
  @protected
  late final ScanPaintCache cache = ScanPaintCache();

  Path? _path;
  ScanFxQuad? _pathQuad;
  double _pathArm = -1;
  double _pathInset = -1;
  double _pathBendRadius = -1;

  /// The cap applied to the bracket arms.
  StrokeCap get cap => StrokeCap.round;

  /// The colour of the brackets in the current state.
  ///
  /// Brackets keep the theme's corner colour while scanning and take over the
  /// state colour on a burst, so success and error tint the whole frame at once.
  Color colorFor(ScanFxFrame frame) =>
      frame.state.isTerminal ? frame.stateColor : frame.theme.cornerColor;

  /// How far each bracket is pulled towards the frame centre.
  ///
  /// `4` px while scanning, `0` when the lock has settled. Reduce-motion zeroes
  /// it, because it is a motion cue rather than a state cue.
  double insetFor(ScanFxFrame frame) =>
      frame.reduceMotion ? 0 : (1 - frame.focus) * 4;

  /// The bracket arm length in logical pixels.
  double armFor(ScanFxFrame frame) =>
      frame.quad.shortestSide * frame.theme.cornerArmFraction;

  /// Radius used to soften the bracket's inside bend.
  @protected
  double bendRadiusFor(ScanFxFrame frame) => 0;

  /// Corner [index] of [quad] (`0` is the top-left of the ring).
  @protected
  static Offset cornerOf(ScanFxQuad quad, int index) =>
      ScanFxShapes.quadCorner(quad, index);

  /// The origin of the bracket for corner [index], pulled [inset] px towards the
  /// frame centre.
  @protected
  static Offset bracketOrigin(ScanFxQuad quad, int index, double inset) =>
      ScanFxShapes.insetQuadCorner(quad, index, inset);

  /// The unit vector from [from] towards [to].
  @protected
  static Offset unit(Offset from, Offset to) =>
      ScanFxShapes.unitVector(from, to);

  /// The four brackets as a single stroked path.
  ///
  /// The path is reused across frames and rebuilt in place with [Path.reset],
  /// so the focus morph — which moves the quad on every frame — stays
  /// allocation-free. It is only rebuilt when the quad, the arm length or the
  /// inset actually changed.
  @protected
  Path bracketPath(ScanFxFrame frame) {
    final quad = frame.quad;
    final arm = armFor(frame);
    final inset = insetFor(frame);
    final bendRadius = bendRadiusFor(frame);
    if (_path != null &&
        _pathQuad == quad &&
        _pathArm == arm &&
        _pathInset == inset &&
        _pathBendRadius == bendRadius) {
      return _path!;
    }
    final path = _path ??= Path();
    path.reset();
    ScanFxShapes.addQuadCornerArms(
      path,
      quad,
      inset,
      arm,
      bendRadius: bendRadius,
    );
    _pathQuad = quad;
    _pathArm = arm;
    _pathInset = inset;
    _pathBendRadius = bendRadius;
    return path;
  }

  /// The glow strength applied to the brackets.
  ///
  /// Overridden by [ScanCornerStyle.glowing], which forces a minimum bloom.
  @protected
  double glowFor(ScanFxFrame frame) => frame.glow;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final color = ScanFxPalette.fade(colorFor(frame), frame.reveal);
    if (color.a <= 0.004) return;

    final path = bracketPath(frame);
    final width = frame.theme.cornerStrokeWidth;
    final sigma = ScanGlow.sigmaFor(glowFor(frame), width);

    if (sigma > 0) {
      cache.applyGlowBlur(sigma);
      cache.glow
        ..color = color
        ..strokeWidth = width * 1.4
        ..strokeCap = cap;
      canvas.drawPath(path, cache.glow);
    }

    cache.stroke
      ..color = color
      ..strokeWidth = width
      ..strokeCap = cap;
    canvas.drawPath(path, cache.stroke);
  }
}
