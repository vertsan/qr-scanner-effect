// The host-side data the payment flow moves between screens.
//
// None of this is part of the package. `qr_scan_fx` never sees a payee, an
// amount or an account: the example app decides what a code means and keeps
// that meaning to itself.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'khqr.dart';

/// A funding account the payer can choose from.
@immutable
class BankAccount {
  /// Creates a funding account.
  const BankAccount({
    required this.id,
    required this.label,
    required this.currency,
    this.maskedNumber,
  });

  /// A stable identifier (a real app uses its own account id).
  final String id;

  /// The human label, e.g. `Everyday account`.
  final String label;

  /// The currency this account settles in.
  final PaymentCurrency currency;

  /// The last few digits, already masked for display.
  final String? maskedNumber;

  /// Serialises this account for the local history.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'currency': currency.name,
        'maskedNumber': maskedNumber,
      };

  /// Rebuilds an account from [json].
  factory BankAccount.fromJson(Map<String, Object?> json) => BankAccount(
        id: json['id']! as String,
        label: json['label']! as String,
        currency: paymentCurrencyFromName(json['currency'] as String?),
        maskedNumber: json['maskedNumber'] as String?,
      );
}

/// Stand-in accounts a host would normally load from its backend.
const List<BankAccount> kDemoAccounts = <BankAccount>[
  BankAccount(
    id: 'usd-everyday',
    label: 'Everyday account',
    currency: PaymentCurrency.usd,
    maskedNumber: '•• 4821',
  ),
  BankAccount(
    id: 'usd-savings',
    label: 'Savings',
    currency: PaymentCurrency.usd,
    maskedNumber: '•• 7730',
  ),
  BankAccount(
    id: 'khr-wallet',
    label: 'Riel wallet',
    currency: PaymentCurrency.khr,
    maskedNumber: '•• 2210',
  ),
];

/// What the host hands the confirmation screen, after its own validation.
///
/// The package never builds one of these; the host does, from the payload it
/// (and only it) decoded.
@immutable
class PaymentRequest {
  /// Creates a payment request.
  const PaymentRequest({
    required this.payee,
    required this.currency,
    this.amount,
    this.city,
    this.verified = false,
  });

  /// Builds a request from a parsed KHQR code.
  factory PaymentRequest.fromKhqr(KhqrData data) => PaymentRequest(
        payee: data.merchantName ?? 'Unverified merchant',
        currency: data.currency ?? PaymentCurrency.usd,
        amount: data.amount,
        city: data.merchantCity,
        verified: data.merchantName != null,
      );

  /// The payee shown to the payer.
  final String payee;

  /// The currency the code settles in.
  final PaymentCurrency currency;

  /// The amount embedded in the code, if the code is *static*.
  final double? amount;

  /// The merchant city, when the code carried one.
  final String? city;

  /// Whether the host recognised the merchant (its own verdict, not the code's).
  final bool verified;

  /// Whether the code already carried a positive amount.
  bool get hasAmount => amount != null && amount! > 0;
}

/// The immutable record of a confirmed payment — the receipt.
@immutable
class PaymentReceipt {
  /// Creates a receipt.
  const PaymentReceipt({
    required this.id,
    required this.payee,
    required this.amount,
    required this.currency,
    required this.account,
    required this.createdAt,
  });

  /// The transaction reference.
  final String id;

  /// The payee.
  final String payee;

  /// The amount, expressed in [currency].
  final double amount;

  /// The currency the payer settled in.
  final PaymentCurrency currency;

  /// The account the money came from.
  final BankAccount account;

  /// When the host confirmed the payment.
  final DateTime createdAt;

  /// Serialises this receipt for the local history.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'payee': payee,
        'amount': amount,
        'currency': currency.name,
        'account': account.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  /// Rebuilds a receipt from [json].
  factory PaymentReceipt.fromJson(Map<String, Object?> json) => PaymentReceipt(
        id: json['id']! as String,
        payee: json['payee']! as String,
        amount: (json['amount']! as num).toDouble(),
        currency: paymentCurrencyFromName(json['currency'] as String?),
        account: BankAccount.fromJson(json['account']! as Map<String, Object?>),
        createdAt: DateTime.parse(json['createdAt']! as String),
      );

  /// The other currency, for the `≈` line.
  PaymentCurrency get otherCurrency =>
      currency == PaymentCurrency.usd ? PaymentCurrency.khr : PaymentCurrency.usd;

  /// [amount] converted to [otherCurrency].
  double get otherAmount => convertCurrency(amount, currency, otherCurrency);

  /// A fresh, plausible transaction id. Demo only — a real app takes this from
  /// its backend.
  static String newId([math.Random? random]) {
    final math.Random rng = random ?? math.Random();
    const String alphabet = '0123456789ABCDEF';
    final String suffix =
        List<String>.generate(6, (int _) => alphabet[rng.nextInt(alphabet.length)]).join();
    final DateTime now = DateTime.now();
    return 'TXN-${now.year}${_pad(now.month)}${_pad(now.day)}-$suffix';
  }
}

/// A stable `yyyy-MM-dd HH:mm` timestamp for receipts.
String formatTimestamp(DateTime time) {
  final String date = '${time.year}-${_pad(time.month)}-${_pad(time.day)}';
  final String clock = '${_pad(time.hour)}:${_pad(time.minute)}';
  return '$date $clock';
}

String _pad(int value) => value.toString().padLeft(2, '0');
