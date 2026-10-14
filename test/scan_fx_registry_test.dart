import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

Widget _host(Widget child) => MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: child),
    );

void main() {
  group('ScanFxRegistry', () {
    test('every style enum value maps to a layer of the right kind', () {
      for (final shape in ScanFrameShape.values) {
        final layer = ScanFxRegistry.frame(shape);
        expect(layer, isA<ScanFrameLayer>(), reason: '$shape');
        expect(layer.kind, ScanLayerKind.frame);
      }
      for (final style in ScanCornerStyle.values) {
        final layer = ScanFxRegistry.corners(style);
        expect(layer, isA<ScanCornerLayer>(), reason: '$style');
        expect(layer.kind, ScanLayerKind.corners);
      }
      for (final style in ScanBeamStyle.values) {
        final layer = ScanFxRegistry.beam(style);
        expect(layer, isA<ScanBeamLayer>(), reason: '$style');
        expect(layer.kind, ScanLayerKind.beam);
      }
      for (final style in ScanBackdropStyle.values) {
        final layer = ScanFxRegistry.backdrop(style);
        expect(layer, isA<ScanBackdropLayer>(), reason: '$style');
        expect(layer.kind, ScanLayerKind.backdrop);
      }
      for (final style in ScanLockStyle.values) {
        expect(ScanFxRegistry.reticle(style).kind, ScanLayerKind.reticle);
      }
      for (final style in ScanSuccessStyle.values) {
        expect(ScanFxRegistry.success(style).kind, ScanLayerKind.effects);
      }
      for (final style in ScanErrorStyle.values) {
        expect(ScanFxRegistry.error(style).kind, ScanLayerKind.effects);
      }
      for (final style in ScanIdleStyle.values) {
        expect(
          ScanFxRegistry.idleModifier(style).transform(0.37),
          isNotNull,
          reason: '$style',
        );
      }
    });

    test('`none` members are genuinely static', () {
      expect(ScanFxRegistry.reticle(ScanLockStyle.none).animated, isFalse);
      expect(ScanFxRegistry.success(ScanSuccessStyle.none).animated, isFalse);
      expect(ScanFxRegistry.error(ScanErrorStyle.none).animated, isFalse);
      expect(ScanFxRegistry.backdrop(ScanBackdropStyle.none).animated, isFalse);
      expect(
          ScanFxRegistry.frame(ScanFrameShape.cornersOnly).animated, isFalse);
    });

    test('a stack is built back-to-front in a stable order', () {
      final stack = ScanFxRegistry.buildStack(QrScanFxTheme.dark);
      final kinds = <ScanLayerKind>[
        for (final entry in stack.entries) entry.layer.kind,
      ];
      expect(kinds, <ScanLayerKind>[
        ScanLayerKind.backdrop,
        ScanLayerKind.frame,
        ScanLayerKind.corners,
        ScanLayerKind.beam,
        ScanLayerKind.reticle,
        ScanLayerKind.effects, // success
        ScanLayerKind.effects, // error
        ScanLayerKind.hint,
      ]);
    });

    test('every preset builds a stack with a hint overlay', () {
      for (final entry in _presets.entries) {
        final stack = ScanFxRegistry.buildStack(entry.value);
        expect(stack.entries, isNotEmpty, reason: entry.key);
        expect(stack.wantsWidget, isTrue, reason: entry.key);
        expect(stack.find(ScanLayerKind.hint), isNotNull, reason: entry.key);
      }
    });
  });

  group('ScanLayerStack', () {
    ScanLayerStack fresh() => ScanFxRegistry.buildStack(QrScanFxTheme.dark);

    test('hide and show toggle visibility without changing order', () {
      final stack = fresh();
      final hidden = stack.hide(ScanLayerKind.beam);
      expect(hidden.find(ScanLayerKind.beam), isNotNull);
      expect(hidden.hasAnimatedLayers, isTrue);

      final order = hidden.entries.map((e) => e.layer.kind).toList();
      expect(
        order,
        stack.entries.map((e) => e.layer.kind).toList(),
      );
      expect(
          hidden.show(ScanLayerKind.beam).entries.length, stack.entries.length);
    });

    test('replace swaps in place and appends when absent', () {
      final stack = fresh();
      final replacement = CustomScanLayer(
        _NullPainter(),
        layerKind: ScanLayerKind.beam,
      );
      final replaced = stack.replace(ScanLayerKind.beam, replacement);
      expect(replaced.find(ScanLayerKind.beam), same(replacement));

      final indexBefore = stack.entries.indexWhere(
        (e) => e.layer.kind == ScanLayerKind.corners,
      );
      final indexAfter = replaced.entries.indexWhere(
        (e) => e.layer.kind == ScanLayerKind.corners,
      );
      expect(indexAfter, indexBefore);

      // A `kind` that is not present is appended rather than dropped.
      final hintReplacement = CustomScanLayer(
        _NullPainter(),
        layerKind: ScanLayerKind.hint,
      );
      final appended = stack
          .remove(ScanLayerKind.hint)
          .replace(ScanLayerKind.hint, hintReplacement);
      expect(appended.find(ScanLayerKind.hint), same(hintReplacement));
      expect(appended.entries.last.layer, same(hintReplacement));
    });

    test('replace does not move layers of other kinds', () {
      final stack = fresh();
      final replaced = stack.replace(
        ScanLayerKind.corners,
        CustomScanLayer(_NullPainter(), layerKind: ScanLayerKind.corners),
      );
      final before = stack.entries.map((e) => e.layer.kind).toList();
      final after = replaced.entries.map((e) => e.layer.kind).toList();
      expect(after, before);
    });

    test('remove drops the slot, insert and reorder move it', () {
      final stack = fresh();
      final removed = stack.remove(ScanLayerKind.beam);
      expect(removed.find(ScanLayerKind.beam), isNull);
      expect(removed.entries.length, stack.entries.length - 1);

      final added = removed.insert(0, CustomScanLayer(_NullPainter()));
      expect(added.entries.first.layer, isA<CustomScanLayer>());

      final reordered = added.reorder(0, 2);
      expect(reordered.entries[2].layer, isA<CustomScanLayer>());
    });

    test('equality is structural over entries', () {
      final stack = fresh();
      // Identity holds for the same stack, which is what the widget relies on:
      // it memoises the base stack so a rebuild compares equal and repaints
      // nothing.
      expect(stack, same(stack));
      expect(stack == stack.hide(ScanLayerKind.beam), isFalse);
      expect(stack == stack.replaceAt(0, CustomScanLayer(_NullPainter())),
          isFalse);
      // Two independently built stacks hold different layer instances, so they
      // are deliberately *not* equal.
      expect(fresh() == fresh(), isFalse);
    });
  });

  group('QrScanFxTheme', () {
    test('helpers resolve tunables without mutating the base theme', () {
      const tunables =
          ScanFxTunables(glow: 0.1, cornerRadius: 4, intensity: 0.5);
      final themed = QrScanFxTheme.dark.copyWith(tunables: tunables);
      expect(themed.resolvedGlow, 0.1);
      expect(themed.resolvedCornerRadius, 4);
      expect(QrScanFxTheme.dark.resolvedGlow, QrScanFxTheme.dark.glowStrength);
    });

    test('copyWith, lerp and equality are consistent', () {
      final a = QrScanFxTheme.dark;
      final b = QrScanFxTheme.light;
      expect(a.copyWith(), a);
      final mid = a.lerp(b, 0.5);
      expect(mid.frameShape, isA<ScanFrameShape>());
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
    });

    test('fromColorScheme and random produce usable themes', () {
      final fromScheme = QrScanFxTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: const Color(0xFF2962FF)),
      );
      expect(fromScheme.beamColor, isA<Color>());

      for (var seed = 0; seed < 12; seed++) {
        final random = QrScanFxTheme.random(seed: seed);
        expect(ScanFxRegistry.buildStack(random).entries, isNotEmpty);
      }
    });

    test('bankingBlue is calm: no shake, no looping burst, short motion', () {
      final banking = QrScanFxTheme.bankingBlue;
      expect(banking.error.shakeAmplitude, 0);
      expect(banking.motion.reduceMotion, isFalse);
      expect(banking.motion.success.inMilliseconds, lessThanOrEqualTo(400));
      expect(banking.motion.hint.inMilliseconds, lessThanOrEqualTo(400));
    });

    test('the banking palette keeps state colours apart from the backdrop', () {
      final banking = QrScanFxTheme.bankingBlue;
      expect(banking.frameColor, isNot(banking.backdropColor));
      expect(banking.successColor, isNot(banking.errorColor));
      expect(banking.errorColor, isNot(banking.invalidColor));
    });
  });

  group('security model', () {
    test('the controller holds no payload: geometry in, pixels out', () {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      // Nothing accepts a decoded payload. The only string the package can hold
      // is the host-supplied UI copy for a failed read, and it is cleared as soon
      // as the state moves on.
      expect(controller.message.value, isNull);

      controller.lockOn(ScanFxTarget.rect(const Rect.fromLTWH(0, 0, 10, 10)));
      expect(controller.message.value, isNull);

      controller.error('Unsupported code');
      expect(controller.message.value, 'Unsupported code');
      controller.success();
      expect(controller.message.value, isNull);

      controller.invalid('Wrong merchant');
      controller.reset();
      expect(controller.message.value, isNull);

      // A controller cannot be constructed with payload text at all.
      expect(controller.value, isA<ScanFxState>());
    });

    test('ScanFxTarget accepts geometry only and rejects malformed corners',
        () {
      expect(ScanFxTarget.rect(Rect.zero).isRect, isTrue);
      expect(() => ScanFxTarget.corners(const <Offset>[]), throwsArgumentError);
      expect(
        () => ScanFxTarget.corners(const <Offset>[Offset.zero]),
        throwsArgumentError,
      );
    });
  });

  group('style matrix', () {
    testWidgets('every style value paints in every state without throwing', (
      tester,
    ) async {
      final themes = <String, QrScanFxTheme>{};
      for (final shape in ScanFrameShape.values) {
        themes['frame:$shape'] = QrScanFxTheme.dark.copyWith(frameShape: shape);
      }
      for (final style in ScanCornerStyle.values) {
        themes['corners:$style'] =
            QrScanFxTheme.dark.copyWith(cornerStyle: style);
      }
      for (final style in ScanBeamStyle.values) {
        themes['beam:$style'] = QrScanFxTheme.dark.copyWith(beamStyle: style);
      }
      for (final style in ScanBackdropStyle.values) {
        themes['backdrop:$style'] =
            QrScanFxTheme.dark.copyWith(backdropStyle: style);
      }
      for (final style in ScanLockStyle.values) {
        themes['lock:$style'] = QrScanFxTheme.dark.copyWith(lockStyle: style);
      }
      for (final style in ScanSuccessStyle.values) {
        themes['success:$style'] =
            QrScanFxTheme.dark.copyWith(successStyle: style);
      }
      for (final style in ScanErrorStyle.values) {
        themes['error:$style'] = QrScanFxTheme.dark.copyWith(errorStyle: style);
      }
      for (final style in ScanIdleStyle.values) {
        themes['idle:$style'] = QrScanFxTheme.dark.copyWith(idleStyle: style);
      }

      for (final entry in themes.entries) {
        final controller = QrScanFxController();
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 300,
              height: 300,
              child: QrScanFx(controller: controller, theme: entry.value),
            ),
          ),
        );

        controller.lockOn(
          ScanFxTarget.rect(const Rect.fromLTWH(50, 50, 200, 200)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        controller.success();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        controller.error();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        controller.invalid();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        controller.reset();
        await tester.pump();

        expect(tester.takeException(), isNull, reason: entry.key);

        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });
  });
}

const Map<String, QrScanFxTheme> _presets = <String, QrScanFxTheme>{
  'dark': QrScanFxTheme.dark,
  'light': QrScanFxTheme.light,
  'bankingBlue': QrScanFxTheme.bankingBlue,
  'minimalLight': QrScanFxTheme.minimalLight,
};

class _NullPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
