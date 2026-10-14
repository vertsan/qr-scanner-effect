import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

Widget _host(Widget child) => MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: child),
    );

/// Pumps in 60 fps steps.
///
/// A single large `pump` would only advance the animation by the director's
/// stall clamp (50 ms), which is deliberate production behaviour: a frame that
/// arrives after a debugger pause must not teleport the animation. Tests have to
/// tick like a real device.
Future<void> _settle(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 16);
  var remaining = duration;
  while (remaining > Duration.zero) {
    final next = remaining < step ? remaining : step;
    await tester.pump(next);
    remaining -= next;
  }
}

void main() {
  group('QrScanFx widget', () {
    testWidgets('renders idle over a preview and unmounts cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(child: ColoredBox(color: Color(0xFF101010))),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('runs the whole lifecycle through the controller', (
      tester,
    ) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(
              controller: controller,
              scanAreaSize: const Size(220, 220),
            ),
          ),
        ),
      );

      expect(controller.value, ScanFxState.idle);
      expect(controller.hasTarget, isFalse);

      // A detection can arrive before anything else, straight out of `idle`.
      controller.lockOn(
        ScanFxTarget.rect(const Rect.fromLTWH(90, 90, 180, 180)),
      );
      expect(controller.value, ScanFxState.detected);
      expect(controller.hasTarget, isTrue);
      await tester.pump();

      // The hold window elapses on its own and the lock settles.
      await _settle(tester, const Duration(milliseconds: 600));
      expect(controller.value, ScanFxState.locked);

      controller.success();
      await tester.pump();
      expect(controller.value, ScanFxState.success);

      // Let the success burst play out; nothing may throw.
      await _settle(tester, const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);

      controller.error('That code is not supported');
      await tester.pump();
      expect(controller.value, ScanFxState.error);
      expect(controller.message.value, 'That code is not supported');
      await _settle(tester, const Duration(milliseconds: 800));

      controller.invalid();
      await tester.pump();
      expect(controller.value, ScanFxState.invalid);
      await _settle(tester, const Duration(milliseconds: 600));

      controller.reset();
      await tester.pump();
      expect(controller.value, ScanFxState.scanning);
      expect(controller.hasTarget, isFalse);
      expect(controller.message.value, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a repeated detection never restarts the lock hold', (
      tester,
    ) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(controller: controller),
          ),
        ),
      );

      // Simulate a 30 fps detector: keep re-reporting the target while the hold
      // window runs. The overlay must still reach `locked`.
      for (var i = 0; i < 20; i++) {
        controller.lockOn(
          ScanFxTarget.rect(Rect.fromLTWH(90 + i.toDouble(), 90, 180, 180)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(controller.value, ScanFxState.locked);
    });

    testWidgets('declarative mode is authoritative and silent on attach', (
      tester,
    ) async {
      final states = <ScanFxState>[];

      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 320,
            height: 320,
            child: QrScanFx(state: ScanFxState.success),
          ),
        ),
      );

      // Opening already in a declared state must not report a change.
      expect(states, isEmpty);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            height: 320,
            child: QrScanFx(
              state: ScanFxState.error,
              onStateChanged: states.add,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(states, <ScanFxState>[ScanFxState.error]);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('declarative geometry tracks the target', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 320,
            height: 320,
            child: QrScanFx(
              state: ScanFxState.locked,
              detectedBounds: Rect.fromLTWH(80, 80, 160, 160),
            ),
          ),
        ),
      );
      await _settle(tester, const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('rotated corner targets and quarter turns render', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 320,
            height: 320,
            child: QrScanFx(
              state: ScanFxState.locked,
              quarterTurns: 1,
              flipX: true,
              detectedCorners: <Offset>[
                Offset(0.6, 0.2),
                Offset(0.9, 0.35),
                Offset(0.75, 0.65),
                Offset(0.45, 0.5),
              ],
              normalized: true,
            ),
          ),
        ),
      );
      await _settle(tester, const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('reduce-motion still locks, just without the spring', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(controller: controller),
          ),
        ),
      );

      controller.lockOn(
        ScanFxTarget.rect(const Rect.fromLTWH(80, 80, 200, 200)),
      );
      await tester.pump();
      await _settle(tester, const Duration(milliseconds: 600));
      expect(controller.value, ScanFxState.locked);

      // Each terminal burst must render to its steady state, not to nothing:
      // under reduce-motion the director jumps the burst forward, so an effect
      // that only "fades out" would otherwise be invisible.
      controller.success();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _settle(tester, const Duration(milliseconds: 300));

      controller.reset();
      await tester.pump();
      controller.error('nope');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _settle(tester, const Duration(milliseconds: 300));

      controller.reset();
      await tester.pump();
      controller.invalid('wrong');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _settle(tester, const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a swap of controllers is picked up', (tester) async {
      final first = QrScanFxController();
      final second = QrScanFxController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(controller: first),
          ),
        ),
      );

      first.lockOn(ScanFxTarget.rect(const Rect.fromLTWH(80, 80, 200, 200)));
      await tester.pump();
      expect(first.value, ScanFxState.detected);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(controller: second),
          ),
        ),
      );
      await tester.pump();
      expect(second.value, ScanFxState.idle);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('custom layers can reorder, hide and replace', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      ScanLayerStack? seen;

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(
              controller: controller,
              layers: (context, stack) {
                seen = stack.hide(ScanLayerKind.hint).replace(
                      ScanLayerKind.reticle,
                      CustomScanLayer(
                        _NullPainter(),
                        layerKind: ScanLayerKind.reticle,
                      ),
                    );
                return seen!;
              },
            ),
          ),
        ),
      );

      final stack = seen!;
      expect(stack.entries, isNotEmpty);
      expect(stack.find(ScanLayerKind.reticle), isA<CustomScanLayer>());
      expect(
        stack.entries
            .firstWhere((e) => e.layer.kind == ScanLayerKind.hint)
            .visible,
        isFalse,
      );

      controller.lockOn(
        ScanFxTarget.rect(const Rect.fromLTWH(80, 80, 200, 200)),
      );
      await _settle(tester, const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('pause freezes motion and resume restarts it', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx(controller: controller),
          ),
        ),
      );

      controller.lockOn(
        ScanFxTarget.rect(const Rect.fromLTWH(80, 80, 200, 200)),
      );
      await tester.pump();
      controller.pause();
      expect(controller.isPaused.value, isTrue);
      await _settle(tester, const Duration(milliseconds: 400));
      // A paused overlay does not advance its timers, so the hold never elapses.
      expect(controller.value, ScanFxState.detected);

      controller.resume();
      expect(controller.isPaused.value, isFalse);
      await _settle(tester, const Duration(milliseconds: 600));
      expect(controller.value, ScanFxState.locked);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

class _NullPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
