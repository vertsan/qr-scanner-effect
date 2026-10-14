import 'dart:ui' show Canvas, Size;

import 'package:flutter/foundation.dart' show protected;

import '../../animation/scan_fx_frame.dart';
import '../../state/scan_fx_state.dart';
import '../../theme/scan_fx_style.dart';
import '../paint/scan_paint_cache.dart';
import '../paint/scan_path_cache.dart';
import '../scan_layer.dart';

/// Shared behaviour for the burst family (success, error and invalid).
///
/// A burst is a *one-shot*: the director drives a single `0..1` progress value
/// and every effect reads it through [ScanFxFrame.local], so a stagger between
/// sub-effects costs nothing but a different interval.
///
/// Concrete effects declare the slot they occupy through `super(kind)`, so a
/// theme that only wants to hide its success burst can do exactly that:
/// `stack.hide(ScanLayerKind.success)`.
///
/// ### Reduce-motion contract
///
/// Under reduce-motion the director jumps the burst to its end, which would
/// leave a "fade out" effect invisible. Every effect therefore has its own
/// explicit steady state that it holds instead: the result of the effect without
/// the motion. That is why a colour wash stays tinted and a glow stays lit
/// rather than blinking past the user.
abstract class ScanEffectLayer extends ScanLayer {
  /// Creates the base, occupying [kind].
  ScanEffectLayer(this.kind);

  @override
  final ScanLayerKind kind;

  /// Paint objects shared by this layer's draws.
  @protected
  late final ScanPaintCache cache = ScanPaintCache();

  /// Outline cache shared by this layer's draws.
  @protected
  late final ScanQuadPathCache paths = ScanQuadPathCache();

  /// The burst progress of a **success** burst, or `-1` when the overlay is not
  /// in [ScanFxState.success].
  ///
  /// Returning a sentinel instead of `null` keeps the check allocation-free.
  @protected
  double successBurst(ScanFxFrame frame) =>
      frame.state == ScanFxState.success ? frame.feedback : -1;

  /// The burst progress of a **fault** burst ([ScanFxState.error] or
  /// [ScanFxState.invalid]), or `-1` otherwise.
  ///
  /// Fault effects share their implementation and pick their colour from
  /// [ScanFxFrame.stateColor], which is what keeps `invalid` a first-class state
  /// without duplicating a single painter.
  @protected
  double faultBurst(ScanFxFrame frame) => switch (frame.state) {
        ScanFxState.error || ScanFxState.invalid => frame.feedback,
        _ => -1,
      };

  /// The opacity every effect settles on under reduce-motion.
  @protected
  double steadyState(ScanFxFrame frame, double peak) => peak * frame.intensity;

  /// A one-shot envelope that ramps up over [attack] and decays to zero.
  ///
  /// [burst] is the `0..1` burst progress. Peaking early and decaying slowly is
  /// what makes a burst read as an *event* rather than as a state change.
  @protected
  double envelope(double burst, {double attack = 0.22}) {
    if (burst <= 0 || burst >= 1) return 0;
    if (burst < attack) return burst / attack;
    return 1 - (burst - attack) / (1 - attack);
  }
}

/// A [ScanEffectLayer] that occupies the success slot.
///
/// Effects extending this answer "what does a successful read look like?" and
/// are hidden or replaced as a group through [ScanLayerKind.success].
abstract class ScanSuccessEffect extends ScanEffectLayer {
  /// Creates the base.
  ScanSuccessEffect() : super(ScanLayerKind.success);
}

/// A [ScanEffectLayer] that occupies the fault slot.
///
/// Effects extending this answer "what does a failed or invalid read look
/// like?" — the two states deliberately share one slot because they share one
/// look, tinted by [ScanFxFrame.stateColor]. Hide or replace the whole family
/// through [ScanLayerKind.error].
abstract class ScanFaultEffect extends ScanEffectLayer {
  /// Creates the base.
  ScanFaultEffect() : super(ScanLayerKind.error);
}

/// A layer that paints nothing.
///
/// Used for the `none` variants of the style enums. It keeps its slot in the
/// stack so `ScanLayerStack.replace(kind, ...)` still finds something to
/// replace, and it reports [animated] as `false` so a theme that opts out of
/// every burst does not keep the ticker alive.
class NoEffectLayer extends ScanLayer {
  /// Creates a no-op layer occupying [kind].
  NoEffectLayer(this.kind);

  @override
  final ScanLayerKind kind;

  @override
  bool get animated => false;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {}
}
