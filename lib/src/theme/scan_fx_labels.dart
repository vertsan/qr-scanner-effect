import 'package:flutter/foundation.dart' show immutable;

import '../state/scan_fx_state.dart';

/// The screen-reader strings the overlay announces.
///
/// Labels live in the theme rather than in the painters so host apps can
/// localise them and so banking mode can guarantee neutral wording ("Code
/// scanned", never "Payment successful").
@immutable
class ScanFxSemanticsLabels {
  /// Creates a set of labels.
  const ScanFxSemanticsLabels({
    this.idle = 'Scanner ready',
    this.scanning = 'Scanning',
    this.detected = 'Code detected',
    this.locked = 'Code detected',
    this.success = 'Code scanned',
    this.error = 'Could not scan code',
    this.invalid = 'Invalid code',
    this.tapToStart = 'Tap to start scanning',
  });

  /// Announced in [ScanFxState.idle].
  final String idle;

  /// Announced in [ScanFxState.scanning].
  final String scanning;

  /// Announced in [ScanFxState.detected].
  final String detected;

  /// Announced in [ScanFxState.locked].
  final String locked;

  /// Announced in [ScanFxState.success].
  ///
  /// Banking mode deliberately phrases this as a *read* result, never a payment
  /// result.
  final String success;

  /// Announced in [ScanFxState.error].
  final String error;

  /// Announced in [ScanFxState.invalid].
  final String invalid;

  /// Hint shown when the scanner is idle.
  final String tapToStart;

  /// The label for [state].
  String labelFor(ScanFxState state) => switch (state) {
        ScanFxState.idle => idle,
        ScanFxState.scanning => scanning,
        ScanFxState.detected => detected,
        ScanFxState.locked => locked,
        ScanFxState.success => success,
        ScanFxState.error => error,
        ScanFxState.invalid => invalid,
      };

  /// Copy with overrides.
  ScanFxSemanticsLabels copyWith({
    String? idle,
    String? scanning,
    String? detected,
    String? locked,
    String? success,
    String? error,
    String? invalid,
    String? tapToStart,
  }) =>
      ScanFxSemanticsLabels(
        idle: idle ?? this.idle,
        scanning: scanning ?? this.scanning,
        detected: detected ?? this.detected,
        locked: locked ?? this.locked,
        success: success ?? this.success,
        error: error ?? this.error,
        invalid: invalid ?? this.invalid,
        tapToStart: tapToStart ?? this.tapToStart,
      );

  @override
  bool operator ==(Object other) =>
      other is ScanFxSemanticsLabels &&
      other.idle == idle &&
      other.scanning == scanning &&
      other.detected == detected &&
      other.locked == locked &&
      other.success == success &&
      other.error == error &&
      other.invalid == invalid &&
      other.tapToStart == tapToStart;

  @override
  int get hashCode => Object.hash(
        idle,
        scanning,
        detected,
        locked,
        success,
        error,
        invalid,
        tapToStart,
      );
}
