// The bank-grade *integration* demo: a real camera, a real torch and a real
// gallery pick, driving `QrScanFx.banking()` inside the reference's scanner
// screen.
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
//
// The screen itself is assembled from the reusable widgets in `lib/scanner/`;
// this file owns only what a host app owns — the camera lifecycle, the image
// picker, and the decision about what a decoded code means.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// The host owns the camera. This is exactly the dependency the *package* never
// takes — it lives here, in the demo, and nowhere in `lib/src/`.
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

import 'payment/khqr.dart';
import 'payment/payment_confirmation_page.dart';
import 'payment/payment_models.dart';
import 'payment/recent_scans_page.dart';
import 'scanner/camera_preview.dart';
import 'scanner/payment_provider_grid.dart';
import 'scanner/qr_scan_overlay.dart';
import 'scanner/scanner_action_button.dart';
import 'scanner/scanner_header.dart';
import 'scanner/scanner_state_views.dart';
import 'scanner/scanner_style.dart';
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

  /// Guards the gallery pick, so a double tap cannot open two pickers.
  bool _picking = false;

  /// Guards the hand-off, so one code cannot open two payment screens.
  bool _handingOff = false;

  @override
  void initState() {
    super.initState();
    // Leave `idle` so the beam is already sweeping before the first code. The
    // overlay seeds its animation from the controller's current state when it
    // attaches, so announcing this before the first build is safe.
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
    if (_settled) return;
    _settled = true;

    if (!sensorSize.isEmpty && sensorSize != _sensorSize) {
      setState(() => _sensorSize = sensorSize);
    }
    _fx.lockOn(ScanFxTarget.corners(corners));
    // A medium tap is the confirmation that lands without startling anyone.
    unawaited(HapticFeedback.mediumImpact());

    // A real app validates here — off the UI thread — before deciding. This
    // demo accepts the code so the calm success path is what you see; a
    // rejection is still reachable by uploading an image with no code in it.
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
    if (_handingOff) return;

    // Never trust a payload because it decoded: an empty one is not a payment
    // request, it is a failed read.
    final String value = payload?.trim() ?? '';
    if (value.isEmpty) {
      _fx.invalid('That code carried no data');
      return;
    }

    _handingOff = true;
    final KhqrData? data = KhqrParser.parse(value);
    // A code that is not EMVCo/KHQR still opens the flow, as an unverified
    // merchant, so the demo can show that path too.
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
    if (_picking || _settled) return;
    setState(() => _picking = true);

    try {
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
    } on MobileScannerException {
      if (mounted) _fx.invalid('That image could not be read');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Small host actions.
  // ---------------------------------------------------------------------------

  void _toggleTorch() {
    unawaited(HapticFeedback.selectionClick());
    unawaited(_camera.toggleTorch());
  }

  Future<void> _retryCamera() async {
    try {
      await _camera.start();
    } on MobileScannerException {
      // The controller publishes the failure to its own state, which the error
      // view is already built from.
    }
  }

  void _close() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // Run through `main.dart` and this page is pushed, so closing pops back to
    // the chooser. Run standalone with `-t` and it *is* the first screen, so say
    // so rather than leaving the button looking broken.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('This demo opens on the scanner, so there is no screen '
              'to return to.'),
        ),
      );
  }

  void _restart() {
    if (!mounted) return;
    setState(() {
      _settled = false;
      _handingOff = false;
    });
    _fx.reset();
    _fx.start();
  }

  // ---------------------------------------------------------------------------
  // Composition.
  // ---------------------------------------------------------------------------

  Widget _cameraView() => MobileScanner(
        controller: _camera,
        fit: BoxFit.cover,
        onDetect: _onDetect,
        errorBuilder: (BuildContext context, MobileScannerException error) =>
            ScannerErrorState(error: error, onRetry: _retryCamera),
        placeholderBuilder: (BuildContext context) =>
            const ScannerLoadingState(),
      );

  Widget _header() => ScannerHeader(
        title: 'QR Scan',
        onHistory: _openHistory,
        onClose: _close,
      );

  Widget _preview(Size? sensorSize, bool failed) => CameraPreview(
        camera: _cameraView(),
        // Nothing is painted over an error or a loading view.
        overlay: failed
            ? null
            : QRScanOverlay(
                controller: _fx,
                sensorSize: sensorSize,
                onRetry: _restart,
                confirmationBuilder: (BuildContext context) =>
                    const _ConfirmationCard(),
              ),
        header: _header(),
      );

  Widget _flashButton(MobileScannerState state) {
    final bool available = state.torchState != TorchState.unavailable;
    final bool on = state.torchState == TorchState.on;
    return ScannerActionButton(
      icon: on ? Icons.flashlight_on : Icons.flashlight_off,
      label: 'Flash',
      active: on,
      onPressed: available ? _toggleTorch : null,
      semanticLabel: available ? null : 'Flash unavailable on this device',
    );
  }

  Widget _uploadButton() => ScannerActionButton(
        icon: Icons.photo_library_outlined,
        label: 'Upload QR',
        busy: _picking,
        onPressed: _settled ? null : _pickFromGallery,
      );

  // Portrait: preview on top, controls stacked underneath. The preview takes
  // every pixel the controls do not need.
  Widget _tallLayout(MobileScannerState state, bool failed, Size? sensorSize) {
    return Column(
      children: <Widget>[
        Expanded(child: _preview(sensorSize, failed)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ScannerStyle.gutter),
          child: Row(
            children: <Widget>[
              Expanded(child: _flashButton(state)),
              const SizedBox(width: 12),
              Expanded(child: _uploadButton()),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const PaymentProviderGrid(),
        const SizedBox(height: 18),
      ],
    );
  }

  // Landscape: the preview keeps the height it has, and the controls move to a
  // column beside it instead of crushing it. The column scrolls, so a short
  // window or a large text scale cannot overflow.
  Widget _wideLayout(MobileScannerState state, bool failed, Size? sensorSize) {
    return Row(
      children: <Widget>[
        Expanded(flex: 3, child: _preview(sensorSize, failed)),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ScannerStyle.gutter,
                  ),
                  child: Column(
                    children: <Widget>[
                      _flashButton(state),
                      const SizedBox(height: 12),
                      _uploadButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const PaymentProviderGrid(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // mobile_scanner reports geometry in the sensor's upright orientation; in
    // landscape the preview is the other way around. `previewFit` on the overlay
    // must match `fit` on MobileScanner.
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final Size? sensorSize = _sensorSize.isEmpty
        ? null
        : (landscape
            ? Size(_sensorSize.height, _sensorSize.width)
            : _sensorSize);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ScannerStyle.background,
        // The preview runs under the status bar on purpose; only the bottom and
        // the horizontal insets are taken away from it.
        body: SafeArea(
          top: false,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _camera,
            builder: (
              BuildContext context,
              MobileScannerState state,
              Widget? _,
            ) {
              final bool failed = state.error != null;
              return landscape
                  ? _wideLayout(state, failed, sensorSize)
                  : _tallLayout(state, failed, sensorSize);
            },
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
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: ScannerStyle.pill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ScannerStyle.pillBorder),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Code captured',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Validated by the app — opening the payment flow…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.onSurfaceVariant,
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
