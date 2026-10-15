import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx_example/payment/khqr.dart';
import 'package:qr_scan_fx_example/payment/payment_models.dart';
import 'package:qr_scan_fx_example/payment/receipt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

PaymentReceipt _receipt({
  required String id,
  PaymentCurrency currency = PaymentCurrency.usd,
  double amount = 12.5,
  BankAccount? account,
}) =>
    PaymentReceipt(
      id: id,
      payee: 'Phnom Penh Coffee',
      amount: amount,
      currency: currency,
      account: account ?? kDemoAccounts.first,
      createdAt: DateTime(2026, 10, 15, 14, 32),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('starts empty', () async {
    expect(await ReceiptStore.load(), isEmpty);
  });

  test('stores a receipt and reads it back', () async {
    await ReceiptStore.add(_receipt(id: 'TXN-1'));
    final List<PaymentReceipt> loaded = await ReceiptStore.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'TXN-1');
    expect(loaded.single.payee, 'Phnom Penh Coffee');
    expect(loaded.single.amount, 12.5);
    expect(loaded.single.currency, PaymentCurrency.usd);
    expect(loaded.single.createdAt, DateTime(2026, 10, 15, 14, 32));
    expect(loaded.single.account.id, kDemoAccounts.first.id);
  });

  test('round-trips a riel receipt', () async {
    await ReceiptStore.add(
      _receipt(
        id: 'TXN-2',
        currency: PaymentCurrency.khr,
        amount: 51000,
        account: kDemoAccounts.last,
      ),
    );
    final PaymentReceipt loaded = (await ReceiptStore.load()).single;
    expect(loaded.currency, PaymentCurrency.khr);
    expect(loaded.amount, 51000);
    expect(loaded.account.currency, PaymentCurrency.khr);
  });

  test('keeps the newest first', () async {
    await ReceiptStore.add(_receipt(id: 'TXN-1'));
    await ReceiptStore.add(_receipt(id: 'TXN-2'));
    final List<PaymentReceipt> loaded = await ReceiptStore.load();
    expect(
      loaded.map((PaymentReceipt r) => r.id).toList(),
      <String>['TXN-2', 'TXN-1'],
    );
  });

  test('trims to the maximum number of entries', () async {
    for (int i = 0; i < ReceiptStore.maxEntries + 5; i++) {
      await ReceiptStore.add(_receipt(id: 'TXN-$i'));
    }
    final List<PaymentReceipt> loaded = await ReceiptStore.load();
    expect(loaded, hasLength(ReceiptStore.maxEntries));
    // The most recent add is at the front; the oldest were dropped.
    expect(loaded.first.id, 'TXN-${ReceiptStore.maxEntries + 4}');
    expect(
      loaded.map((PaymentReceipt r) => r.id),
      isNot(contains('TXN-0')),
    );
  });

  test('clear empties the history', () async {
    await ReceiptStore.add(_receipt(id: 'TXN-1'));
    await ReceiptStore.clear();
    expect(await ReceiptStore.load(), isEmpty);
  });

  test('a corrupt value decodes as empty rather than throwing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'qr_scan_fx.receipts': 'not json',
    });
    expect(await ReceiptStore.load(), isEmpty);
  });
}
