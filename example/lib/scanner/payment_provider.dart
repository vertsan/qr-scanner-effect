// The payment methods the scanner screen advertises.
//
// Honesty note, because this file is easy to misread:
//
// * This app performs **no** payment integration. It reads KHQR — Cambodia's
//   EMVCo-compliant QR standard — and stops there. There is no SDK for, and no
//   settlement with, any of the networks below.
// * They are listed because a KHQR code issued by any of them is exactly what
//   `payment/khqr.dart` already reads, and because this repository's own demo
//   (`lib/main.dart`) already names these four as the KHQR issuers it
//   recognises. Adding a row here adds no payment rail.
// * No official logo assets ship with this repository, so every entry renders as
//   a neutral text tile. When authorised artwork is available, put it under
//   `example/assets/`, declare it in `pubspec.yaml`, and set [logoAsset]; the
//   grid draws it with `BoxFit.contain`, so the mark keeps its proportions.

import 'package:flutter/foundation.dart';

/// One payment method shown in [PaymentProviderGrid].
@immutable
class PaymentProvider {
  /// Creates a payment method.
  const PaymentProvider(
      {required this.id, required this.label, this.logoAsset});

  /// A stable identifier, for keys and analytics.
  final String id;

  /// The name drawn in the tile, and the label announced to screen readers.
  final String label;

  /// An authorised logo asset, or `null` to fall back to [label]. No asset ships
  /// with this project, so every entry currently leaves this unset.
  final String? logoAsset;
}

/// The methods the scanner screen shows, in display order.
const List<PaymentProvider> kPaymentProviders = <PaymentProvider>[
  PaymentProvider(id: 'aba', label: 'ABA'),
  PaymentProvider(id: 'acleda', label: 'ACLEDA'),
  PaymentProvider(id: 'wing', label: 'Wing'),
  PaymentProvider(id: 'bakong', label: 'Bakong'),
];
