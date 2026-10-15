// A tiny persisted history of confirmed payments.
//
// A real app keeps this in its own store; the example uses
// `shared_preferences` because it is the smallest thing that survives a
// restart. It is still host-side: the overlay never sees a receipt.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'payment_models.dart';

/// Persists the most recent receipts as a JSON list under one key.
abstract final class ReceiptStore {
  /// The preference key the encoded list lives under.
  static const String _key = 'qr_scan_fx.receipts';

  /// How many receipts to keep before the oldest are dropped.
  static const int maxEntries = 20;

  /// Loads the stored receipts, newest first.
  static Future<List<PaymentReceipt>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <PaymentReceipt>[];
    return _decode(raw);
  }

  /// Puts [receipt] at the front of the history, trimming to [maxEntries].
  ///
  /// Returns the stored list, newest first.
  static Future<List<PaymentReceipt>> add(PaymentReceipt receipt) async {
    final List<PaymentReceipt> receipts = await load();
    final List<PaymentReceipt> next = <PaymentReceipt>[receipt, ...receipts];
    final List<PaymentReceipt> trimmed =
        next.length > maxEntries ? next.sublist(0, maxEntries) : next;
    await _write(trimmed);
    return trimmed;
  }

  /// Removes every stored receipt.
  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _write(List<PaymentReceipt> receipts) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(
      receipts.map((PaymentReceipt r) => r.toJson()).toList(),
    );
    await prefs.setString(_key, raw);
  }

  static List<PaymentReceipt> _decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <PaymentReceipt>[];
      return decoded
          .whereType<Map<String, Object?>>()
          .map(PaymentReceipt.fromJson)
          .toList();
    } on FormatException {
      // A corrupt value must never take the app down; treat it as empty.
      return <PaymentReceipt>[];
    }
  }
}
