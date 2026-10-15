// The persisted list of confirmed payments, opened from the chooser and from
// each banking demo. Tapping a row reopens its receipt.

import 'package:flutter/material.dart';

import 'khqr.dart';
import 'payment_models.dart';
import 'receipt_page.dart';
import 'receipt_store.dart';
import '../theme.dart';

/// Shows the receipts saved by [ReceiptStore], newest first, grouped by day.
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
        backgroundColor: AppTheme.surface,
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: _grouped(receipts),
          );
        },
      ),
    );
  }

  /// Flattens the receipts into section headers and cards.
  List<Widget> _grouped(List<PaymentReceipt> receipts) {
    final List<Widget> items = <Widget>[];
    DateTime? lastDay;
    for (final PaymentReceipt receipt in receipts) {
      final DateTime createdAt = receipt.createdAt;
      final DateTime day = DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
      );
      if (day != lastDay) {
        items.add(_DateHeader(label: _dateLabel(createdAt)));
        lastDay = day;
      }
      items.add(
        _ReceiptCard(receipt: receipt, time: _clock(createdAt), onTap: () => _openReceipt(receipt)),
      );
    }
    return items;
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.receipt,
    required this.time,
    required this.onTap,
  });

  final PaymentReceipt receipt;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.outline.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.accentContainer,
                  foregroundColor: AppTheme.onAccentContainer,
                  child: Text(
                    receipt.payee.isEmpty
                        ? '?'
                        : receipt.payee.characters.first.toUpperCase(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.onAccentContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        receipt.payee,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$time · ${receipt.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      formatMoney(receipt.amount, receipt.currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ ${formatMoney(receipt.otherAmount, receipt.otherCurrency)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
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
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.accentContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 34,
                color: AppTheme.onAccentContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No payments yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Confirm a payment in either banking demo and it will show up '
              'here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A friendly day label: "Today", "Yesterday", else a full date.
String _dateLabel(DateTime time) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(time.year, time.month, time.day);
  final int diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${time.day} ${months[time.month - 1]} ${time.year}';
}

/// `HH:mm`, tabular.
String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
