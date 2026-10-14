import 'dart:ui' show Canvas, Size;

import 'package:flutter/widgets.dart';

import '../../animation/scan_fx_frame.dart';
import '../../theme/qr_scan_fx_theme.dart';
import '../../theme/scan_fx_style.dart';
import '../scan_layer.dart';

/// The idle hint: a small pill of host-facing copy under the scan area.
///
/// The hint is a *widget* rather than canvas text, so it inherits the host app's
/// text scaling, locale, font fallback and letter spacing for free — the parts of
/// text rendering that are genuinely hard to reimplement in a painter.
///
/// It renders above the painter (see [ScanLayer.buildOverlay]) and animates with
/// implicit animations, so a state change rebuilds the overlay once instead of
/// sixty times a second.
class ScanHintLayer extends ScanLayer {
  /// Creates the slot.
  const ScanHintLayer();

  @override
  ScanLayerKind get kind => ScanLayerKind.hint;

  @override
  bool get wantsOverlay => true;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {}

  @override
  Widget buildOverlay(BuildContext context, ScanFxFrame frame) =>
      ScanHintView(frame: frame);
}

/// The default hint pill.
///
/// Hosts can replace this by swapping the whole layer:
///
/// ```dart
/// QrScanFx(
///   layers: (context, stack) =>
///       stack.replace(ScanLayerKind.hint, CustomScanLayer(MyBanner())),
/// )
/// ```
class ScanHintView extends StatelessWidget {
  /// Creates a hint view for the given frame snapshot.
  const ScanHintView({super.key, required this.frame});

  /// The frame snapshot captured when the overlay last rebuilt.
  final ScanFxFrame frame;

  /// The gap between the bottom of the scan area and the pill.
  static const double gap = 24;

  @override
  Widget build(BuildContext context) {
    final theme = frame.theme;
    final visible = frame.state.showsHint;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : theme.motion.hint;

    final bounds = frame.quad.bounds;
    final size = frame.size;
    final axis =
        size.height <= 0 ? 0.0 : ((bounds.bottom + gap) / size.height) * 2 - 1;

    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment(0, (axis - (visible ? 0 : 0.05)).clamp(-0.94, 0.94)),
            child: AnimatedOpacity(
              duration: duration,
              curve: Curves.easeOutCubic,
              opacity: visible ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.hintBackgroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Text(
                    theme.labels.tapToStart,
                    style: theme.resolvedHintStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
