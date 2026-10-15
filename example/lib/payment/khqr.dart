// Host-side parsing of a KHQR / EMVCo payment code.
//
// This file lives in the *example*, never in the package. `qr_scan_fx` is a
// renderer: it receives geometry and returns pixels, and has no API that could
// accept the payload this parser reads. The host decodes; the overlay draws.
//
// KHQR is an EMVCo-compliant payload: a flat list of (2-digit tag, 2-digit
// length, value) records. We only read the handful of tags a payment screen
// needs — currency (53), amount (54) and merchant name (59) — and bail out on
// anything that is not EMVCo, such as a plain URL.

import 'package:flutter/foundation.dart';

/// The currencies this demo understands.
enum PaymentCurrency {
  /// United States dollar — the settlement currency most KHQR codes use.
  usd,

  /// Cambodian riel.
  khr,
}

/// Display and conversion helpers for [PaymentCurrency].
extension PaymentCurrencyX on PaymentCurrency {
  /// The ISO-4217 code, e.g. `USD`.
  String get code => switch (this) {
        PaymentCurrency.usd => 'USD',
        PaymentCurrency.khr => 'KHR',
      };

  /// The symbol shown next to an amount.
  String get symbol => switch (this) {
        PaymentCurrency.usd => r'$',
        PaymentCurrency.khr => '៛',
      };

  /// The EMVCo currency code carried in tag 53.
  String get emvCode => switch (this) {
        PaymentCurrency.usd => '840',
        PaymentCurrency.khr => '116',
      };

  /// Whether amounts in this currency are shown with two decimals.
  bool get hasDecimals => this == PaymentCurrency.usd;
}

/// The fixed demo exchange rate: 1 USD = 4,100 KHR.
///
/// A real app takes this from a rate service; a fixed value keeps the demo
/// deterministic and is honest about being an example.
const double khrPerUsd = 4100;

/// A KHQR code the host has decoded and parsed, expressed in *typed* fields.
///
/// Nothing here is rendered by `qr_scan_fx`; it is the example app's own model.
@immutable
class KhqrData {
  /// Creates parsed KHQR fields.
  const KhqrData({
    this.merchantName,
    this.merchantCity,
    this.countryCode,
    this.currency,
    this.amount,
  });

  /// The merchant name (tag 59), when present.
  final String? merchantName;

  /// The merchant city (tag 60), when present.
  final String? merchantCity;

  /// The ISO-3166 country code (tag 58), when present.
  final String? countryCode;

  /// The currency (tag 53), when it is one this demo knows.
  final PaymentCurrency? currency;

  /// The amount embedded in the code (tag 54), when present.
  ///
  /// A `null` amount is a *dynamic* code: the payer enters the amount.
  final double? amount;

  /// Whether the code already carries an amount.
  bool get hasAmount => amount != null && amount! > 0;
}

/// Parses EMVCo / KHQR payloads. Returns `null` for anything else.
abstract final class KhqrParser {
  /// Parses [payload] into typed fields, or returns `null` when it is not a
  /// well-formed EMVCo / KHQR string.
  static KhqrData? parse(String payload) {
    final Map<String, String> fields = _readTlv(payload);
    if (fields.isEmpty) return null;
    // EMVCo payload format indicator. Its absence means "not a payment code".
    if (fields['00'] != '01') return null;

    return KhqrData(
      merchantName: _clean(fields['59']),
      merchantCity: _clean(fields['60']),
      countryCode: _clean(fields['58']),
      currency: _currency(fields['53']),
      amount: double.tryParse(fields['54'] ?? ''),
    );
  }

  /// Reads one level of (tag, length, value) records.
  ///
  /// Malformed input ends the scan rather than throwing: a scanner must never
  /// crash on a crafted or truncated code.
  static Map<String, String> _readTlv(String payload) {
    final Map<String, String> out = <String, String>{};
    int i = 0;
    while (i + 4 <= payload.length) {
      final String tag = payload.substring(i, i + 2);
      final int? length = int.tryParse(payload.substring(i + 2, i + 4));
      if (length == null) break;
      final int start = i + 4;
      final int end = start + length;
      if (end > payload.length) break;
      out[tag] = payload.substring(start, end);
      i = end;
    }
    return out;
  }

  static PaymentCurrency? _currency(String? code) => switch (code) {
        '840' => PaymentCurrency.usd,
        '116' => PaymentCurrency.khr,
        _ => null,
      };

  static String? _clean(String? value) {
    final String? trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// Maps a stored currency name back to a [PaymentCurrency].
///
/// Used when rebuilding a receipt from the local history; anything unknown
/// falls back to dollars.
PaymentCurrency paymentCurrencyFromName(String? name) => switch (name) {
      'khr' => PaymentCurrency.khr,
      _ => PaymentCurrency.usd,
    };

/// Converts [amount] between the two supported currencies at [khrPerUsd].
double convertCurrency(
    double amount, PaymentCurrency from, PaymentCurrency to) {
  if (from == to) return amount;
  return from == PaymentCurrency.usd ? amount * khrPerUsd : amount / khrPerUsd;
}

/// Formats [amount] for display, with thousands separators and no `intl`
/// dependency.
///
/// KHR is rounded to the nearest 100 riel (the smallest note in everyday use)
/// and shown without decimals; USD keeps two.
String formatMoney(double amount, PaymentCurrency currency) {
  if (currency.hasDecimals) {
    final String fixed = amount.toStringAsFixed(2);
    final int dot = fixed.indexOf('.');
    return '${currency.symbol} ${_group(fixed.substring(0, dot))}${fixed.substring(dot)}';
  }
  final int rounded = (amount / 100).round() * 100;
  return '${currency.symbol} ${_group(rounded.toString())}';
}

String _group(String digits) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
