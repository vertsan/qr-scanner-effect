// The compact header that sits over the camera preview: a history shortcut on
// the left, the screen title centred, and the close button in the upper-right
// corner, the way the reference lays it out.

import 'package:flutter/material.dart';

/// The scanner's title bar, designed to be laid over a camera preview.
///
/// It is deliberately transparent: the preview (and the scrim above it) provide
/// the contrast, so the header only draws white text and two white icons.
class ScannerHeader extends StatelessWidget {
  /// Creates a header.
  const ScannerHeader({
    super.key,
    required this.title,
    this.onClose,
    this.onHistory,
  });

  /// The centred screen title.
  final String title;

  /// Called when the close button is tapped. The button is hidden when `null`.
  final VoidCallback? onClose;

  /// Called when the history shortcut is tapped. Hidden when `null`.
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _Slot(
          child: onHistory == null
              ? null
              : IconButton(
                  onPressed: onHistory,
                  tooltip: 'Recent scans',
                  icon: const Icon(Icons.history),
                  color: Colors.white,
                  iconSize: 24,
                ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        _Slot(
          child: onClose == null
              ? null
              : IconButton(
                  onPressed: onClose,
                  tooltip: 'Close scanner',
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  iconSize: 24,
                ),
        ),
      ],
    );
  }
}

/// A fixed-width slot, so the title stays optically centred whether or not the
/// buttons beside it are shown.
class _Slot extends StatelessWidget {
  const _Slot({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(width: 48, child: child);
}
