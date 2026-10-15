// The camera card: a nearly full-width preview with rounded bottom corners, with
// the header laid over it inside the top safe area.
//
// It is deliberately dumb. It takes the camera widget, the scanner overlay and
// the header and arranges them; *how* the camera runs lives in the page, and
// *how the frame is drawn* lives in [QRScanOverlay].

import 'package:flutter/material.dart';

import 'scanner_style.dart';

/// A rounded camera preview card with an optional overlay and a header.
class CameraPreview extends StatelessWidget {
  /// Creates a preview card.
  const CameraPreview({
    super.key,
    required this.camera,
    required this.header,
    this.overlay,
  });

  /// The live camera view. Fills the card.
  final Widget camera;

  /// The scanner overlay drawn over the camera. Pass `null` when the camera
  /// failed, so nothing is painted on top of the error view.
  final Widget? overlay;

  /// The header, placed inside the top safe area, over the preview.
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ScannerStyle.previewInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(ScannerStyle.previewRadius),
        ),
        child: ColoredBox(
          color: ScannerStyle.background,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              camera,
              if (overlay != null) overlay!,
              // A short scrim keeps the status bar and the title legible over a
              // bright frame.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset + 76,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: topInset + 8, left: 4, right: 4),
                  child: header,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
