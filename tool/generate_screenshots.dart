// Generates preview screenshots for the pub.dev page.
//
// This mirrors the probe that the regression tests use, so the shots are
// reproducible: it rasterises the full layer stack for a few canonical themes
// across the handful of states worth showing, and writes lossless PNGs under
// `screenshots/`.
//
// `dart:ui` only exists inside a Flutter engine, so this runs through the test
// harness rather than the plain VM. It lives outside `test/`, so a normal
// `flutter test` does not pick it up:
//
//   flutter test tool/generate_screenshots.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

/// Size of every preview shot.
const ui.Size _size = ui.Size(320, 320);

/// A neutral background, so a "draws nothing" mistake is obvious by eye.
const ui.Color _ground = ui.Color(0xFF151B28);

/// Canonical moments of the lifecycle.
const List<_Shot> _shots = <_Shot>[
  _Shot('idle', ScanFxState.idle, 0, 0),
  _Shot('scanning', ScanFxState.scanning, 0, 0, pulse: 0),
  _Shot('detected', ScanFxState.detected, 0.35, 0.25),
  _Shot('locked', ScanFxState.locked, 1, 0.6),
  _Shot('success', ScanFxState.success, 1, 0.35),
  _Shot('invalid', ScanFxState.invalid, 1, 0.28),
];

/// The themes worth putting on a store page.
final List<_ThemeShot> _themes = <_ThemeShot>[
  _ThemeShot('hero_dark', QrScanFxTheme.dark),
  _ThemeShot('hero_banking', QrScanFxTheme.bankingBlue),
  _ThemeShot('recipe_cyberpunk', ScanFxRecipes.theme(ScanPreset.cyberpunk)),
  _ThemeShot(
      'recipe_apple_vision', ScanFxRecipes.theme(ScanPreset.appleVision)),
  _ThemeShot('recipe_retro_laser', ScanFxRecipes.theme(ScanPreset.retroLaser)),
  _ThemeShot('recipe_playful_pop', ScanFxRecipes.theme(ScanPreset.playfulPop)),
];

void main() {
  test('renders the pub.dev screenshots', () async {
    final Directory shots = Directory('screenshots');
    if (!shots.existsSync()) {
      shots.createSync(recursive: true);
    }

    var written = 0;
    for (final _ThemeShot theme in _themes) {
      for (final _Shot shot in _shots) {
        final File file = File('${shots.path}/${theme.slug}_${shot.name}.png');
        await _write(file, theme.theme, shot);
        written++;
      }
    }

    stdout.writeln('wrote $written screenshots to ${shots.path}/');
    expect(written, _themes.length * _shots.length);
  });
}

/// One moment worth rendering.
class _Shot {
  const _Shot(
    this.name,
    this.state,
    this.focus,
    this.feedback, {
    this.pulse = 0.4,
  });

  final String name;
  final ScanFxState state;
  final double focus;
  final double feedback;
  final double pulse;
}

/// One theme, under a filename-safe slug.
class _ThemeShot {
  const _ThemeShot(this.slug, this.theme);

  final String slug;
  final QrScanFxTheme theme;
}

Future<void> _write(File file, QrScanFxTheme theme, _Shot shot) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawColor(_ground, ui.BlendMode.src);

  final ui.Rect quad = ui.Rect.fromLTWH(50, 54, 220, 220);
  final ScanFxFrame frame = ScanFxFrame(
    size: _size,
    state: shot.state,
    theme: theme,
    frameShape: theme.frameShape,
    ambientSeconds: 0.42,
    focus: shot.focus,
    focusRaw: shot.focus,
    beamSpan: 0.25,
    breath: 0.6,
    dim: 1,
    feedback: shot.feedback,
    pulse: shot.pulse,
    hint: 1,
    reveal: 1,
    shake: ui.Offset.zero,
    quad: ScanFxQuad.fromRect(quad),
    defaultQuad: ScanFxQuad.fromRect(quad),
    lockedQuad: ScanFxQuad.fromRect(quad),
    idleScale: 1,
    idleOffset: ui.Offset.zero,
    shimmer: 0.4,
    reduceMotion: false,
    textDirection: ui.TextDirection.ltr,
    revision: 0,
  );

  final ScanLayerStack stack = ScanFxRegistry.buildStack(theme);
  for (final ScanLayerEntry entry in stack.entries) {
    if (!entry.visible) continue;
    entry.layer.paint(canvas, frame.size, frame);
  }

  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    _size.width.toInt(),
    _size.height.toInt(),
  );
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();

  await file.writeAsBytes(bytes!.buffer.asUint8List());
}
