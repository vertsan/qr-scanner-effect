// The package's own demo — the reference's scanner screen, self-contained.
//
// pubspec.yaml (the root package, whose `flutter run` shows this page)
//   flutter:
//     uses-material-design: true   # fixes the broken icon glyphs
//
//   dev_dependencies:
//     mobile_scanner: ^7.4.2       # the demo owns the camera
//     image_picker: ^1.2.4         # ... and the gallery pick
//   Both are dev dependencies on purpose: the published package stays free of
//   runtime dependencies, so these imports are only allowed here because this
//   file is the demo entrypoint.
//
// What this screen does
//   • a near-black, nearly full-width camera card with rounded bottom corners
//   • a header over the preview: a centred "QR Scan" title and a close button
//   • a four-bracket (cornersOnly) frame, ~280–330 dp, that never boxes in the
//     camera, with a soft sweep and a spring lock-on
//   • two pill controls under the card: Flash (tracks the torch state) and
//     Upload QR (decodes a gallery image)
//   • a compact payment-methods strip under the controls
//   • on a read: a calm success dialog with a $ / ៛ coin burst
//
// The host owns the camera and the decode; `qr_scan_fx` receives geometry only.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Both are *dev* dependencies on purpose: the published package stays free of
// runtime dependencies, so these imports are only allowed here because this
// file is the demo entrypoint.
// ignore: depend_on_referenced_packages
import 'package:image_picker/image_picker.dart';
// ignore: depend_on_referenced_packages
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

void main() => runApp(const QrScanFxDemoApp());

// ───────────────────────── Palette ─────────────────────────
class _C {
  // Scanner screen — the reference's neutral dark look.
  static const bg = Color(0xFF000000);
  static const pill = Color(0xFF1C1C1E);
  static const pillBorder = Color(0xFF2E2E30);
  static const pillActive = Color(0xFF7CB0FF);
  static const onPillActive = Color(0xFF04213F);
  static const onDisabled = Color(0x66FFFFFF);
  static const providerTile = Color(0xFF141416);
  static const providerTileBorder = Color(0xFF28282A);
  static const providerLabel = Color(0xFFE6E6E8);
  static const caption = Color(0xFF9FB3CC);

  // The success dialog — the demo's own celebration, unchanged.
  static const navy = Color(0xFF071A3A);
  static const blue = Color(0xFF1D6FE8);
  static const gold = Color(0xFFF6B93B);
  static const goldDeep = Color(0xFFD48A12);
  static const ink = Color(0xFF0F1B33);
  static const muted = Color(0xFF6B7791);
  static const line = Color(0xFFE6EAF2);
}

/// Shared metrics for the scanner screen.
abstract final class _M {
  /// Side margin of the camera card, so it reads as nearly full-width.
  static const double previewInset = 8;

  /// Radius of the card's rounded bottom corners.
  static const double previewRadius = 28;

  /// Horizontal margin shared by the controls and the strip below the card.
  static const double gutter = 20;

  /// Height of a pill control. Comfortably past the 48 dp touch target.
  static const double pillHeight = 52;

  /// The largest the scan frame will grow.
  static const double frameMaxSide = 330;

  /// A frame this small no longer reads as a scanner.
  static const double frameFloor = 120;

  /// Space kept clear below the frame for the hint pill and the status notice.
  static const double frameFootroom = 140;

  /// Fixed tile size, so the payment-method labels line up.
  static const double tileWidth = 84;
  static const double tileHeight = 36;
}

class QrScanFxDemoApp extends StatelessWidget {
  const QrScanFxDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scan to pay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[QrScanFxTheme.dark],
      ),
      home: const ScannerPage(),
    );
  }
}

// ───────────────────── Scan result model ───────────────────
class ScanResult {
  ScanResult({
    required this.raw,
    this.isKhqr = false,
    this.merchant,
    this.city,
    this.amount,
    this.symbol,
    this.currency,
  });

  final String raw;
  final bool isKhqr;
  final String? merchant, city, amount, symbol, currency;

  factory ScanResult.parse(String raw) {
    if (raw.startsWith('000201')) {
      final t = _tlv(raw);
      if (t.containsKey('59') || t.containsKey('54')) {
        final code = t['53'];
        final khr = code == '116';
        final usd = code == '840';
        final amt = t['54'];
        return ScanResult(
          raw: raw,
          isKhqr: true,
          merchant: t['59'],
          city: t['60'],
          amount: amt == null ? null : _fmt(amt, khr),
          symbol: khr ? '៛' : (usd ? '\$' : null),
          currency: khr ? 'KHR' : (usd ? 'USD' : null),
        );
      }
    }
    return ScanResult(raw: raw);
  }

  static Map<String, String> _tlv(String s) {
    final out = <String, String>{};
    var i = 0;
    while (i + 4 <= s.length) {
      final tag = s.substring(i, i + 2);
      final len = int.tryParse(s.substring(i + 2, i + 4));
      if (len == null || i + 4 + len > s.length) break;
      out[tag] = s.substring(i + 4, i + 4 + len);
      i += 4 + len;
    }
    return out;
  }

  static String _fmt(String amt, bool khr) {
    final v = double.tryParse(amt);
    if (v == null) return amt;
    final group = RegExp(r'\B(?=(\d{3})+(?!\d))');
    if (khr) return v.round().toString().replaceAllMapped(group, (_) => ',');
    final p = v.toStringAsFixed(2).split('.');
    return '${p[0].replaceAllMapped(group, (_) => ',')}.${p[1]}';
  }
}

// ───────────────────────── Page ────────────────────────────
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final QrScanFxController _fx = QrScanFxController();

  // Torch on, as the banking screen expects; the Flash pill tracks the real
  // state rather than a local copy, so it stays honest when the device
  // reports the torch as unavailable.
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    torchEnabled: true,
  );

  final ImagePicker _picker = ImagePicker();

  // The reference's minimal scanner: white corners, no frame outline, a soft
  // white sweep, and a dim surround that keeps the camera visible.
  final QrScanFxTheme _theme = QrScanFxTheme.dark.copyWith(
    frameColor: Colors.white,
    frameGlowColor: const Color(0xFFBBD4FF),
    cornerColor: Colors.white,
    beamColor: const Color(0xFFD8E6FF),
    backdropColor: _C.bg,
    backdropStyle: ScanBackdropStyle.solidDim,
    cornerStyle: ScanCornerStyle.rounded,
    cornerRadius: 24,
    cornerStrokeWidth: 4.5,
    cornerArmFraction: 0.2,
    frameShape: ScanFrameShape.cornersOnly,
    beamStyle: ScanBeamStyle.softGradientBar,
    lockStyle: ScanLockStyle.smoothMorph,
  );

  // The success dialog's own entrance and coin burst. The dialog is this page's
  // seat for a read; the overlay only supplies the lock-on.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  Size _sensorSize = Size.zero;

  /// Guards against a stream of detections for the same code restarting the
  /// lock-on or firing a second result.
  bool _settled = false;

  /// Guards the gallery pick, so a double tap cannot open two pickers.
  bool _picking = false;

  ScanResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Leave `idle` so the beam is already sweeping before the first code. The
    // overlay seeds its animation from the controller's current state when it
    // attaches, so announcing this before the first build is safe.
    _fx.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pop.dispose();
    _burst.dispose();
    _fx.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
  // Camera → overlay. Geometry only.
  // ---------------------------------------------------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_settled || capture.barcodes.isEmpty) return;
    final Barcode code = capture.barcodes.first;
    final List<Offset> corners = code.corners;
    if (corners.length != 4) return; // Nothing to frame without corners.

    final String? raw = code.rawValue ?? code.displayValue;
    if (raw == null || raw.isEmpty) return;

    _settled = true;
    if (!capture.size.isEmpty && capture.size != _sensorSize) {
      setState(() => _sensorSize = capture.size);
    }
    // The decoded string is read here, by the app, and never crosses the
    // overlay boundary: the package receives corners alone.
    _fx.lockOn(ScanFxTarget.corners(corners));

    unawaited(_settle(raw));
  }

  Future<void> _settle(String raw) async {
    // A medium tap is the confirmation that lands without startling anyone.
    unawaited(HapticFeedback.mediumImpact());
    await Future<void>.delayed(const Duration(milliseconds: 760));
    if (!mounted) return;
    _fx.success();
    setState(() => _result = ScanResult.parse(raw));
    unawaited(_pop.forward(from: 0));
    unawaited(_burst.forward(from: 0));
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
      final String? raw = code?.rawValue ?? code?.displayValue;
      if (raw == null || raw.isEmpty) {
        _fx.invalid('That code carried no data');
        return;
      }
      if (!capture!.size.isEmpty) {
        setState(() => _sensorSize = capture.size);
      }
      _settled = true;
      _fx.lockOn(ScanFxTarget.corners(corners));
      await _settle(raw);
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

  void _retryCamera() {
    unawaited(_camera.start());
  }

  void _scanAgain() {
    _pop.reset();
    _burst.reset();
    setState(() {
      _result = null;
      _settled = false;
    });
    _fx.reset();
    _fx.start();
  }

  void _close() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // Run standalone this page *is* the first screen, so say so rather than
    // leaving the button looking broken.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('This demo opens on the scanner, so there is no screen '
              'to return to.'),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Composition.
  // ---------------------------------------------------------------------------

  Widget _cameraView() => MobileScanner(
        controller: _camera,
        fit: BoxFit.cover,
        onDetect: _onDetect,
        errorBuilder: (BuildContext context, MobileScannerException error) =>
            _CameraError(error: error, onRetry: _retryCamera),
        placeholderBuilder: (BuildContext context) => const _CameraLoading(),
      );

  Widget _overlay(Size? sensorSize) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          // Aim for the reference's 280–330 dp band, bound by the two things
          // that can genuinely clip it: the card's width, and the room under
          // the frame that the hint pill and the status notice need. The
          // package additionally clamps the frame to 82% of the card's short
          // side, so a very short card degrades gracefully.
          final double widthBound = size.width - 32;
          final double heightBound = size.height - _M.frameFootroom;
          final double requested = math.max(
            _M.frameFloor,
            math.min(
              math.min(widthBound, heightBound),
              _M.frameMaxSide,
            ),
          );

          return QrScanFx(
            controller: _fx,
            theme: _theme,
            sensorSize: sensorSize,
            previewFit: BoxFit.cover,
            scanAreaSize: Size.square(requested),
            // The camera is a sibling below this overlay, so nothing is painted
            // over an error or a loading view.
            //
            // The package's default status seat sits inside the scan area,
            // which would land on the frame; pin it to the foot of the card
            // instead, level with where the hint pill appears.
            messageBuilder: (BuildContext context) => Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ScanFxStatusNotice(
                  message: _fx.message,
                  fallback: 'Invalid code',
                  onRetry: _scanAgain,
                  backgroundColor: const Color(0xB30B1220),
                  foregroundColor: const Color(0xFFF2F6FC),
                  maxWidth: 320,
                ),
              ),
            ),
          );
        },
      );

  Widget _header(BuildContext context) {
    return Row(
      children: <Widget>[
        // An equal-width slot on the left keeps the title optically centred.
        const SizedBox(width: 48),
        Expanded(
          child: Text(
            'QR Scan',
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
        SizedBox(
          width: 48,
          child: IconButton(
            onPressed: _close,
            tooltip: 'Close scanner',
            icon: const Icon(Icons.close),
            color: Colors.white,
            iconSize: 24,
          ),
        ),
      ],
    );
  }

  Widget _flashButton(MobileScannerState state) {
    final bool available = state.torchState != TorchState.unavailable;
    final bool on = state.torchState == TorchState.on;
    return _PillButton(
      icon: on ? Icons.flashlight_on : Icons.flashlight_off,
      label: 'Flash',
      active: on,
      onPressed: available ? _toggleTorch : null,
      semanticLabel: available ? null : 'Flash unavailable on this device',
    );
  }

  Widget _uploadButton() => _PillButton(
        icon: Icons.photo_library_outlined,
        label: 'Upload QR',
        busy: _picking,
        onPressed: _settled ? null : _pickFromGallery,
      );

  // The camera card: nearly full-width, rounded bottom corners, with a short
  // top scrim so the status bar and the title stay legible over a bright frame.
  Widget _preview(BuildContext context, bool failed, Size? sensorSize) {
    final double topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _M.previewInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_M.previewRadius),
        ),
        child: ColoredBox(
          color: _C.bg,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _cameraView(),
              if (!failed) _overlay(sensorSize),
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
                  padding: EdgeInsets.only(
                    top: topInset + 8,
                    left: 4,
                    right: 4,
                  ),
                  child: _header(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Portrait: the card on top, the controls and the strip underneath. The card
  // takes every pixel the controls do not need.
  Widget _tall(BuildContext context, MobileScannerState state, bool failed,
      Size? sensorSize) {
    return Column(
      children: <Widget>[
        Expanded(child: _preview(context, failed, sensorSize)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _M.gutter),
          child: Row(
            children: <Widget>[
              Expanded(child: _flashButton(state)),
              const SizedBox(width: 12),
              Expanded(child: _uploadButton()),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _ProviderGrid(),
        const SizedBox(height: 18),
      ],
    );
  }

  // Landscape: the card keeps the height it has, and the controls move to a
  // column beside it instead of crushing it. The column scrolls, so a short
  // window or a large text scale cannot overflow.
  Widget _wide(BuildContext context, MobileScannerState state, bool failed,
      Size? sensorSize) {
    return Row(
      children: <Widget>[
        Expanded(flex: 3, child: _preview(context, failed, sensorSize)),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _M.gutter),
                  child: Column(
                    children: <Widget>[
                      _flashButton(state),
                      const SizedBox(height: 12),
                      _uploadButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _ProviderGrid(),
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
    final bool done = _result != null;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The preview runs under the status bar on purpose; only the bottom
          // and the horizontal insets are taken away from it.
          SafeArea(
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
                    ? _wide(context, state, failed, sensorSize)
                    : _tall(context, state, failed, sensorSize);
              },
            ),
          ),

          // Success dialog.
          if (done) ...<Widget>[
            Positioned.fill(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _pop,
                  curve: const Interval(0, .4),
                ),
                child: const ColoredBox(color: Color(0xB3041025)),
              ),
            ),
            Center(
              child: _SuccessDialog(
                result: _result!,
                pop: _pop,
                burst: _burst,
                onAgain: _scanAgain,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────── Pill action button ───────────────────
/// The pill action button under the preview: charcoal with a white icon and
/// label at rest, accent while the control is on, spinner while it is busy.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.busy = false,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final bool busy;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !busy;
    final Color background = enabled && active ? _C.pillActive : _C.pill;
    final Color foreground = !enabled
        ? _C.onDisabled
        : active
            ? _C.onPillActive
            : Colors.white;
    final BorderRadius radius = BorderRadius.circular(_M.pillHeight / 2);

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
              height: _M.pillHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: enabled && active
                      ? Colors.transparent
                      : _C.pillBorder,
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

// ─────────────── Payment-methods strip ───────────────
// Neutral text tiles, not trademarked logos: this package ships no provider
// artwork, and inventing a logo would be worse than a plain label. The four
// names are the KHQR issuers this demo already talks about — KHQR is the
// Cambodian interoperable standard the reference screen reads.
const List<String> _kProviders = <String>['ABA', 'ACLEDA', 'Wing', 'Bakong'];

/// A centred, evenly spaced strip naming the payment methods this app reads.
class _ProviderGrid extends StatelessWidget {
  const _ProviderGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _M.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'ACCEPTED VIA KHQR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.caption,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          // A Wrap rather than a GridView: the row reflows to one or two lines
          // by itself, so nothing clips on a narrow phone or a tablet.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final String provider in _kProviders)
                _ProviderTile(label: provider),
            ],
          ),
        ],
      ),
    );
  }
}

/// One fixed-size payment-method tile.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        width: _M.tileWidth,
        height: _M.tileHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _C.providerTile,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.providerTileBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _C.providerLabel,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ──────────────────── Camera states ─────────────────────
/// Shown while the camera is being initialised.
class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _C.bg,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }
}

/// Shown when the camera could not be started — most often because camera
/// permission was refused.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, this.onRetry});

  final MobileScannerException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: _C.navy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                denied ? Icons.no_photography : Icons.videocam_off_outlined,
                color: Colors.white54,
                size: 44,
              ),
              const SizedBox(height: 14),
              Text(
                denied ? 'Camera access needed' : 'Camera unavailable',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                // Only the plugin's own (English) error code is shown. The
                // native `errorDetails` message is localised by the OS, which
                // would put a foreign language on this screen.
                denied
                    ? 'Allow camera access to scan a code, or upload one from '
                        'your gallery instead.'
                    : 'The camera could not be started. Try again, or upload a '
                        'code from your gallery instead.\n'
                        '${error.errorCode.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7CB0FF),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    minimumSize: const Size(120, 48),
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

// ───────────────────── Success dialog ─────────────────────
class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({
    required this.result,
    required this.pop,
    required this.burst,
    required this.onAgain,
  });

  final ScanResult result;
  final AnimationController pop, burst;
  final VoidCallback onAgain;

  static const double _badge = 88;

  @override
  Widget build(BuildContext context) {
    final w = math.min(MediaQuery.of(context).size.width - 48, 340.0);
    final scale = CurvedAnimation(parent: pop, curve: Curves.easeOutBack);

    return SizedBox(
      width: w,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: _badge / 2),
            child: ScaleTransition(
              scale: Tween<double>(begin: .88, end: 1).animate(scale),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: pop,
                  curve: const Interval(0, .5),
                ),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.fromLTRB(22, _badge / 2 + 14, 22, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withAlpha(70),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: _CardBody(result: result, onAgain: onAgain),
                ),
              ),
            ),
          ),

          // Badge: gold coin for payments, QR glyph for everything else.
          Positioned(
            top: 0,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: pop, curve: Curves.elasticOut),
              child: Container(
                width: _badge,
                height: _badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF2F86F5),
                      _C.blue,
                      Color(0xFF1654B8),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _C.blue.withAlpha(110),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: result.symbol != null
                    ? SizedBox(
                        width: 46,
                        height: 46,
                        child: _CoinFace(result.symbol!),
                      )
                    : SizedBox(
                        width: 40,
                        height: 40,
                        child: CustomPaint(painter: _QrGlyphPainter()),
                      ),
              ),
            ),
          ),

          // $ / ៛ coin burst
          Positioned(
            left: 0,
            top: 0,
            width: w,
            height: _badge,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: burst,
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  children: _coins(w),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static final List<_Coin> _list = _makeCoins();

  static List<_Coin> _makeCoins() {
    final r = math.Random(11);
    return List<_Coin>.generate(18, (i) {
      return _Coin(
        symbol: i.isEven ? '\$' : '៛',
        angle: -math.pi + r.nextDouble() * math.pi,
        dist: 110 + r.nextDouble() * 120,
        size: 24 + r.nextDouble() * 14,
        delay: r.nextDouble() * .18,
        spin: (r.nextDouble() - .5) * 1.2,
      );
    });
  }

  List<Widget> _coins(double w) {
    final v = burst.value;
    final cx = w / 2, cy = _badge / 2;
    final out = <Widget>[];

    final ringT = Curves.easeOut.transform((v / .55).clamp(0.0, 1.0));
    out.add(Positioned(
      left: cx - 44 - ringT * 70,
      top: cy - 44 - ringT * 70,
      width: 88 + ringT * 140,
      height: 88 + ringT * 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
        ),
      ),
    ));

    for (final c in _list) {
      final p = ((v - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
      if (p == 0) continue;
      final e = Curves.easeOutCubic.transform(p);
      final dx = math.cos(c.angle) * c.dist * e;
      final dy = math.sin(c.angle) * c.dist * e + 90 * p * p;
      final opacity = p < .65 ? 1.0 : ((1 - p) / .35).clamp(0.0, 1.0);
      final s = .4 + .6 * Curves.easeOutBack.transform((p * 3).clamp(0.0, 1.0));

      out.add(Positioned(
        left: cx + dx - c.size,
        top: cy + dy - c.size,
        width: c.size * 2,
        height: c.size * 2,
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: c.spin * p * math.pi,
            child: Transform.scale(scale: s, child: _CoinFace(c.symbol)),
          ),
        ),
      ));
    }
    return out;
  }
}

class _Coin {
  const _Coin({
    required this.symbol,
    required this.angle,
    required this.dist,
    required this.size,
    required this.delay,
    required this.spin,
  });
  final String symbol;
  final double angle, dist, size, delay, spin;
}

class _CoinFace extends StatelessWidget {
  const _CoinFace(this.symbol);
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFE08A), _C.gold, _C.goldDeep],
        ),
        border: Border.all(color: const Color(0xFFFFF3C4), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(color: _C.gold.withAlpha(120), blurRadius: 10),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            symbol,
            style: const TextStyle(
              color: Color(0xFF7A4A00),
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.result, required this.onAgain});
  final ScanResult result;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          r.isKhqr ? 'Payment code found' : 'QR code read',
          style: const TextStyle(
            color: _C.ink,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          r.isKhqr ? 'KHQR' : 'Check the content before you open it',
          style: const TextStyle(color: _C.muted, fontSize: 13.5),
        ),
        const SizedBox(height: 18),

        if (r.isKhqr && r.amount != null) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                r.symbol ?? '',
                style: const TextStyle(
                  color: _C.blue,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                r.amount!,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: <Widget>[
              if (r.isKhqr) ...<Widget>[
                _Row('Merchant', r.merchant ?? '—'),
                if (r.city != null) _Row('City', r.city!),
                if (r.currency != null) _Row('Currency', r.currency!, last: true),
              ] else
                _Row('Content', r.raw, last: true, wrap: true),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: r.raw));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.ink,
                  side: const BorderSide(color: _C.line, width: 1.5),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onAgain,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text('Scan again'),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v, {this.last = false, this.wrap = false});
  final String k, v;
  final bool last, wrap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: _C.line, width: 1.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(k, style: const TextStyle(color: _C.muted, fontSize: 13.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              maxLines: wrap ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small QR glyph (three finder squares + dots) used as the badge for
/// non-payment codes.
class _QrGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 7;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * .55;
    final fill = Paint()..color = Colors.white;

    void finder(double x, double y) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + u * .3, y + u * .3, u * 2.4, u * 2.4),
          Radius.circular(u * .6),
        ),
        stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + u, y + u, u, u),
          Radius.circular(u * .25),
        ),
        fill,
      );
    }

    finder(0, 0);
    finder(4 * u, 0);
    finder(0, 4 * u);
    for (final o in <Offset>[
      Offset(4.2 * u, 4.2 * u),
      Offset(5.8 * u, 4.2 * u),
      Offset(4.2 * u, 5.8 * u),
      Offset(5.8 * u, 5.8 * u),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o.dx, o.dy, u, u),
          Radius.circular(u * .25),
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
