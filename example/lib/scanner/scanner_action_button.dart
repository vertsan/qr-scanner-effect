// The pill action button under the preview: dark charcoal with a white icon and
// label at rest, and the app's accent while the control is on.

import 'package:flutter/material.dart';

import 'scanner_style.dart';

/// A pill-shaped action button for the scanner screen.
///
/// It covers every state the screen needs — resting, active (the flashlight is
/// on), busy (the gallery is opening) and disabled (the device has no torch) —
/// without the caller having to restyle it.
class ScannerActionButton extends StatelessWidget {
  /// Creates an action button.
  const ScannerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.busy = false,
    this.semanticLabel,
  });

  /// The leading icon.
  final IconData icon;

  /// The visible label.
  final String label;

  /// Called on tap. When `null` — or while [busy] — the button is disabled, and
  /// a second tap cannot land.
  final VoidCallback? onPressed;

  /// Whether the control is currently on, e.g. the flashlight.
  final bool active;

  /// Whether an async action is in flight: shows a spinner and blocks repeats.
  final bool busy;

  /// Overrides the label announced to screen readers. Defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !busy;
    final Color background =
        enabled && active ? ScannerStyle.pillActive : ScannerStyle.pill;
    final Color foreground = !enabled
        ? ScannerStyle.onDisabled
        : active
            ? ScannerStyle.onPillActive
            : ScannerStyle.onPill;
    final BorderRadius radius =
        BorderRadius.circular(ScannerStyle.pillHeight / 2);

    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Tooltip(
            message: semanticLabel ?? label,
            child: Container(
              height: ScannerStyle.pillHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: enabled && active
                      ? Colors.transparent
                      : ScannerStyle.pillBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (busy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    Icon(icon, size: 20, color: foreground),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
