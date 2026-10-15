// Clean, banking-style host for the `qr_scan_fx` overlay.
//
// pubspec.yaml (the root package, whose `flutter run` shows this page)
//   flutter:
//     uses-material-design: true   # fixes the broken icon glyphs
//
// What changed vs. the old demo
//   • removed the "qr_scan_fx" pill and the "State: …" debug text
//   • removed the check/tick animation (we no longer call _fx.success())
//   • new header, torch state, hint card
//   • success = clean white popup with a $ / ៛ coin burst
//   • KHQR (ABA, ACLEDA, Wing, Bakong …) is parsed: amount, merchant, currency
//
// The host owns the camera and the decode; `qr_scan_fx` receives geometry only.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// The demo drives a real camera. `mobile_scanner` is a *dev* dependency on
// purpose: the published package stays free of runtime dependencies, so this
// import is only allowed here because this file is the demo entrypoint.
// ignore: depend_on_referenced_packages
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

void main() => runApp(const QrScanFxDemoApp());

// ───────────────────────── Palette ─────────────────────────
class _C {
  static const navy = Color(0xFF071A3A);
  static const blue = Color(0xFF1D6FE8);
  static const aqua = Color(0xFF38E1D0);
  static const gold = Color(0xFFF6B93B);
  static const goldDeep = Color(0xFFD48A12);
  static const ink = Color(0xFF0F1B33);
  static const muted = Color(0xFF6B7791);
  static const line = Color(0xFFE6EAF2);
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

  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  // Calmer look: white corners, soft aqua beam, very faint glow.
  final QrScanFxTheme _theme = QrScanFxTheme.dark.copyWith(
    cornerColor: Colors.white,
    beamColor: _C.aqua,
    frameGlowColor: const Color(0x3338E1D0),
    frameShape: ScanFrameShape.cornersOnly,
    beamStyle: ScanBeamStyle.glowingLaser,
    lockStyle: ScanLockStyle.springSnap,
  );

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  Size _sensorSize = Size.zero;
  bool _settled = false;
  bool _torch = false;
  ScanResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start after the first frame so the overlay is attached and the beam is
    // already sweeping (no "Tap to start scanning" idle state).
    WidgetsBinding.instance.addPostFrameCallback((_) => _fx.start());
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

  void _onDetect(BarcodeCapture capture) {
    if (_settled || capture.barcodes.isEmpty) return;
    final Barcode code = capture.barcodes.first;

    if (!capture.size.isEmpty && capture.size != _sensorSize) {
      setState(() => _sensorSize = capture.size);
    }

    final List<Offset> corners = code.corners;
    if (corners.length != 4) return;

    final String? raw = code.rawValue ?? code.displayValue;
    if (raw == null || raw.isEmpty) return;

    _settled = true;
    _fx.lockOn(ScanFxTarget.corners(corners)); // frame snaps onto the code

    // Let the lock-on land, then show our own success popup.
    // (We intentionally do NOT call _fx.success(): that is the tick animation.)
    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _result = ScanResult.parse(raw));
      _pop.forward(from: 0);
      _burst.forward(from: 0);
    });
  }

  void _scanAgain() {
    _pop.reset();
    _burst.reset();
    setState(() {
      _result = null;
      _settled = false;
    });
    _fx.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fx.start());
  }

  Future<void> _toggleTorch() async {
    await _camera.toggleTorch();
    if (mounted) setState(() => _torch = !_torch);
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final Size? sensorSize = _sensorSize.isEmpty
        ? null
        : (landscape
            ? Size(_sensorSize.height, _sensorSize.width)
            : _sensorSize);
    final bool done = _result != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          QrScanFx(
            controller: _fx,
            theme: _theme,
            // The package's built-in hint reads "Tap to start scanning" and is
            // shown while idle *and* scanning, so it never disappears on its
            // own. This page has its own hint card, so hide the built-in one.
            layers: (context, stack) => stack.hide(ScanLayerKind.hint),
            sensorSize: sensorSize,
            previewFit: BoxFit.cover,
            onStateChanged: (_) {},
            child: MobileScanner(
              controller: _camera,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(error: error),
            ),
          ),

          // Soft top/bottom shading so text stays readable on any camera feed.
          const IgnorePointer(child: _Shade()),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Scan to pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Scan a KHQR code to continue',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: the hint, then the two controls, sitting under the scan
          // frame instead of up in the header.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _GlassButton(
                          icon: _torch
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          semanticLabel: _torch
                              ? 'Turn the torch off'
                              : 'Turn the torch on',
                          active: _torch,
                          onTap: done ? null : _toggleTorch,
                        ),
                        const SizedBox(width: 16),
                        _GlassButton(
                          icon: Icons.cameraswitch_rounded,
                          semanticLabel: 'Switch camera',
                          onTap: done ? null : _camera.switchCamera,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Success popup
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

// ──────────────────── Small UI pieces ─────────────────────
class _Shade extends StatelessWidget {
  const _Shade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0, .22, .7, 1],
          colors: <Color>[
            Color(0xCC041025),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC041025),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.semanticLabel,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color accent = active ? _C.gold : _C.aqua;

    return Semantics(
      label: semanticLabel,
      button: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Soft halo: aqua at rest, gold and brighter while the torch is on.
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withAlpha(active ? 150 : (enabled ? 55 : 0)),
              blurRadius: active ? 28 : 16,
              spreadRadius: active ? 2 : 0,
            ),
          ],
        ),
        child: Material(
          color: active ? _C.gold : Colors.white.withAlpha(enabled ? 32 : 16),
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white.withAlpha(active ? 0 : 46),
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                icon,
                size: 24,
                color: active
                    ? _C.navy
                    : Colors.white.withAlpha(enabled ? 255 : 120),
              ),
            ),
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
      color: _C.navy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.no_photography_rounded,
                  color: Colors.white54, size: 44),
              const SizedBox(height: 14),
              const Text(
                'Camera unavailable',
                style: TextStyle(
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
                'Allow camera access in Settings, then try again.\n'
                '${error.errorCode.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
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
                    colors: <Color>[Color(0xFF2F86F5), _C.blue, Color(0xFF1654B8)],
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
        border: last ? null : const Border(bottom: BorderSide(color: _C.line, width: 1.5)),
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
