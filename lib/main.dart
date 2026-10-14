// A runnable demo that drives the `qr_scan_fx` overlay from a real camera.
//
// This file is the *host*: it owns the camera (`mobile_scanner`), decodes the
// QR content, and hands `qr_scan_fx` geometry only. The package never sees the
// camera and never sees the payload — it just draws the focus effect.
//
// Run it on a device/emulator with a camera:
//
//   flutter run
//
// Android already declares the CAMERA permission (the plugin's manifest merges
// it in). On iOS you would add `NSCameraUsageDescription` to Info.plist.

import 'dart:async';

import 'package:flutter/material.dart';
// The demo drives a real camera. `mobile_scanner` is a *dev* dependency on
// purpose: the published package stays free of runtime dependencies, so this
// import is only allowed here because this file is the dev-only entrypoint.
// ignore: depend_on_referenced_packages
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

void main() {
  runApp(const QrScanFxDemoApp());
}

class QrScanFxDemoApp extends StatelessWidget {
  const QrScanFxDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'qr_scan_fx demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        // Install the overlay theme app-wide; a widget-level `theme:` would
        // override it.
        extensions: const <ThemeExtension<dynamic>>[QrScanFxTheme.dark],
      ),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  /// Frame, brackets, beam, lock-on and bursts — all drawn from geometry.
  final QrScanFxController _fx = QrScanFxController();

  /// The camera. `qr_scan_fx` does not depend on this; it only consumes the
  /// geometry that comes out of `onDetect`.
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  /// Look and feel. `copyWith` keeps the calm dark motion and swaps the style.
  final QrScanFxTheme _theme = QrScanFxTheme.dark.copyWith(
    cornerColor: const Color(0xFF7CF0FF),
    beamColor: const Color(0xFF7CF0FF),
    frameGlowColor: const Color(0xFF3AA0FF),
    beamStyle: ScanBeamStyle.glowingLaser,
    lockStyle: ScanLockStyle.springSnap,
    successStyle: ScanSuccessStyle.checkMorph,
  );

  /// The camera input size that produced the current detections, in the
  /// preview's upright orientation. Updated from each capture.
  Size _sensorSize = Size.zero;

  /// Set while a read is being acknowledged, so the stream of detections from
  /// one code cannot restart the lock-on or fire a second result.
  bool _settled = false;

  String? _result;
  ScanFxState _state = ScanFxState.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Leave `idle` so the beam is already sweeping before the first code.
    _fx.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fx.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the overlay when the app is not in front — it costs nothing while
    // paused. The camera handles its own lifecycle.
    switch (state) {
      case AppLifecycleState.resumed:
        _fx.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _fx.pause();
    }
  }

  // ---------------------------------------------------------------------------
  // From the camera to the overlay
  // ---------------------------------------------------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_settled) return;

    if (capture.barcodes.isEmpty) return;
    final Barcode code = capture.barcodes.first;

    // Keep the sensor size fresh — it is what maps detection geometry (in
    // camera-image pixels) onto the preview's coordinate space. `fit` on the
    // MobileScanner below must match `previewFit` on the overlay.
    if (!capture.size.isEmpty && capture.size != _sensorSize) {
      setState(() => _sensorSize = capture.size);
    }

    final List<Offset> corners = code.corners;
    if (corners.length != 4) return; // Nothing to frame without corners.

    _settled = true;

    // THE ONLY THING THE PACKAGE NEEDS: where the code is, in sensor pixels.
    // Corners (not a rect) let a rotated or skewed code be framed exactly.
    _fx.lockOn(ScanFxTarget.corners(corners));

    // The package is a renderer, so *we* decide what the code means. Wait for
    // the lock-on to land, then report the read and show the value.
    Timer(const Duration(milliseconds: 720), () {
      if (!mounted) return;
      setState(() => _result = code.displayValue ?? code.rawValue ?? '');
      _fx.success();
    });
  }

  void _scanAgain() {
    setState(() {
      _result = null;
      _settled = false;
    });
    _fx.reset();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // mobile_scanner reports geometry in the sensor's upright orientation. In
    // landscape the preview is the other way around, so swap the sensor size to
    // keep the mapping aligned (this mirrors the plugin's own overlay).
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final Size? sensorSize = _sensorSize.isEmpty
        ? null
        : (landscape
            ? Size(_sensorSize.height, _sensorSize.width)
            : _sensorSize);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The overlay draws on top of the camera preview it is given.
          QrScanFx(
            controller: _fx,
            theme: _theme,
            sensorSize: sensorSize,
            previewFit: BoxFit.cover,
            onStateChanged: (ScanFxState state) =>
                setState(() => _state = state),
            child: MobileScanner(
              controller: _camera,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(error: error),
            ),
          ),
          _TopBar(
            onTorch: _camera.toggleTorch,
            onSwitchCamera: _camera.switchCamera,
          ),
          _BottomPanel(
            state: _state,
            result: _result,
            onScanAgain: _scanAgain,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onTorch, required this.onSwitchCamera});

  final VoidCallback onTorch;
  final VoidCallback onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            const _Pill(text: 'qr_scan_fx'),
            const Spacer(),
            _IconAction(icon: Icons.flashlight_on, onTap: onTorch),
            _IconAction(icon: Icons.cameraswitch, onTap: onSwitchCamera),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.state,
    required this.result,
    required this.onScanAgain,
  });

  final ScanFxState state;
  final String? result;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.transparent, Color(0xCC000000)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'State: ${state.name}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result ?? 'Point the camera at a QR code',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (result != null) ...<Widget>[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onScanAgain,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan again'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.no_photography, color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              Text(
                'Camera unavailable\n${error.errorDetails?.message ?? error.errorCode.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
