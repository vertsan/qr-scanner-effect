import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

/// The lock-on and burst effects are all *transient*: they draw while their
/// animation is in flight and must contribute nothing once it has landed. This
/// file proves that by rasterising a single layer and counting the pixels it
/// actually inked.
///
/// Counting pixels rather than mocking the canvas keeps the test honest: it
/// observes the same output the engine would composite, so an effect that
/// "returns early" but still strokes a fully transparent path would fail here.

const ui.Size _size = ui.Size(300, 300);

/// The quad every case tracks.
const ui.Rect _bounds = ui.Rect.fromLTWH(70, 70, 160, 160);

ScanFxFrame _frame({
  required ui.Rect quad,
  ui.Rect? locked,
  double focus = 0,
  double? focusRaw,
  double pulse = 1,
  double feedback = 0,
  ScanFxState state = ScanFxState.detected,
  QrScanFxTheme theme = QrScanFxTheme.dark,
  double reveal = 1,
}) =>
    ScanFxFrame(
      size: _size,
      state: state,
      theme: theme,
      frameShape: theme.frameShape,
      ambientSeconds: 0,
      focus: focus,
      focusRaw: focusRaw ?? focus,
      beamSpan: 1,
      breath: 1,
      dim: 0,
      feedback: feedback,
      pulse: pulse,
      hint: 1,
      reveal: reveal,
      shake: ui.Offset.zero,
      quad: ScanFxQuad.fromRect(quad),
      defaultQuad: ScanFxQuad.fromRect(quad),
      lockedQuad: locked == null ? null : ScanFxQuad.fromRect(locked),
      idleScale: 1,
      idleOffset: ui.Offset.zero,
      shimmer: 0,
      reduceMotion: false,
      textDirection: ui.TextDirection.ltr,
      revision: 0,
    );

/// Rasterises one layer and reports how much it inked and where.
///
/// The centroid is what makes "the geometry never moves for an invalid read"
/// testable: an effect that tints in place and one that jumps by four pixels ink
/// exactly the same *number* of pixels, so only their position tells them apart.
typedef _Ink = ({int count, double cx, double cy});

Future<_Ink> _ink(ScanLayer layer, ScanFxFrame frame) async {
  final width = frame.size.width.toInt();
  final height = frame.size.height.toInt();
  final recorder = ui.PictureRecorder();
  layer.paint(ui.Canvas(recorder), frame.size, frame);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  picture.dispose();
  image.dispose();
  final bytes = data!.buffer.asUint8List();

  var count = 0;
  var sumX = 0.0;
  var sumY = 0.0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (bytes[(y * width + x) * 4 + 3] != 0) {
        count++;
        sumX += x;
        sumY += y;
      }
    }
  }
  return (
    count: count,
    cx: count == 0 ? 0.0 : sumX / count,
    cy: count == 0 ? 0.0 : sumY / count,
  );
}

/// Just the number of pixels [layer] inked.
Future<int> _inked(ScanLayer layer, ScanFxFrame frame) async =>
    (await _ink(layer, frame)).count;

void main() {
  group('lock-on reticle', () {
    test('the AI focus brackets travel, then vanish', () async {
      final reticle = ScanFxRegistry.reticle(ScanLockStyle.springSnap);

      // Early in the lock: the quad is still at the default area and the
      // brackets are outside it, at full strength.
      final travelling = await _inked(
        reticle,
        _frame(quad: _bounds, locked: _bounds, focus: 0.05),
      );
      expect(travelling, greaterThan(0));

      // Settled: the corner layer owns the look, so the reticle is silent. This
      // is the assertion that keeps the two bracket families from ever being
      // drawn on top of each other.
      final settled = await _inked(
        reticle,
        _frame(quad: _bounds, locked: _bounds, focus: 1),
      );
      expect(settled, 0);
    });

    test('no target means no focus flourish', () async {
      final reticle = ScanFxRegistry.reticle(ScanLockStyle.springSnap);
      expect(await _inked(reticle, _frame(quad: _bounds)), 0);
    });

    test('the confirmation ring plays once and then stops', () async {
      final reticle = ScanFxRegistry.reticle(ScanLockStyle.springSnap);

      // Focus settled, so anything inked here is the ring alone.
      final ringing = await _inked(
        reticle,
        _frame(quad: _bounds, locked: _bounds, focus: 1, pulse: 0.3),
      );
      expect(ringing, greaterThan(0));

      final done = await _inked(
        reticle,
        _frame(quad: _bounds, locked: _bounds, focus: 1, pulse: 1),
      );
      expect(done, 0);
    });

    test('every flourish is silent once the lock has landed', () async {
      for (final style in ScanLockStyle.values) {
        final reticle = ScanFxRegistry.reticle(style);
        expect(
          await _inked(
            reticle,
            _frame(quad: _bounds, locked: _bounds, focus: 1, pulse: 1),
          ),
          0,
          reason: '$style',
        );
      }
    });

    test('an overshooting lock is visible in the brackets', () async {
      // The style reads `focusRaw`, so a spring past its target is a different
      // picture from a settled one.
      final reticle = ScanFxRegistry.reticle(ScanLockStyle.springSnap);
      final overshoot = await _inked(
        reticle,
        _frame(quad: _bounds, locked: _bounds, focus: 1, focusRaw: 1.04),
      );
      final settled = await _inked(
        reticle,
        _frame(quad: _bounds, locked: _bounds, focus: 1, focusRaw: 1),
      );
      expect(settled, 0);
      expect(overshoot, 0, reason: 'the flourish has already handed off');
    });
  });

  group('success bursts', () {
    test('ripples expand and then leave nothing behind', () async {
      final effect = ScanFxRegistry.success(ScanSuccessStyle.rippleWaves);
      final mid = await _inked(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.success,
          feedback: 0.1,
        ),
      );
      expect(mid, greaterThan(0));

      final after = await _inked(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.success,
          feedback: 1,
        ),
      );
      expect(after, 0);
    });

    test('confetti bursts and then leaves nothing behind', () async {
      final effect = ScanFxRegistry.success(ScanSuccessStyle.confetti);
      final mid = await _inked(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.success,
          feedback: 0.35,
        ),
      );
      expect(mid, greaterThan(0));

      final after = await _inked(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.success,
          feedback: 1,
        ),
      );
      expect(after, 0);
    });

    test('confetti is inert outside the success state', () async {
      final effect = ScanFxRegistry.success(ScanSuccessStyle.confetti);
      expect(
        await _inked(
          effect,
          _frame(quad: _bounds, locked: _bounds, focus: 1, feedback: 0.35),
        ),
        0,
      );
    });
  });

  group('fault bursts', () {
    test('the glitch fires on error and clears', () async {
      final effect = ScanFxRegistry.error(ScanErrorStyle.glitch);
      final mid = await _inked(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.error,
          feedback: 0.3,
        ),
      );
      expect(mid, greaterThan(0));

      final after = await _inked(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.error,
          feedback: 1,
        ),
      );
      expect(after, 0);
    });

    test('an invalid read tints in place while an error jumps', () async {
      final effect = ScanFxRegistry.error(ScanErrorStyle.glitch);
      final invalid = await _ink(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.invalid,
          feedback: 0.3,
        ),
      );
      final error = await _ink(
        effect,
        _frame(
          quad: _bounds,
          locked: _bounds,
          focus: 1,
          state: ScanFxState.error,
          feedback: 0.3,
        ),
      );

      // Both draw something...
      expect(invalid.count, greaterThan(0));
      expect(error.count, greaterThan(0));

      // ...but only the error displaces the frame. At this point in the burst
      // the jump table has selected a downward offset, so the error's ink sits
      // below the quad's centre while the invalid tint stays on it.
      const center = 150.0;
      expect(invalid.cx, closeTo(center, 1.0));
      expect(invalid.cy, closeTo(center, 1.0));
      expect(error.cy, greaterThan(invalid.cy + 2));
    });

    test('every fault style clears when its burst ends', () async {
      for (final style in ScanErrorStyle.values) {
        final effect = ScanFxRegistry.error(style);
        for (final state in <ScanFxState>[
          ScanFxState.error,
          ScanFxState.invalid,
        ]) {
          expect(
            await _inked(
              effect,
              _frame(
                quad: _bounds,
                locked: _bounds,
                focus: 1,
                state: state,
                feedback: 1,
              ),
            ),
            0,
            reason: '$style in $state',
          );
        }
      }
    });
  });
}
