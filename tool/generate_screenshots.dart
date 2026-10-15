// Generates the preview screenshots used by the README and the pub.dev page.
//
// This mirrors the probe that the regression tests use, so the shots are
// reproducible: it rasterises the full layer stack for the themes and moments
// worth showing, and writes lossless PNGs under `screenshots/`.
//
// `dart:ui` only exists inside a Flutter engine, so this runs through the test
// harness rather than the plain VM. It lives outside `test/`, so a normal
// `flutter test` does not pick it up:
//
//   flutter test tool/generate_screenshots.dart
//
// The set of shots is deliberate, not exhaustive: every file written here is
// referenced by `README.md` or by the `screenshots:` list in `pubspec.yaml`, so
// the published archive carries nothing that is not shown to a reader.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

/// Size of every preview shot.
const ui.Size _size = ui.Size(320, 320);

/// A neutral background, so a "draws nothing" mistake is obvious by eye.
const ui.Color _ground = ui.Color(0xFF151B28);

/// The scan area the stack is drawn around.
const ui.Rect _quad = ui.Rect.fromLTWH(50, 54, 220, 220);

// The four moments worth showing. `feedback` sweeps the terminal burst.
const _Shot _scanning = _Shot(ScanFxState.scanning, 0, 0, pulse: 0);
const _Shot _locked = _Shot(ScanFxState.locked, 1, 0.6);
const _Shot _success = _Shot(ScanFxState.success, 1, 0.35);
const _Shot _invalid = _Shot(ScanFxState.invalid, 1, 0.28);

/// The themes referenced from the two documents.
final QrScanFxTheme _cyberpunk = ScanFxRecipes.theme(ScanPreset.cyberpunk);
final QrScanFxTheme _appleVision = ScanFxRecipes.theme(ScanPreset.appleVision);
final QrScanFxTheme _retroLaser = ScanFxRecipes.theme(ScanPreset.retroLaser);
final QrScanFxTheme _playfulPop = ScanFxRecipes.theme(ScanPreset.playfulPop);

/// Every file this tool writes, in the order the README shows them.
final List<_Preview> _previews = <_Preview>[
  _Preview('hero_dark_scanning', QrScanFxTheme.dark, _scanning),
  _Preview('hero_dark_locked', QrScanFxTheme.dark, _locked),
  _Preview('hero_dark_success', QrScanFxTheme.dark, _success),
  _Preview('hero_banking_locked', QrScanFxTheme.bankingBlue, _locked),
  _Preview('hero_banking_invalid', QrScanFxTheme.bankingBlue, _invalid),
  _Preview('recipe_cyberpunk_locked', _cyberpunk, _locked),
  _Preview('recipe_apple_vision_locked', _appleVision, _locked),
  _Preview('recipe_retro_laser_locked', _retroLaser, _locked),
  _Preview('recipe_playful_pop_locked', _playfulPop, _locked),
];

void main() {
  test('renders the pub.dev screenshots', () async {
    final Directory shots = Directory('screenshots');
    if (!shots.existsSync()) {
      shots.createSync(recursive: true);
    }

    for (final _Preview preview in _previews) {
      final File file = File('${shots.path}/${preview.name}.png');
      await _write(file, preview.theme, preview.shot);
      stdout.writeln('wrote ${file.path}');
    }

    // Anything left over is a shot that was renamed or retired; leaving it
    // behind would ship a file nothing references.
    final Set<String> expected = <String>{
      for (final _Preview preview in _previews) '${preview.name}.png',
    };
    for (final FileSystemEntity entity in shots.listSync()) {
      final String name = entity.uri.pathSegments.last;
      if (entity is File && !expected.contains(name)) {
        entity.deleteSync();
        stdout.writeln('removed stale ${entity.path}');
      }
    }

    expect(_previews.length, greaterThan(0));
  });
}

/// One file to write: [name] without the `.png`, a [theme], and a [shot].
class _Preview {
  const _Preview(this.name, this.theme, this.shot);

  /// The base filename, without the extension.
  final String name;

  /// The theme to render.
  final QrScanFxTheme theme;

  /// The moment to render.
  final _Shot shot;
}

/// One moment worth rendering.
class _Shot {
  const _Shot(
    this.state,
    this.focus,
    this.feedback, {
    this.pulse = 0.4,
  });

  final ScanFxState state;
  final double focus;
  final double feedback;
  final double pulse;
}

Future<void> _write(File file, QrScanFxTheme theme, _Shot shot) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawColor(_ground, ui.BlendMode.src);

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
    quad: ScanFxQuad.fromRect(_quad),
    defaultQuad: ScanFxQuad.fromRect(_quad),
    lockedQuad: ScanFxQuad.fromRect(_quad),
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
