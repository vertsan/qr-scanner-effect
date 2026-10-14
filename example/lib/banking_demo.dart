// Banking / fintech demo for `qr_scan_fx`.
//
// This demo is deliberately camera-free. You do not need a device, a permission
// or a platform folder to see exactly what a payment flow gets: a simulated
// detection drives the same `QrScanFxController` a real detector would, so the
// lock-on, the confirmation seat, the invalid message and the retry button are
// the real thing rather than a mock-up.
//
// Run it with:
//
//   cd example && flutter pub get && flutter run
//
// The real camera wiring — including torch and a gallery pick — is in
// `doc/payment-qr-guide.md`, and a runnable camera host ships with the package
// repository at `lib/main.dart`.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

void main() => runApp(const BankingDemoApp());

/// Where the simulated code "is" on screen, as a fraction of the viewport.
const double _codeTop = 0.30;

/// The mock code's edge length.
const double _codeSize = 200;

class BankingDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const BankingDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'qr_scan_fx · banking demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const BankingDemoPage(),
    );
  }
}

class BankingDemoPage extends StatefulWidget {
  /// Creates the demo page.
  const BankingDemoPage({super.key});

  @override
  State<BankingDemoPage> createState() => _BankingDemoPageState();
}

class _BankingDemoPageState extends State<BankingDemoPage> {
  final QrScanFxController _controller = QrScanFxController();

  /// The scripted "detector". Cancelled whenever a new action starts, so two
  /// taps can never leave a timer behind that fires into a later state.
  Timer? _script;

  ScanFxState _state = ScanFxState.idle;
  ScanFxTunables _tunables = ScanFxTunables.defaults;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onController);
    // Leave `idle` so the beam is already sweeping before the first "scan".
    _controller.start();
  }

  @override
  void dispose() {
    _script?.cancel();
    _controller.removeListener(_onController);
    _controller.dispose();
    super.dispose();
  }

  void _onController() {
    if (_controller.value != _state) {
      setState(() => _state = _controller.value);
    }
  }

  Rect _codeRect(Size size) => Rect.fromCenter(
        center: Offset(size.width / 2, size.height * _codeTop + _codeSize / 2),
        width: _codeSize,
        height: _codeSize,
      );

  /// Runs the exact sequence a camera callback would, minus the camera.
  ///
  /// `lockOn` is handed **geometry only** — the same `ScanFxTarget.rect` a real
  /// detector would produce. No content is created here because no content ever
  /// reaches the package.
  void _simulateScan(Size size) {
    _script?.cancel();
    final Rect rect = _codeRect(size);
    _controller.reset();
    _controller.start();
    _script = Timer(const Duration(milliseconds: 420), () {
      _controller.lockOn(ScanFxTarget.rect(rect));
      // `detected → locked` happens by itself after the hold; the success state
      // stands in for "the host validated the code and accepted it".
      _script = Timer(const Duration(milliseconds: 1500), () {
        _controller.success();
      });
    });
  }

  void _simulateRejection() {
    _script?.cancel();
    _controller.invalid('This merchant code is not supported');
  }

  void _restart() {
    _script?.cancel();
    _controller.reset();
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04070D),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          return QrScanFx.banking(
            controller: _controller,
            tunables: _tunables,
            onRetry: _restart,
            child: const _MockCamera(),
            confirmationBuilder: (BuildContext context) => _ConfirmationSeat(
              state: _state,
            ),
            controlsBuilder: (BuildContext context) => _ControlsSeat(
              onScan: () => _simulateScan(size),
              onReject: _simulateRejection,
              onReset: _restart,
              tunables: _tunables,
              onTunables: (ScanFxTunables value) =>
                  setState(() => _tunables = value),
            ),
          );
        },
      ),
    );
  }
}

/// The confirmation seat: what a host shows *after* its own validation.
///
/// Note the copy. It says the code was captured — never that a payment went
/// through, because the overlay has no way to know that and must not imply it.
class _ConfirmationSeat extends StatelessWidget {
  const _ConfirmationSeat({required this.state});

  final ScanFxState state;

  @override
  Widget build(BuildContext context) {
    final bool visible = state == ScanFxState.success;
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.16),
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
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
                  'Your app decides what happens next. qr_scan_fx never sees the '
                  'payload.',
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
        ),
      ),
    );
  }
}

/// The controls seat: where a host drops its own controls.
///
/// In a real app this holds a torch toggle and a gallery pick. Here it holds the
/// buttons that stand in for the camera, plus live tunables — which is the point
/// of the seat: the package owns no camera, so the host owns what goes here.
class _ControlsSeat extends StatelessWidget {
  const _ControlsSeat({
    required this.onScan,
    required this.onReject,
    required this.onReset,
    required this.tunables,
    required this.onTunables,
  });

  final VoidCallback onScan;
  final VoidCallback onReject;
  final VoidCallback onReset;
  final ScanFxTunables tunables;
  final ValueChanged<ScanFxTunables> onTunables;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _TunableRow(tunables: tunables, onChanged: onTunables),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan a code'),
                  ),
                  OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Reject'),
                  ),
                  TextButton(onPressed: onReset, child: const Text('Reset')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TunableRow extends StatelessWidget {
  const _TunableRow({required this.tunables, required this.onChanged});

  final ScanFxTunables tunables;
  final ValueChanged<ScanFxTunables> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1220),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _slider(
            label: 'Intensity',
            value: tunables.intensity,
            min: 0,
            max: 1,
            onChanged: (double value) =>
                onChanged(tunables.copyWith(intensity: value)),
          ),
          _slider(
            label: 'Speed',
            value: tunables.speed,
            min: 0.25,
            max: 3,
            onChanged: (double value) =>
                onChanged(tunables.copyWith(speed: value)),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF9FB3CC), fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFF9FB3CC), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// A stand-in for a camera preview: a dark vignette with a plain "code" drawn
/// where the simulated detection points, so the overlay has something to
/// acquire.
class _MockCamera extends StatelessWidget {
  const _MockCamera();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.infinite, painter: _MockCameraPainter());
}

class _MockCameraPainter extends CustomPainter {
  const _MockCameraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          radius: 1.1,
          colors: <Color>[Color(0xFF14202F), Color(0xFF04070D)],
        ).createShader(full),
    );

    final Rect code = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * _codeTop + _codeSize / 2),
      width: _codeSize,
      height: _codeSize,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(code.inflate(12), const Radius.circular(14)),
      Paint()..color = const Color(0xFFE8EEF6),
    );

    // A recognisable-enough QR-ish block grid. Purely decorative: nothing in
    // this app decodes it, and nothing hands it to the overlay.
    final Paint cell = Paint()..color = const Color(0xFF0A1622);
    const int grid = 9;
    final double step = _codeSize / grid;
    final math.Random random = math.Random(7);
    for (int y = 0; y < grid; y++) {
      for (int x = 0; x < grid; x++) {
        if (random.nextBool() && !_isFinder(x, y, grid)) {
          canvas.drawRect(
            Rect.fromLTWH(
              code.left + x * step,
              code.top + y * step,
              step,
              step,
            ),
            cell,
          );
        }
      }
    }
    _finder(canvas, code.topLeft, step, cell);
    _finder(canvas, code.topRight - Offset(step * 3, 0), step, cell);
    _finder(canvas, code.bottomLeft - Offset(0, step * 3), step, cell);
  }

  bool _isFinder(int x, int y, int grid) {
    bool inBox(int ox, int oy) =>
        x >= ox && x < ox + 3 && y >= oy && y < oy + 3;
    return inBox(0, 0) || inBox(grid - 3, 0) || inBox(0, grid - 3);
  }

  void _finder(Canvas canvas, Offset at, double step, Paint paint) {
    canvas.drawRect(Rect.fromLTWH(at.dx, at.dy, step * 3, step * 3), paint);
    canvas.drawRect(
      Rect.fromLTWH(at.dx + step, at.dy + step, step, step),
      Paint()..color = const Color(0xFFE8EEF6),
    );
  }

  @override
  bool shouldRepaint(_MockCameraPainter oldDelegate) => false;
}
