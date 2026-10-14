import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

void main() {
  group('ScanFxStateMachine', () {
    test('starts idle and reaches locked through the hold window', () {
      final machine = ScanFxStateMachine();
      expect(machine.state, ScanFxState.idle);

      expect(machine.fire(ScanFxTrigger.start), ScanFxState.scanning);
      expect(machine.fire(ScanFxTrigger.targetDetected), ScanFxState.detected);
      expect(machine.fire(ScanFxTrigger.lockHoldElapsed), ScanFxState.locked);
    });

    test('a repeated detection does not restart or leave `detected`', () {
      final machine = ScanFxStateMachine()
        ..fire(ScanFxTrigger.start)
        ..fire(ScanFxTrigger.targetDetected);
      expect(machine.state, ScanFxState.detected);

      // A 30 fps detector fires this many times before the hold elapses. If any
      // of them re-entered `detected`, the hold would restart and the lock-on
      // animation would never complete.
      for (var i = 0; i < 50; i++) {
        expect(machine.canFire(ScanFxTrigger.targetDetected), isFalse);
        expect(
            machine.fire(ScanFxTrigger.targetDetected), ScanFxState.detected);
      }

      expect(machine.fire(ScanFxTrigger.lockHoldElapsed), ScanFxState.locked);

      // A target that moves while locked keeps the lock.
      expect(machine.fire(ScanFxTrigger.targetDetected), ScanFxState.locked);
      expect(machine.fire(ScanFxTrigger.lockHoldElapsed), ScanFxState.locked);
    });

    test('autoLock: false keeps `detected` sticky', () {
      final machine = ScanFxStateMachine(autoLock: false)
        ..fire(ScanFxTrigger.start)
        ..fire(ScanFxTrigger.targetDetected);
      expect(machine.fire(ScanFxTrigger.lockHoldElapsed), ScanFxState.detected);
      expect(machine.fire(ScanFxTrigger.succeed), ScanFxState.success);
    });

    test('terminal states are reachable from every tracked state', () {
      for (final from in <ScanFxState>[
        ScanFxState.scanning,
        ScanFxState.detected,
        ScanFxState.locked,
      ]) {
        for (final trigger in <ScanFxTrigger>[
          ScanFxTrigger.succeed,
          ScanFxTrigger.fail,
          ScanFxTrigger.invalidate,
        ]) {
          expect(
            ScanFxStateMachine.resolveTransition(from, trigger),
            isNotNull,
            reason: '$from + $trigger',
          );
        }
      }
    });

    test('idle ignores terminal triggers', () {
      for (final trigger in <ScanFxTrigger>[
        ScanFxTrigger.succeed,
        ScanFxTrigger.fail,
        ScanFxTrigger.invalidate,
        ScanFxTrigger.lockHoldElapsed,
      ]) {
        expect(
          ScanFxStateMachine.resolveTransition(ScanFxState.idle, trigger),
          isNull,
          reason: 'idle + $trigger',
        );
      }
    });

    test('reset returns to scanning from every non-idle state', () {
      for (final from in ScanFxState.values) {
        final next = ScanFxStateMachine.resolveTransition(
          from,
          ScanFxTrigger.reset,
        );
        expect(
          next,
          from == ScanFxState.idle ? ScanFxState.idle : ScanFxState.scanning,
          reason: '$from + reset',
        );
      }
    });

    test('a fresh target after a burst restarts the cycle', () {
      for (final from in <ScanFxState>[
        ScanFxState.success,
        ScanFxState.error,
        ScanFxState.invalid,
      ]) {
        expect(
          ScanFxStateMachine.resolveTransition(
            from,
            ScanFxTrigger.targetDetected,
          ),
          ScanFxState.detected,
          reason: '$from + targetDetected',
        );
      }
    });

    test('resolve never commits and fire always does', () {
      final machine = ScanFxStateMachine();
      expect(machine.resolve(ScanFxTrigger.start), ScanFxState.scanning);
      expect(machine.state, ScanFxState.idle);
      machine.fire(ScanFxTrigger.start);
      expect(machine.state, ScanFxState.scanning);
    });

    test('jumpTo bypasses the table', () {
      final machine = ScanFxStateMachine();
      machine.jumpTo(ScanFxState.locked);
      expect(machine.state, ScanFxState.locked);
    });
  });
}
