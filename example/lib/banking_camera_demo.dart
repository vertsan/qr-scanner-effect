// The bank-grade *integration* demo: a real camera, a real torch and a real
// gallery pick, driving `QrScanFx.banking()`.
//
// It shows the one interface that matters for a payment flow:
//
//   camera (host)  ──geometry──▶  qr_scan_fx  ──pixels──▶  screen
//                  └──payload────▶  your backend (never the package)
//
// Run it on a device with a camera:
//
//   cd example && flutter pub get && flutter run -t lib/banking_camera_demo.dart
//
// Android merges in the CAMERA permission from the plugin. On iOS add
// `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to Info.plist.
//
// The camera-free sibling, `banking_demo.dart`, drives the same controller with
// scripted detections and needs no device at all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// The host owns the camera. This is exactly the dependency the *package* never
// takes — it lives here, in the demo, and nowhere in `lib/src/`.
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

import 'payment/khqr.dart';
import 'payment/payment_confirmation_page.dart';
import 'payment/payment_models.dart';
import 'payment/recent_scans_page.dart';
import 'theme.dart';

void main() => runApp(const BankingCameraDemoApp());

class BankingCameraDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const BankingCameraDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'qr_scan_fx · banking camera demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data(),
      home: const BankingCameraPage(),
    );
  }
}

class BankingCameraPage extends StatefulWidget {
  /// Creates the camera-backed demo page.
  const BankingCameraPage({super.key});

  @override
  State<BankingCameraPage> createState() => _BankingCameraPageState();
}

class _BankingCameraPageState extends State<BankingCameraPage> {
  /// The overlay. It never receives a payload — only geometry.
  final QrScanFxController _fx = QrScanFxController();

  /// The camera. Torch on by default, as banking mode expects.
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    torchEnabled: true,
  );

  final ImagePicker _picker = ImagePicker();

  /// The sensor size that produced the current detections, in the preview's
  /// upright orientation. This is the glue that maps sensor pixels onto the
  /// preview the overlay is drawn over.
  Size _sensorSize = Size.zero;

  /// Guards against a stream of detections for the same code restarting the
  /// lock-on or firing a second result.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    // Leave `idle` so the beam is already sweeping before the first code.
    _fx.start();
  }

  @override
  void dispose() {
    _fx.dispose();
    _camera.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Camera → overlay. Geometry only.
  // ---------------------------------------------------------------------------

  /// Hands the overlay a location and reports the read.
  ///
  /// The corner list is the *entire* input the package gets. The decoded value
  /// is read by this app, in [_onDetect], and passed to [_openPayment] — it
  /// never crosses the overlay boundary.
  Future<void> _acquire(
    Size sensorSize,
    List<Offset> corners,
    String? payload,
  ) async {
    if (!sensorSize.isEmpty && sensorSize != _sensorSize) {
      setState(() => _sensorSize = sensorSize);
    }
    _settled = true;
    _fx.lockOn(ScanFxTarget.corners(corners));

    // A real app validates here — off the UI thread — before deciding. This
    // demo accepts the code so the calm success path is what you see; the
    // "Reject" control in the overlay seat shows the other outcome.
    await Future<void>.delayed(const Duration(milliseconds: 760));
    if (!mounted) return;
    _fx.success();

    // Let the success state land, then hand off to the host's payment flow.
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    await _openPayment(payload);
  }

  /// The host's own next step: turn the decoded payload into a payment.
  ///
  /// This is where the `qr_scan_fx` job ends. The package drew the lock-on and
  /// the success; from here the app parses the code and owns every decision.
  Future<void> _openPayment(String? payload) async {
    final KhqrData? data = payload == null ? null : KhqrParser.parse(payload);
    final PaymentRequest request = data == null
        ? const PaymentRequest(
            payee: 'Unverified merchant',
            currency: PaymentCurrency.usd,
          )
        : PaymentRequest.fromKhqr(data);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PaymentConfirmationPage(request: request),
      ),
    );
    if (mounted) _restart();
  }

  /// Opens the saved receipts, newest first.
  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const RecentScansPage(),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_settled || capture.barcodes.isEmpty) return;
    final Barcode code = capture.barcodes.first;
    final List<Offset> corners = code.corners;
    if (corners.length != 4) return; // Nothing to frame without corners.
    // The decoded string is read here, by the app, and kept on this side of the
    // boundary: the overlay receives geometry alone.
    unawaited(
      _acquire(capture.size, corners, code.displayValue ?? code.rawValue),
    );
  }

  // ---------------------------------------------------------------------------
  // Gallery. Same overlay path, a different source of geometry.
  // ---------------------------------------------------------------------------

  Future<void> _pickFromGallery() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted || file == null) return;

    final BarcodeCapture? capture = await _camera.analyzeImage(file.path);
    if (!mounted) return;

    final List<Barcode> codes = capture?.barcodes ?? const <Barcode>[];
    final Barcode? code = codes.isEmpty ? null : codes.first;
    final List<Offset> corners = code?.corners ?? const <Offset>[];

    if (corners.length != 4) {
      _fx.invalid('No QR code found in that image');
      return;
    }
    await _acquire(
      capture?.size ?? Size.zero,
      corners,
      code?.displayValue ?? code?.rawValue,
    );
  }

  // ---------------------------------------------------------------------------

  void _reject() {
    _fx.invalid('This merchant code is not supported');
  }

  void _restart() {
    setState(() => _settled = false);
    _fx.reset();
    _fx.start();
  }

  @override
  Widget build(BuildContext context) {
    // mobile_scanner reports geometry in the sensor's upright orientation; in
    // landscape the preview is the other way around. `previewFit` on the
    // overlay must match `fit` on MobileScanner.
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final Size? sensorSize = _sensorSize.isEmpty
        ? null
        : (landscape
            ? Size(_sensorSize.height, _sensorSize.width)
            : _sensorSize);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: QrScanFx.banking(
        controller: _fx,
        sensorSize: sensorSize,
        previewFit: BoxFit.cover,
        onRetry: _restart,
        child: MobileScanner(
          controller: _camera,
          fit: BoxFit.cover,
          onDetect: _onDetect,
          errorBuilder: (BuildContext context, MobileScannerException error) =>
              _CameraError(error: error),
          placeholderBuilder: (BuildContext context) =>
              const ColoredBox(color: Color(0xFF04070D)),
        ),
        confirmationBuilder: (BuildContext context) =>
            const _ConfirmationCard(),
        controlsBuilder: (BuildContext context) => Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Torch: on by default, and the icon follows the plugin's own
                  // torch state rather than a local guess.
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _camera,
                    builder: (
                      BuildContext context,
                      MobileScannerState state,
                      _,
                    ) =>
                        IconButton.filledTonal(
                      onPressed: _camera.toggleTorch,
                      tooltip: state.torchState == TorchState.on
                          ? 'Torch off'
                          : 'Torch on',
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flashlight_on
                            : Icons.flashlight_off,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _pickFromGallery,
                    tooltip: 'Scan from gallery',
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _reject,
                    tooltip: 'Simulate a rejected code',
                    icon: const Icon(Icons.block_outlined),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _openHistory,
                    tooltip: 'Recent scans',
                    icon: const Icon(Icons.history),
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

/// The confirmation seat: what *the app* says after its own validation.
///
/// It never says "paid". The overlay cannot know that, and must not imply it.
class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E3A5F)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Code captured',
              style: TextStyle(
                color: Color(0xFFF2F6FC),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Validated by the app — opening the payment flow…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9FB3CC),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
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
      color: const Color(0xFF04070D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Camera unavailable.\n${error.errorDetails?.message ?? error.errorCode.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9FB3CC)),
          ),
        ),
      ),
    );
  }
}
