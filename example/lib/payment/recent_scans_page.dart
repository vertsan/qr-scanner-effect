// The persisted list of confirmed payments, opened from the chooser and from
// each banking demo. Tapping a row reopens its receipt.

import 'package:flutter/material.dart';

import 'khqr.dart';
import 'payment_models.dart';
import 'receipt_page.dart';
import 'receipt_store.dart';

/// Shows the receipts saved by [ReceiptStore], newest first.
class RecentScansPage extends StatefulWidget {
  /// Creates the history screen.
  const RecentScansPage({super.key});

  @override
  State<RecentScansPage> createState() => _RecentScansPageState();
}

class _RecentScansPageState extends State<RecentScansPage> {
  late Future<List<PaymentReceipt>> _receipts;

  @override
  void initState() {
    super.initState();
    _receipts = ReceiptStore.load();
  }

  void _reload() {
    setState(() => _receipts = ReceiptStore.load());
  }

  Future<void> _clear() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This removes every receipt saved on this device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ReceiptStore.clear();
    if (!mounted) return;
    _reload();
  }

  Future<void> _openReceipt(PaymentReceipt receipt) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ReceiptPage(receipt: receipt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent scans'),
        actions: <Widget>[
          IconButton(
            onPressed: _clear,
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<PaymentReceipt>>(
        future: _receipts,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<PaymentReceipt>> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<PaymentReceipt> receipts =
              snapshot.data ?? const <PaymentReceipt>[];
          if (receipts.isEmpty) return const _EmptyHistory();

          return ListView.separated(
            itemCount: receipts.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final PaymentReceipt receipt = receipts[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    receipt.payee.isEmpty
                        ? '?'
                        : receipt.payee.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(receipt.payee),
                subtitle: Text(
                  '${formatTimestamp(receipt.createdAt)}\n${receipt.id}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      formatMoney(receipt.amount, receipt.currency),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '≈ ${formatMoney(receipt.otherAmount, receipt.otherCurrency)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                onTap: () => _openReceipt(receipt),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.history,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('No payments yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Confirm a payment in either banking demo and it will show up '
              'here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
