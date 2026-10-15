// The Style Studio: a live playground for every layer in the package.
//
// It is deliberately camera-free. The scene is painted, the detection is
// scripted, and the overlay is the real widget reading the real theme — so what
// you see here is what ships (minus your camera and your content).
//
// Everything is live: change a frame shape and the running ambient loop keeps
// going; drag *Speed* mid-lock and the spring rescales instead of restarting.
// That is the whole point of the tunables model, and this screen is how you feel
// it rather than read about it.
//
//   cd example && flutter pub get && flutter run -t lib/style_studio.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

void main() => runApp(const StyleStudioApp());

/// How much of the preview's shorter side the mock code occupies.
const double _codeFraction = 0.52;

class StyleStudioApp extends StatelessWidget {
  /// Creates the studio app.
  const StyleStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'qr_scan_fx · style studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const StyleStudioPage(),
    );
  }
}

class StyleStudioPage extends StatefulWidget {
  /// Creates the studio page.
  const StyleStudioPage({super.key});

  @override
  State<StyleStudioPage> createState() => _StyleStudioPageState();
}

class _StyleStudioPageState extends State<StyleStudioPage> {
  final QrScanFxController _fx = QrScanFxController();

  QrScanFxTheme _theme = QrScanFxTheme.dark;
  ScanFxTunables _tunables = ScanFxTunables.defaults;

  ScanFxState _state = ScanFxState.idle;
  Timer? _script;
  Timer? _autoplay;
  bool _live = true;

  @override
  void initState() {
    super.initState();
    _fx.addListener(_onController);
    _fx.start();
    _restartAutoplay();
  }

  @override
  void dispose() {
    _script?.cancel();
    _autoplay?.cancel();
    _fx.removeListener(_onController);
    _fx.dispose();
    super.dispose();
  }

  void _onController() {
    if (_fx.value != _state) {
      setState(() => _state = _fx.value);
    }
  }

  // ---------------------------------------------------------------------------
  // The scripted detector
  // ---------------------------------------------------------------------------

  void _cancelScript() {
    _script?.cancel();
    _script = null;
  }

  /// Parks the overlay on a locked target: `start` → `lockOn` → the automatic
  /// `detected → locked` promotion. Nothing calls `success`, so it stays there
  /// and the lock-on styles can be inspected at leisure.
  void _lockOn(Rect rect) {
    _cancelScript();
    _fx.reset();
    _fx.start();
    _fx.lockOn(ScanFxTarget.rect(rect));
  }

  /// The full happy path, ending in `success`.
  void _playScan(Rect rect,
      {Duration settle = const Duration(milliseconds: 900)}) {
    _lockOn(rect);
    _script = Timer(settle, () {
      if (mounted) _fx.success();
    });
  }

  void _restartAutoplay() {
    _autoplay?.cancel();
    _autoplay = null;
    if (!_live) return;
    _autoplay = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      // A fresh rect each cycle would be noise; the studio's job is the styles.
      if (mounted) _replayFromLastGeometry();
    });
  }

  Rect? _lastRect;

  void _replayFromLastGeometry() {
    final Rect? rect = _lastRect;
    if (rect == null) return;
    _playScan(rect);
  }

  void _onGeometry(Rect rect) => _lastRect = rect;

  // ---------------------------------------------------------------------------
  // Theme edits
  // ---------------------------------------------------------------------------

  void _applyTheme(QrScanFxTheme theme) => setState(() => _theme = theme);

  void _randomise() => _applyTheme(
        QrScanFxTheme.random(seed: DateTime.now().millisecondsSinceEpoch),
      );

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Style Studio'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Random theme',
            onPressed: _randomise,
            icon: const Icon(Icons.casino_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 780;
          final Widget preview = _Preview(
            controller: _fx,
            theme: _theme,
            tunables: _tunables,
            state: _state,
            onGeometry: _onGeometry,
          );
          final Widget panel = _ControlPanel(
            theme: _theme,
            tunables: _tunables,
            state: _state,
            live: _live,
            onTheme: _applyTheme,
            onTunables: (ScanFxTunables value) =>
                setState(() => _tunables = value),
            onLive: (bool value) {
              setState(() => _live = value);
              _restartAutoplay();
            },
            onLock: () {
              final Rect? rect = _lastRect;
              if (rect == null) return;
              setState(() => _live = false);
              _restartAutoplay();
              _lockOn(rect);
            },
            onSuccess: () => _fx.success(),
            onReject: () => _fx.invalid('This merchant code is not supported'),
            onError: () => _fx.error('Could not read the code'),
            onReset: () {
              _cancelScript();
              _fx.reset();
              _fx.start();
            },
          );

          if (wide) {
            return Row(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: preview,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(width: 400, child: panel),
              ],
            );
          }

          return Column(
            children: <Widget>[
              SizedBox(
                  height: math.min(constraints.maxHeight * 0.5, 460),
                  child: preview),
              const Divider(height: 1),
              Expanded(child: panel),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Preview
// -----------------------------------------------------------------------------

class _Preview extends StatelessWidget {
  const _Preview({
    required this.controller,
    required this.theme,
    required this.tunables,
    required this.state,
    required this.onGeometry,
  });

  final QrScanFxController controller;
  final QrScanFxTheme theme;
  final ScanFxTunables tunables;
  final ScanFxState state;
  final ValueChanged<Rect> onGeometry;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: const Color(0xFF05070D),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size = constraints.biggest;
              final double side = size.shortestSide * _codeFraction;
              final Rect code = Rect.fromCenter(
                center: Offset(size.width / 2, size.height * 0.46),
                width: side,
                height: side,
              );
              onGeometry(code);

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _MockScene(code: code),
                  QrScanFx(
                    controller: controller,
                    theme: theme,
                    tunables: tunables,
                    scanAreaSize: Size.square(side * 1.18),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A painted stand-in for a camera preview: a soft studio light, a card, and a
/// plausible code on it. Nothing here is decoded, and nothing here reaches the
/// overlay except the rectangle the detection points at.
class _MockScene extends StatelessWidget {
  const _MockScene({required this.code});

  final Rect code;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.infinite, painter: _MockScenePainter(code));
}

class _MockScenePainter extends CustomPainter {
  _MockScenePainter(this.code);

  final Rect code;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.55),
          radius: 1.25,
          colors: <Color>[Color(0xFF1B2839), Color(0xFF05070D)],
        ).createShader(full),
    );

    // A soft key light behind the card, so the overlay's own glow has something
    // to compete with.
    canvas.drawCircle(
      Offset(size.width * 0.5, code.center.dy),
      code.width * 1.5,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0x223F7BD8),
            const Color(0x003F7BD8),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, code.center.dy),
            radius: code.width * 1.5,
          ),
        ),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(code.inflate(16), const Radius.circular(18)),
      Paint()..color = const Color(0xFFF3F6FA),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(code.inflate(16), const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x33000000),
    );

    _drawCode(canvas, code);
  }

  /// A QR-looking block grid. Decorative, deterministic, and never read.
  void _drawCode(Canvas canvas, Rect area) {
    const int grid = 11;
    final double step = area.width / grid;
    final math.Random random = math.Random(42);
    final Paint dark = Paint()..color = const Color(0xFF0A1622);

    for (int y = 0; y < grid; y++) {
      for (int x = 0; x < grid; x++) {
        if (_inFinder(x, y, grid)) continue;
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(
              area.left + x * step,
              area.top + y * step,
              step,
              step,
            ),
            dark,
          );
        }
      }
    }

    _finder(canvas, area.topLeft, step, dark);
    _finder(canvas, Offset(area.right - step * 3, area.top), step, dark);
    _finder(canvas, Offset(area.left, area.bottom - step * 3), step, dark);
  }

  bool _inFinder(int x, int y, int grid) {
    bool box(int ox, int oy) => x >= ox && x < ox + 3 && y >= oy && y < oy + 3;
    return box(0, 0) || box(grid - 3, 0) || box(0, grid - 3);
  }

  void _finder(Canvas canvas, Offset at, double step, Paint paint) {
    canvas.drawRect(Rect.fromLTWH(at.dx, at.dy, step * 3, step * 3), paint);
    canvas.drawRect(
      Rect.fromLTWH(at.dx + step, at.dy + step, step, step),
      Paint()..color = const Color(0xFFF3F6FA),
    );
  }

  @override
  bool shouldRepaint(_MockScenePainter oldDelegate) => oldDelegate.code != code;
}

// -----------------------------------------------------------------------------
// Control panel
// -----------------------------------------------------------------------------

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.theme,
    required this.tunables,
    required this.state,
    required this.live,
    required this.onTheme,
    required this.onTunables,
    required this.onLive,
    required this.onLock,
    required this.onSuccess,
    required this.onReject,
    required this.onError,
    required this.onReset,
  });

  final QrScanFxTheme theme;
  final ScanFxTunables tunables;
  final ScanFxState state;
  final bool live;
  final ValueChanged<QrScanFxTheme> onTheme;
  final ValueChanged<ScanFxTunables> onTunables;
  final ValueChanged<bool> onLive;
  final VoidCallback onLock;
  final VoidCallback onSuccess;
  final VoidCallback onReject;
  final VoidCallback onError;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _Section(
          title: 'Lifecycle',
          trailing: _StateChip(state: state),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonal(
                      onPressed: onLock, child: const Text('Lock on')),
                  FilledButton(
                      onPressed: onSuccess, child: const Text('Success')),
                  OutlinedButton(
                      onPressed: onReject, child: const Text('Reject')),
                  OutlinedButton(
                      onPressed: onError, child: const Text('Error')),
                  TextButton(onPressed: onReset, child: const Text('Reset')),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: live,
                onChanged: onLive,
                title: const Text('Live loop'),
                subtitle: const Text('Replays a scan every few seconds'),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Recipe',
          subtitle:
              'A recipe is a theme, not a bundle — start here, then edit.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ScanPreset preset in ScanPreset.values)
                ActionChip(
                  label: Text(preset.name),
                  onPressed: () => onTheme(ScanFxRecipes.theme(preset)),
                ),
              for (final String name in const <String>[
                'dark',
                'light',
                'bankingBlue',
                'highContrast',
              ])
                ActionChip(
                  label: Text(name),
                  onPressed: () => onTheme(_namedTheme(name)),
                ),
            ],
          ),
        ),
        _ChoiceRow<ScanFrameShape>(
          label: 'Frame shape',
          values: ScanFrameShape.values,
          selected: theme.frameShape,
          onSelected: (ScanFrameShape v) =>
              onTheme(theme.copyWith(frameShape: v)),
        ),
        _ChoiceRow<ScanCornerStyle>(
          label: 'Corners',
          values: ScanCornerStyle.values,
          selected: theme.cornerStyle,
          onSelected: (ScanCornerStyle v) =>
              onTheme(theme.copyWith(cornerStyle: v)),
        ),
        _ChoiceRow<ScanBeamStyle>(
          label: 'Beam',
          values: ScanBeamStyle.values,
          selected: theme.beamStyle,
          onSelected: (ScanBeamStyle v) =>
              onTheme(theme.copyWith(beamStyle: v)),
        ),
        _ChoiceRow<ScanBackdropStyle>(
          label: 'Backdrop',
          values: ScanBackdropStyle.values,
          selected: theme.backdropStyle,
          onSelected: (ScanBackdropStyle v) =>
              onTheme(theme.copyWith(backdropStyle: v)),
        ),
        _ChoiceRow<ScanLockStyle>(
          label: 'Lock-on',
          values: ScanLockStyle.values,
          selected: theme.lockStyle,
          onSelected: (ScanLockStyle v) =>
              onTheme(theme.copyWith(lockStyle: v)),
        ),
        _ChoiceRow<ScanSuccessStyle>(
          label: 'Success',
          values: ScanSuccessStyle.values,
          selected: theme.successStyle,
          onSelected: (ScanSuccessStyle v) =>
              onTheme(theme.copyWith(successStyle: v)),
        ),
        _ChoiceRow<ScanErrorStyle>(
          label: 'Fault',
          values: ScanErrorStyle.values,
          selected: theme.errorStyle,
          onSelected: (ScanErrorStyle v) =>
              onTheme(theme.copyWith(errorStyle: v)),
        ),
        _ChoiceRow<ScanIdleStyle>(
          label: 'Idle motion',
          values: ScanIdleStyle.values,
          selected: theme.idleStyle,
          onSelected: (ScanIdleStyle v) =>
              onTheme(theme.copyWith(idleStyle: v)),
        ),
        _Section(
          title: 'Live tunables',
          subtitle: 'Applied without resetting the animation in flight.',
          child: Column(
            children: <Widget>[
              _SliderRow(
                label: 'Intensity',
                value: tunables.intensity,
                min: 0,
                max: 1,
                onChanged: (double v) =>
                    onTunables(tunables.copyWith(intensity: v)),
              ),
              _SliderRow(
                label: 'Speed',
                value: tunables.speed,
                min: 0.25,
                max: 3,
                onChanged: (double v) =>
                    onTunables(tunables.copyWith(speed: v)),
              ),
              _SliderRow(
                label: 'Glow',
                value: tunables.glow ?? theme.glowStrength,
                min: 0,
                max: 1.5,
                onChanged: (double v) => onTunables(tunables.copyWith(glow: v)),
                onReset: () => onTunables(tunables.copyWith(clearGlow: true)),
              ),
              _SliderRow(
                label: 'Radius',
                value: tunables.cornerRadius ?? theme.cornerRadius,
                min: 0,
                max: 56,
                onChanged: (double v) =>
                    onTunables(tunables.copyWith(cornerRadius: v)),
                onReset: () =>
                    onTunables(tunables.copyWith(clearCornerRadius: true)),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Read it back',
          subtitle: 'The exact theme the overlay is rendering right now.',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              <String>[
                'frameShape: ${theme.frameShape.name},',
                'cornerStyle: ${theme.cornerStyle.name},',
                'beamStyle: ${theme.beamStyle.name},',
                'backdropStyle: ${theme.backdropStyle.name},',
                'lockStyle: ${theme.lockStyle.name},',
                'successStyle: ${theme.successStyle.name},',
                'errorStyle: ${theme.errorStyle.name},',
                'idleStyle: ${theme.idleStyle.name},',
              ].join('\n'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF9FB3CC),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static QrScanFxTheme _namedTheme(String name) => switch (name) {
        'light' => QrScanFxTheme.light,
        'bankingBlue' => QrScanFxTheme.bankingBlue,
        'highContrast' => QrScanFxTheme.highContrast,
        _ => QrScanFxTheme.dark,
      };
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8FA3BF)),
              ),
            ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final ScanFxState state;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      ScanFxState.success => const Color(0xFF35D07F),
      ScanFxState.error => const Color(0xFFFF5A5F),
      ScanFxState.invalid => const Color(0xFFFFB020),
      ScanFxState.locked => const Color(0xFF7CC2FF),
      _ => const Color(0xFF8FA3BF),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        state.name,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A label plus a horizontally scrollable row of choice chips — one per enum
/// value. Seeing every option beats a dropdown: the studio exists to show the
/// vocabulary, not to hide it.
class _ChoiceRow<T extends Enum> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFC9D6E6),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final T value in values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(value.name),
                      selected: value == selected,
                      onSelected: (_) => onSelected(value),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onReset,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFC9D6E6)),
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
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8FA3BF)),
          ),
        ),
        SizedBox(
          width: 32,
          child: onReset == null
              ? null
              : IconButton(
                  tooltip: 'Reset to theme',
                  iconSize: 16,
                  onPressed: onReset,
                  icon: const Icon(Icons.undo),
                ),
        ),
      ],
    );
  }
}
