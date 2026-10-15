// The scanner overlay itself: the `qr_scan_fx` frame, sized for the reference
// and given this screen's own status seat.
//
// The package draws the corners, the sweep and the lock-on. It never sees a
// payload — this file hands it a size, a theme and a controller, and nothing
// else.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

import 'scanner_style.dart';

/// The `qr_scan_fx` overlay, tuned to the reference's minimal scanner.
class QRScanOverlay extends StatelessWidget {
  /// Creates the overlay.
  const QRScanOverlay({
    super.key,
    required this.controller,
    this.sensorSize,
    this.onRetry,
    this.confirmationBuilder,
  });

  /// The overlay's imperative handle. It never receives a decoded value.
  final QrScanFxController controller;

  /// The resolution of the camera frame that produced a detection, so the
  /// lock-on lands on the code instead of drifting.
  final Size? sensorSize;

  /// Wired to the retry button on the status notice.
  final VoidCallback? onRetry;

  /// The seat the app fills once the overlay reports a successful read.
  final WidgetBuilder? confirmationBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        // Aim for the reference's 280–330 dp band, bound by the two things that
        // can genuinely clip it: the card's width, and the room under the frame
        // that the hint pill and the status notice need.
        //
        // The package clamps the result to 82% of the card's short side as well,
        // so a very short card degrades gracefully instead of overflowing.
        final double widthBound = size.width - 32;
        final double heightBound = size.height - ScannerStyle.frameFootroom;
        final double requested = math.max(
          ScannerStyle.frameFloor,
          math.min(
            math.min(widthBound, heightBound),
            ScannerStyle.frameMaxSide,
          ),
        );
        final Size frame = Size.square(requested);

        return QrScanFx.banking(
          controller: controller,
          theme: ScannerStyle.overlay,
          sensorSize: sensorSize,
          previewFit: BoxFit.cover,
          scanAreaSize: frame,
          onRetry: onRetry,
          confirmationBuilder: confirmationBuilder,
          // The package's default seat sits inside the scan area, which would
          // land on the frame. Pin it to the foot of the card instead, level with
          // where the hint pill appears.
          messageBuilder: (BuildContext context) => Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScanFxStatusNotice(
                message: controller.message,
                fallback: ScannerStyle.overlay.labels.invalid,
                onRetry: onRetry,
                backgroundColor: ScannerStyle.overlay.hintBackgroundColor,
                foregroundColor: ScannerStyle.overlay.hintTextColor,
                maxWidth: 320,
              ),
            ),
          ),
        );
      },
    );
  }
}
