import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/scan_fx_state.dart';

/// A calm status pill: a message with an optional retry affordance.
///
/// This is the widget [QrScanFx.banking] puts in its `messageBuilder` seat when
/// the state is [ScanFxState.invalid] or [ScanFxState.error]. It is a plain
/// presentational widget, so it can also be used anywhere else, or replaced
/// entirely by passing your own `messageBuilder`.
///
/// It is deliberately small and boring — no icon animation, no colour wash, no
/// motion beyond a 10 px slide and a fade. A failure in a payment flow should
/// read as *information*, not as an alarm.
///
/// ### Accessibility
///
/// * The text wraps in a [Wrap] rather than a fixed row, so it survives
///   `textScaler` values well past 2.0 without overflowing.
/// * [backgroundColor] and [foregroundColor] default to the banking pair, which
///   is ~17:1; if you override them, check
///   [ScanFxPalette.contrastRatio] is at least `4.5`.
/// * The entrance animation is skipped when the platform asks for reduced
///   motion.
class ScanFxStatusNotice extends StatelessWidget {
  /// Creates a status notice.
  const ScanFxStatusNotice({
    super.key,
    required this.message,
    this.fallback,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.backgroundColor = const Color(0xFF0B1220),
    this.foregroundColor = const Color(0xFFF2F6FC),
    this.textStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    this.maxWidth = 340,
  });

  /// The host copy to display.
  ///
  /// Listening rather than reading means a message set *after* the state already
  /// changed still lands, which matters when a host reports an async rejection.
  final ValueListenable<String?> message;

  /// Copy used when [message] is empty or `null`.
  final String? fallback;

  /// Called when the retry button is tapped. When `null` no button is shown.
  final VoidCallback? onRetry;

  /// The retry button's label.
  final String retryLabel;

  /// The pill's fill.
  final Color backgroundColor;

  /// The text and button colour.
  final Color foregroundColor;

  /// The base text style. [foregroundColor] is applied on top of it.
  final TextStyle textStyle;

  /// The widest the pill will grow before the text wraps.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final style = textStyle.copyWith(color: foregroundColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ValueListenableBuilder<String?>(
        valueListenable: message,
        builder: (BuildContext context, String? value, Widget? _) {
          final text =
              (value == null || value.trim().isEmpty) ? fallback ?? '' : value;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double t, Widget? child) =>
                    Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 10),
                    child: child,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: <Widget>[
                          if (text.isNotEmpty)
                            Text(
                              text,
                              style: style,
                              textAlign: TextAlign.center,
                            ),
                          if (onRetry != null)
                            TextButton(
                              onPressed: onRetry,
                              style: TextButton.styleFrom(
                                foregroundColor: foregroundColor,
                              ),
                              child: Text(retryLabel),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
