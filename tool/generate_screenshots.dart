// Generates preview screenshots for pub.dev.
//
// This mirrors the visual probe that the regression tests use, so screenshots
// are portable and consistent: it renders the full stack for a few canonical
// themes and a few canonical states, saving lossless PNGs under screenshots/.
//
// Run from the package root:
//
//   dart run tool/generate_screenshots.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

/// Size of the hero and preview shots.
const ui.Size _size = ui.Size(320, 320);

/// A neutral background, so a "doesn't draw" guard is trivial.
const ui.Color _ground = ui.Color(0xFF151B28);

/// Canonical states used to show the lifecycle at a glance.
const List<_Shot> _shots = <_Shot>[
  _Shot('idle', ScanFxState.idle, 0, 0),
  _Shot('scanning', ScanFxState.scanning, 0, 0, pulse: 0),
  _Shot('detected', ScanFxState.detected, 0.35, 0.25),
  _Shot('locked', ScanFxState.locked, 1, 0.6),
  _Shot('success', ScanFxState.success, 1, 0.35),
  _Shot('invalid', ScanFxState.invalid, 1, 0.28),
];

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

Future<void> main() async {
  // The Flutter binding isn't strictly required for a pure `dart:ui` render, but
  // `WidgetsFlutterBinding` is exported from `package:flutter/material.dart`
  // used for other tooling. Import the binding instead of pulling the whole
  // widget tree test helpers.
  ui.FlutterBinding.ensureInitialized();

  final Directory shots = Directory('screenshots');
  if (!shots.existsSync()) {
    shots.createSync();
  }

  final List<_ThemeShot> themes = <_ThemeShot>[
    _ThemeShot('hero_dark', QrScanFxTheme.dark),
    _ThemeShot('hero_banking', QrScanFxTheme.bankingBlue),
    _ThemeShot('recipe_cyberpunk', ScanFxRecipes.theme(ScanPreset.cyberpunk)),
    _ThemeShot('recipe_appl_vision', ScanFxRecipes.theme(ScanPreset.appleVision)),
    _ThemeShot('recipe_retro', ScanFxRecipes.theme(ScanPreset.retroLaser)),
    _ThemeShot('recipe_playful', ScanFxRecipes.theme(ScanPreset.playfulPop)),
  ];

  for (final _ThemeShot theme in themes) {
    for (final _Shot shot in _shots) {
      final File f = File('screenshots/${theme.slug}_${shot.name}.png');
      await _write(f, theme.theme, shot);
      stdout.writeln('wrote ${f.path}');
    }
  }
}

class _ThemeShot {
  _ThemeShot(this.slug, this.theme);

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
  final ui.Image image = await picture.toImage(320, 320);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();

  await file.writeAsBytes(bytes!.buffer.asUint8List());
}
