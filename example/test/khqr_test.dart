import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_fx_example/payment/khqr.dart';

void main() {
  group('KhqrParser', () {
    // A well-formed static KHQR: format indicator, USD, an amount, a merchant.
    const String usdPayload =
        '0002010102125303840540512.505802KH5917Phnom Penh Coffee6010Phnom Penh6304ABCD';

    test('reads merchant, country, currency and amount', () {
      final KhqrData parsed = KhqrParser.parse(usdPayload)!;
      expect(parsed.merchantName, 'Phnom Penh Coffee');
      expect(parsed.merchantCity, 'Phnom Penh');
      expect(parsed.countryCode, 'KH');
      expect(parsed.currency, PaymentCurrency.usd);
      expect(parsed.amount, 12.50);
      expect(parsed.hasAmount, isTrue);
    });

    test('reads riel currency', () {
      const String khrPayload =
          '0002010102125303116540512.505802KH5917Phnom Penh Coffee6010Phnom Penh6304ABCD';
      expect(KhqrParser.parse(khrPayload)!.currency, PaymentCurrency.khr);
    });

    test('a dynamic code carries no amount', () {
      const String dynamicPayload =
          '00020101021153038405802KH5917Phnom Penh Coffee6010Phnom Penh6304ABCD';
      final KhqrData parsed = KhqrParser.parse(dynamicPayload)!;
      expect(parsed.amount, isNull);
      expect(parsed.hasAmount, isFalse);
    });

    test('rejects a plain URL', () {
      expect(KhqrParser.parse('https://example.com/pay'), isNull);
    });

    test('rejects a payload whose format indicator is not 01', () {
      expect(KhqrParser.parse('0002AB'), isNull);
    });

    test('never throws on a truncated payload', () {
      expect(KhqrParser.parse('00020101'), isNotNull);
      expect(KhqrParser.parse('00'), isNull);
    });
  });

  group('money', () {
    test('formats USD with two decimals and grouping', () {
      expect(formatMoney(1234.5, PaymentCurrency.usd), r'$ 1,234.50');
    });

    test('formats KHR without decimals, rounded to the nearest 100', () {
      expect(formatMoney(51250, PaymentCurrency.khr), '៛ 51,300');
    });

    test('converts USD to KHR at the fixed rate', () {
      expect(
        convertCurrency(12.5, PaymentCurrency.usd, PaymentCurrency.khr),
        51250,
      );
    });

    test('converts KHR back to USD', () {
      expect(
        convertCurrency(51250, PaymentCurrency.khr, PaymentCurrency.usd),
        12.5,
      );
    });
  });
}
