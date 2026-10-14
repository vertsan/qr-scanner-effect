import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

Widget _host(Widget child, {double textScale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
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

/// Drives a controller to [ScanFxState.invalid] from a cold start.
void _toInvalid(QrScanFxController controller, String message) {
  controller.start();
  controller.invalid(message);
}

void main() {
  group('QrScanFx.banking', () {
    testWidgets('uses the banking palette', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(controller: controller),
          ),
        ),
      );

      final overlay = tester.widget<QrScanFx>(find.byType(QrScanFx));
      expect(overlay.theme, QrScanFxTheme.bankingBlue);
      // autoLock is not part of the public widget surface; the banking factory
      // relies on the default (true), which is what `detected → locked` needs.
      expect(overlay.autoLock, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('shows the status notice on invalid, with host copy', (
      tester,
    ) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(controller: controller),
          ),
        ),
      );

      expect(find.byType(ScanFxStatusNotice), findsNothing);

      _toInvalid(controller, 'This merchant code is not supported');
      await tester.pump();
      await _settle(tester, const Duration(milliseconds: 260));

      expect(find.byType(ScanFxStatusNotice), findsOneWidget);
      expect(find.text('This merchant code is not supported'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('shows the status notice on error too', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(controller: controller),
          ),
        ),
      );

      controller.start();
      controller.error('Could not read the code');
      await tester.pump();

      expect(find.byType(ScanFxStatusNotice), findsOneWidget);
      expect(find.text('Could not read the code'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('falls back to the invalid label when there is no copy', (
      tester,
    ) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(controller: controller),
          ),
        ),
      );

      _toInvalid(controller, '');
      await tester.pump();

      expect(
        find.text(QrScanFxTheme.bankingBlue.labels.invalid),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the retry affordance is wired to onRetry', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      var retries = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(
              controller: controller,
              onRetry: () => retries++,
            ),
          ),
        ),
      );

      _toInvalid(controller, 'Expired');
      await tester.pump();
      await _settle(tester, const Duration(milliseconds: 260));

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(retries, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('no retry button appears without onRetry', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(controller: controller),
          ),
        ),
      );

      _toInvalid(controller, 'Expired');
      await tester.pump();

      expect(find.text('Try again'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the confirmation seat appears only on success', (
      tester,
    ) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(
              controller: controller,
              confirmationBuilder: (BuildContext context) =>
                  const Text('Code captured'),
            ),
          ),
        ),
      );

      expect(find.text('Code captured'), findsNothing);

      controller.start();
      await tester.pump();
      expect(find.text('Code captured'), findsNothing);

      controller.success();
      await tester.pump();
      expect(find.text('Code captured'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the controls seat is always present', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(
              controller: controller,
              controlsBuilder: (BuildContext context) =>
                  const Text('Torch · Gallery'),
            ),
          ),
        ),
      );

      expect(find.text('Torch · Gallery'), findsOneWidget);

      controller.start();
      controller.success();
      await tester.pump();
      expect(find.text('Torch · Gallery'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('is large-text safe with a long message', (tester) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(
              controller: controller,
              onRetry: () {},
            ),
          ),
          textScale: 2.0,
        ),
      );

      _toInvalid(
        controller,
        'This payment code is not supported at this merchant, please try '
        'another code or ask the cashier for help.',
      );
      await tester.pump();
      await _settle(tester, const Duration(milliseconds: 260));

      // A RenderFlex overflow would surface here.
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the confirmation seat survives a 2.0 text scale', (
      tester,
    ) async {
      final controller = QrScanFxController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            height: 360,
            child: QrScanFx.banking(
              controller: controller,
              confirmationBuilder: (BuildContext context) => const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Code captured', textAlign: TextAlign.center),
              ),
            ),
          ),
          textScale: 2.0,
        ),
      );

      controller.start();
      controller.success();
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('ScanFxStatusNotice', () {
    testWidgets('prefers the message over the fallback', (tester) async {
      final message = ValueNotifier<String?>('Live message');
      addTearDown(message.dispose);

      await tester.pumpWidget(
        _host(
          ScanFxStatusNotice(message: message, fallback: 'Fallback'),
        ),
      );
      await _settle(tester, const Duration(milliseconds: 260));

      expect(find.text('Live message'), findsOneWidget);
      expect(find.text('Fallback'), findsNothing);
    });

    testWidgets('updates when the message changes without a state change', (
      tester,
    ) async {
      final message = ValueNotifier<String?>(null);
      addTearDown(message.dispose);

      await tester.pumpWidget(
        _host(
          ScanFxStatusNotice(message: message, fallback: 'Fallback'),
        ),
      );
      await tester.pump();
      expect(find.text('Fallback'), findsOneWidget);

      message.value = 'Arrived late';
      await tester.pump();
      expect(find.text('Arrived late'), findsOneWidget);
    });

    testWidgets('skips the entrance animation under reduced motion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final message = ValueNotifier<String?>('Nope');
      addTearDown(message.dispose);

      await tester.pumpWidget(
        _host(ScanFxStatusNotice(message: message)),
      );
      await tester.pump();

      // With no animation there is nothing to settle into: it is opaque at once.
      expect(find.text('Nope'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('banking contrast', () {
    test('overlay text and state colours clear 4.5:1', () {
      const banking = QrScanFxTheme.bankingBlue;

      expect(
        ScanFxPalette.contrastRatio(
          banking.hintTextColor,
          banking.hintBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'hint / status copy must stay readable',
      );
      for (final Color state in <Color>[
        banking.frameColor,
        banking.successColor,
        banking.errorColor,
        banking.invalidColor,
      ]) {
        expect(
          ScanFxPalette.contrastRatio(state, banking.backdropColor),
          greaterThanOrEqualTo(4.5),
          reason: '$state on the banking backdrop',
        );
      }
    });

    test('the default notice colours clear 4.5:1', () {
      const notice = ScanFxStatusNotice(
        message: _NeverNotifier(),
      );
      expect(
        ScanFxPalette.contrastRatio(
          notice.foregroundColor,
          notice.backgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}

/// A listenable that never fires, for constructing widgets in pure unit tests.
class _NeverNotifier implements ValueListenable<String?> {
  const _NeverNotifier();

  @override
  String? get value => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
