import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

/// Visual regression, done the way this package can actually afford to do it.
///
/// A committed byte-for-byte golden is a promise you can only keep on the exact
/// machine that generated it: the same `Picture` rasterises differently across
/// text engines, font stacks and GPU backends, so goldens generated on a
/// developer's laptop fail on CI for reasons that have nothing to do with the
/// overlay. What actually needs to be true is stronger *and* portable:
///
/// * every style draws something when it is supposed to;
/// * a style that claims to be a no-op really paints nothing;
/// * no two styles in a family render the same picture — which is what catches
///   a registry that routes two enum values at one implementation;
/// * every preset is a distinct look, and every preset survives reduce motion.
///
/// So this file rasterises the whole layer stack across a probe set of frames
/// and compares *derived* facts — ink coverage and a content hash — instead of
/// comparing to a stored image.
///
/// `tool/generate_screenshots.dart` is the other half: it renders the same
/// stacks into `screenshots/*.png` for the pub.dev page. Those are for humans.
/// These are the assertions.
const ui.Size _size = ui.Size(200, 200);

/// A quad that deliberately does not sit on the scan area, so the lock-on
/// flourish has somewhere to travel from and to.
final ui.Rect _detected = ui.Rect.fromLTWH(44, 48, 112, 112);

/// The flat background every render starts from. A layer that paints nothing
/// leaves exactly this behind, which is how "inert" is asserted.
const ui.Color _ground = ui.Color(0xFF202020);

/// One moment in the lifecycle worth looking at.
class _Probe {
  const _Probe(
    this.name,
    this.state,
    this.focus,
    this.feedback, {
    this.beamSpan = 0.5,
    this.dim = 1,
    this.pulse = 0.5,
  });

  final String name;
  final ScanFxState state;
  final double focus;
  final double feedback;
  final double beamSpan;
  final double dim;
  final double pulse;
}

/// The probe set. Between them, every layer finds a frame in which it is active:
/// the chrome draws while tracking, the reticle while the spring is in flight,
/// and the terminals are swept across their whole burst because a one-shot can
/// legitimately be blank at any single instant.
const List<_Probe> _probes = <_Probe>[
  _Probe('scanning', ScanFxState.scanning, 0, 0, pulse: 0, dim: 0),
  _Probe('detected-early', ScanFxState.detected, 0.25, 0.2),
  _Probe('detected', ScanFxState.detected, 0.6, 0.4, beamSpan: 0.2),
  _Probe('locked', ScanFxState.locked, 1, 0.6, pulse: 0.3),
  _Probe('success-early', ScanFxState.success, 1, 0.12, pulse: 0),
  _Probe('success-mid', ScanFxState.success, 1, 0.35, pulse: 0),
  _Probe('success-late', ScanFxState.success, 1, 0.62, pulse: 0),
  _Probe('success-end', ScanFxState.success, 1, 0.9, pulse: 0),
  _Probe('error-early', ScanFxState.error, 1, 0.12, pulse: 0),
  _Probe('error-mid', ScanFxState.error, 1, 0.34, pulse: 0),
  _Probe('error-late', ScanFxState.error, 1, 0.62, pulse: 0),
  _Probe('invalid-early', ScanFxState.invalid, 1, 0.12, pulse: 0),
  _Probe('invalid-mid', ScanFxState.invalid, 1, 0.4, pulse: 0),
  _Probe('invalid-late', ScanFxState.invalid, 1, 0.7, pulse: 0),
];

ScanFxFrame _frame(
  QrScanFxTheme theme,
  _Probe probe, {
  bool reduceMotion = false,
  double ambientSeconds = 0.37,
}) =>
    ScanFxFrame(
      size: _size,
      state: probe.state,
      theme: theme,
      frameShape: theme.frameShape,
      ambientSeconds: ambientSeconds,
      focus: probe.focus,
      focusRaw: probe.focus,
      beamSpan: probe.beamSpan,
      breath: 0.6,
      dim: probe.dim,
      feedback: probe.feedback,
      pulse: probe.pulse,
      hint: 1,
      reveal: 1,
      shake: ui.Offset.zero,
      quad: ScanFxQuad.fromRect(_detected),
      defaultQuad: ScanFxQuad.fromRect(_detected),
      lockedQuad: ScanFxQuad.fromRect(_detected),
      idleScale: 1,
      idleOffset: ui.Offset.zero,
      shimmer: 0.4,
      reduceMotion: reduceMotion,
      textDirection: ui.TextDirection.ltr,
      revision: 0,
    );

/// What one rasterisation produced.
typedef _Render = ({int hash, int ink});

/// A 32-bit FNV-1a over the RGBA buffer: portable, deterministic, and wide
/// enough that two different pictures colliding is not a thing that happens.
int _hash(Uint8List bytes) {
  var h = 2166136261;
  for (var i = 0; i < bytes.length; i++) {
    h ^= bytes[i];
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

Future<_Render> _renderStack(ScanLayerStack stack, ScanFxFrame frame) async {
  final int width = frame.size.width.toInt();
  final int height = frame.size.height.toInt();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(_ground, ui.BlendMode.src);
  for (final ScanLayerEntry entry in stack.entries) {
    if (!entry.visible) continue;
    entry.layer.paint(canvas, frame.size, frame);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  picture.dispose();
  image.dispose();

  final Uint8List bytes = data!.buffer.asUint8List();
  var ink = 0;
  const int g = 0x20;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] != g ||
        bytes[i + 1] != g ||
        bytes[i + 2] != g ||
        bytes[i + 3] != 0xFF) {
      ink++;
    }
  }
  return (hash: _hash(bytes), ink: ink);
}

/// The whole stack across every probe, folded into one portable signature.
Future<int> _signatureOf(
  ScanLayerStack stack,
  QrScanFxTheme theme, {
  bool reduceMotion = false,
}) async {
  var folded = 2166136261;
  for (final _Probe probe in _probes) {
    final _Render r = await _renderStack(
      stack,
      _frame(theme, probe, reduceMotion: reduceMotion),
    );
    folded = (folded ^ r.hash) * 16777619 & 0xFFFFFFFF;
  }
  return folded;
}

Future<int> _signature(QrScanFxTheme theme) =>
    _signatureOf(ScanFxRegistry.buildStack(theme), theme);

/// Ink per probe for one layer rendered on its own, so "this style draws" can
/// be asserted without the rest of the stack masking it.
Future<int> _singleLayerInk(ScanLayer layer, QrScanFxTheme theme) async {
  var total = 0;
  for (final _Probe probe in _probes) {
    final _Render r = await _renderStack(
      ScanLayerStack.of(<ScanLayer>[layer]),
      _frame(theme, probe),
    );
    total += r.ink;
  }
  return total;
}

/// Every layer hidden — the control that proves the ink counter is honest.
ScanLayerStack _emptyStack(QrScanFxTheme theme) => ScanFxRegistry.buildStack(
      theme,
    )
        .hide(ScanLayerKind.backdrop)
        .hide(ScanLayerKind.frame)
        .hide(ScanLayerKind.corners)
        .hide(ScanLayerKind.beam)
        .hide(ScanLayerKind.reticle)
        .hide(ScanLayerKind.success)
        .hide(ScanLayerKind.error)
        .hide(ScanLayerKind.hint);

void main() {
  test('hiding every layer paints nothing but the ground', () async {
    final theme = QrScanFxTheme.dark;
    final stack = _emptyStack(theme);
    for (final _Probe probe in _probes) {
      final _Render r = await _renderStack(stack, _frame(theme, probe));
      expect(r.ink, 0, reason: '${probe.name} should be blank');
    }
  });

  /// Asserts the whole contract for one style family.
  ///
  /// [vary] swaps one family's style. [noop], if given, must be the value that
  /// draws nothing — and [noopKind] is the layer it stands in for, so "declared
  /// inert" can be checked against "actually removed".
  Future<void> family<T extends Enum>({
    required String name,
    required List<T> values,
    required QrScanFxTheme Function(QrScanFxTheme, T) vary,
    required ScanLayer Function(T) layer,
    T? noop,
    ScanLayerKind? noopKind,
  }) async {
    test(name, () async {
      final Map<T, int> signatures = <T, int>{};
      final Map<T, int> inks = <T, int>{};

      for (final T value in values) {
        final QrScanFxTheme theme = vary(QrScanFxTheme.dark, value);
        signatures[value] = await _signatureOf(
          ScanFxRegistry.buildStack(theme),
          theme,
        );
        inks[value] = await _singleLayerInk(layer(value), theme);
      }

      for (final T value in values) {
        if (value == noop) {
          expect(
            inks[value],
            0,
            reason: '$name: $value claims to be inert but painted something',
          );
        } else {
          expect(
            inks[value],
            greaterThan(0),
            reason: '$name: $value never painted anything in any state',
          );
        }
      }

      if (noop != null && noopKind != null) {
        // "Draws nothing" and "is not there" have to produce the same picture.
        final int removed = await _signatureOf(
          ScanFxRegistry.buildStack(QrScanFxTheme.dark).remove(noopKind),
          vary(QrScanFxTheme.dark, noop),
        );
        expect(
          signatures[noop],
          removed,
          reason: '$name: $noop is not truly the same as omitting the layer',
        );
      }

      final Map<int, T> seen = <int, T>{};
      for (final T value in values) {
        expect(
          seen.containsKey(signatures[value]),
          isFalse,
          reason:
              '$name: $value renders identically to ${seen[signatures[value]]}',
        );
        seen[signatures[value]!] = value;
      }
    });
  }

  group('every style family', () {
    family<ScanFrameShape>(
      name: 'frame shapes draw and are all distinct',
      values: ScanFrameShape.values,
      vary: (QrScanFxTheme t, ScanFrameShape v) => t.copyWith(frameShape: v),
      layer: (v) => ScanFxRegistry.frame(v),
    );

    family<ScanCornerStyle>(
      name: 'corner styles draw and are all distinct',
      values: ScanCornerStyle.values,
      vary: (QrScanFxTheme t, ScanCornerStyle v) => t.copyWith(cornerStyle: v),
      layer: (v) => ScanFxRegistry.corners(v),
    );

    family<ScanBeamStyle>(
      name: 'beam styles draw and are all distinct',
      values: ScanBeamStyle.values,
      vary: (QrScanFxTheme t, ScanBeamStyle v) => t.copyWith(beamStyle: v),
      layer: (v) => ScanFxRegistry.beam(v),
      noop: ScanBeamStyle.none,
      noopKind: ScanLayerKind.beam,
    );

    family<ScanBackdropStyle>(
      name: 'backdrop styles draw and are all distinct',
      values: ScanBackdropStyle.values,
      vary: (QrScanFxTheme t, ScanBackdropStyle v) =>
          t.copyWith(backdropStyle: v),
      layer: (v) => ScanFxRegistry.backdrop(v),
      noop: ScanBackdropStyle.none,
      noopKind: ScanLayerKind.backdrop,
    );

    family<ScanLockStyle>(
      name: 'lock-on styles draw and are all distinct',
      values: ScanLockStyle.values,
      vary: (QrScanFxTheme t, ScanLockStyle v) => t.copyWith(lockStyle: v),
      layer: (v) => ScanFxRegistry.reticle(v),
      noop: ScanLockStyle.none,
      noopKind: ScanLayerKind.reticle,
    );

    family<ScanSuccessStyle>(
      name: 'success styles draw and are all distinct',
      values: ScanSuccessStyle.values,
      vary: (QrScanFxTheme t, ScanSuccessStyle v) =>
          t.copyWith(successStyle: v),
      layer: (v) => ScanFxRegistry.success(v),
      noop: ScanSuccessStyle.none,
      noopKind: ScanLayerKind.success,
    );

    family<ScanErrorStyle>(
      name: 'fault styles draw and are all distinct',
      values: ScanErrorStyle.values,
      vary: (QrScanFxTheme t, ScanErrorStyle v) => t.copyWith(errorStyle: v),
      layer: (v) => ScanFxRegistry.error(v),
      noop: ScanErrorStyle.none,
      noopKind: ScanLayerKind.error,
    );
  });

  group('idle motion', () {
    test('every idle style produces a distinct, finite transform', () {
      final Map<ScanIdleStyle, ScanFxIdleTransform> transforms =
          <ScanIdleStyle, ScanFxIdleTransform>{
        for (final ScanIdleStyle style in ScanIdleStyle.values)
          style: ScanFxRegistry.idleModifier(style).transform(0.37),
      };

      for (final MapEntry<ScanIdleStyle, ScanFxIdleTransform> e
          in transforms.entries) {
        expect(e.value.scale.isFinite, isTrue, reason: '${e.key} scale');
        expect(e.value.offset.dx.isFinite, isTrue, reason: '${e.key} dx');
        expect(e.value.offset.dy.isFinite, isTrue, reason: '${e.key} dy');
        expect(e.value.shimmer.isFinite, isTrue, reason: '${e.key} shimmer');
      }

      final ScanFxIdleTransform still = transforms[ScanIdleStyle.still]!;
      expect(still.scale, 0);
      expect(still.offset, ui.Offset.zero);
      expect(still.shimmer, 0);

      final Map<String, ScanIdleStyle> seen = <String, ScanIdleStyle>{};
      for (final MapEntry<ScanIdleStyle, ScanFxIdleTransform> e
          in transforms.entries) {
        final String key = '${e.value.scale}|${e.value.offset}';
        expect(
          seen.containsKey(key),
          isFalse,
          reason: '${e.key} is identical to ${seen[key]}',
        );
        seen[key] = e.key;
      }
    });

    test('idle motion stays bounded over a long run', () {
      for (final ScanIdleStyle style in ScanIdleStyle.values) {
        final ScanFxIdleModifier modifier = ScanFxRegistry.idleModifier(style);
        for (double t = 0; t < 20; t += 0.37) {
          final ScanFxIdleTransform transform = modifier.transform(t);
          expect(transform.scale.abs(), lessThan(0.5), reason: '$style @ $t');
          expect(
            transform.offset.distance,
            lessThan(40),
            reason: '$style @ $t',
          );
          expect(
            transform.shimmer,
            inInclusiveRange(-0.001, 1.001),
            reason: '$style @ $t',
          );
        }
      }
    });
  });

  group('presets', () {
    const Map<String, QrScanFxTheme> named = <String, QrScanFxTheme>{
      'dark': QrScanFxTheme.dark,
      'light': QrScanFxTheme.light,
      'bankingBlue': QrScanFxTheme.bankingBlue,
      'aurora': QrScanFxTheme.aurora,
      'neonCyber': QrScanFxTheme.neonCyber,
      'monoGlass': QrScanFxTheme.monoGlass,
      'sunsetGradient': QrScanFxTheme.sunsetGradient,
      'oceanDeep': QrScanFxTheme.oceanDeep,
      'matrixGreen': QrScanFxTheme.matrixGreen,
      'roseGold': QrScanFxTheme.roseGold,
      'midnightPurple': QrScanFxTheme.midnightPurple,
      'cleanWhite': QrScanFxTheme.cleanWhite,
      'highContrast': QrScanFxTheme.highContrast,
      'minimalLight': QrScanFxTheme.minimalLight,
    };

    Future<int> _stackInk(QrScanFxTheme theme) async {
      var total = 0;
      for (final _Probe probe in _probes) {
        total += (await _renderStack(
          ScanFxRegistry.buildStack(theme),
          _frame(theme, probe),
        ))
            .ink;
      }
      return total;
    }

    test('every recipe renders, and no two look alike', () async {
      final Map<String, int> signatures = <String, int>{};
      for (final ScanPreset preset in ScanPreset.values) {
        final QrScanFxTheme theme = ScanFxRecipes.theme(preset);
        expect(await _stackInk(theme), greaterThan(0),
            reason: '${preset.name} drew nothing');
        signatures[preset.name] = await _signature(theme);
      }

      final Map<int, String> seen = <int, String>{};
      for (final MapEntry<String, int> e in signatures.entries) {
        expect(seen.containsKey(e.value), isFalse,
            reason: '${e.key} looks identical to ${seen[e.value]}');
        seen[e.value] = e.key;
      }
    });

    test('every named theme renders, and no two look alike', () async {
      final Map<String, int> signatures = <String, int>{};
      for (final MapEntry<String, QrScanFxTheme> e in named.entries) {
        expect(await _stackInk(e.value), greaterThan(0),
            reason: '${e.key} drew nothing');
        signatures[e.key] = await _signature(e.value);
      }

      final Map<int, String> seen = <int, String>{};
      for (final MapEntry<String, int> e in signatures.entries) {
        expect(seen.containsKey(e.value), isFalse,
            reason: '${e.key} looks identical to ${seen[e.value]}');
        seen[e.value] = e.key;
      }
    });

    test('every theme survives reduce motion, in every state', () async {
      for (final MapEntry<String, QrScanFxTheme> e in named.entries) {
        for (final _Probe probe in _probes) {
          final _Render r = await _renderStack(
            ScanFxRegistry.buildStack(e.value),
            _frame(e.value, probe, reduceMotion: true),
          );
          expect(r.ink, greaterThan(0),
              reason:
                  '${e.key} drew nothing at ${probe.name} under reduce motion');
        }
      }
    });
  });
  });
}
