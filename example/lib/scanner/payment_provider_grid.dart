// The compact payment-methods strip at the bottom of the scanner screen.
//
// See `payment_provider.dart` for why the entries are neutral text tiles rather
// than trademarked logos, and why the list is what it is.

import 'package:flutter/material.dart';

import 'payment_provider.dart';
import 'scanner_style.dart';

/// A centred, evenly spaced grid of the payment methods this app reads.
class PaymentProviderGrid extends StatelessWidget {
  /// Creates the grid.
  const PaymentProviderGrid({
    super.key,
    this.providers = kPaymentProviders,
    this.caption = 'Accepted via KHQR',
  });

  /// The methods to show. An empty list renders nothing.
  final List<PaymentProvider> providers;

  /// The small label above the row.
  final String caption;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ScannerStyle.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            caption.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ScannerStyle.caption,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          // A Wrap rather than a GridView: the row reflows to one or two lines by
          // itself, so nothing clips on a narrow phone or a tablet.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final PaymentProvider provider in providers)
                _ProviderTile(provider: provider),
            ],
          ),
        ],
      ),
    );
  }
}

/// One fixed-size payment-method tile.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider});

  final PaymentProvider provider;

  @override
  Widget build(BuildContext context) {
    final String? logo = provider.logoAsset;

    return Semantics(
      label: provider.label,
      excludeSemantics: true,
      child: Container(
        width: ScannerStyle.providerTileWidth,
        height: ScannerStyle.providerTileHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ScannerStyle.providerTile,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ScannerStyle.providerTileBorder),
        ),
        child: logo == null
            ? _label()
            : Image.asset(
                logo,
                fit: BoxFit.contain,
                width: ScannerStyle.providerTileWidth - 16,
                height: ScannerStyle.providerTileHeight - 14,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) =>
                    _label(),
              ),
      ),
    );
  }

  Widget _label() => Text(
        provider.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ScannerStyle.providerLabel,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      );
}
