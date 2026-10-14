import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

Widget _host(Widget child) => MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: child),
    );

/// Pumps in 60 fps steps so the director's per-tick stall clamp is respected.
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
  group('ScanPreset recipes', () {
    test('every preset resolves to a buildable theme', () {
      for (final preset in ScanPreset.values) {
        final theme = ScanFxRecipes.theme(preset);

        // The resolved theme must be coherent: distinguishable terminal
        // colours, and a stack the registry can actually build.
        expect(theme.successColor, isNot(theme.errorColor));
        expect(theme.errorColor, isNot(theme.invalidColor));

        final stack = ScanFxRegistry.buildStack(theme);
        expect(
          stack.entries.length,
          greaterThan(0),
          reason: 'preset $preset produced an empty stack',
        );
        expect(
          stack.find(ScanLayerKind.frame),
          isNotNull,
          reason: 'preset $preset has no frame layer',
        );
        expect(
          stack.find(ScanLayerKind.reticle),
          isNotNull,
          reason: 'preset $preset has no reticle layer',
        );
      }
    });

    test('every preset is distinct', () {
      final seen = <QrScanFxTheme>{};
      for (final preset in ScanPreset.values) {
        expect(
          seen.add(ScanFxRecipes.theme(preset)),
          isTrue,
          reason: 'preset $preset resolves to a theme another preset uses',
        );
      }
    });

    testWidgets('QrScanFx.preset renders every preset', (tester) async {
      for (final preset in ScanPreset.values) {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 360,
              height: 360,
              child: QrScanFx.preset(
                preset,
                child: const ColoredBox(color: Color(0xFF101010)),
              ),
            ),
          ),
        );

        await _settle(tester, const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a preset theme reaches the layers', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.preset(
              ScanPreset.retroLaser,
              child: const ColoredBox(color: Color(0xFF101010)),
            ),
          ),
        ),
      );

      final overlay = tester.widget<QrScanFx>(find.byType(QrScanFx));
      expect(overlay.theme, ScanFxRecipes.theme(ScanPreset.retroLaser));
      expect(
        overlay.theme!.frameShape,
        ScanFrameShape.fullBorder,
        reason: 'the recipe picked a straight-edged frame',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
