// The payment confirmation screen: enter an amount (if the code has none), pick
// a source account, see the conversion, and confirm behind a biometric gate.
//
// This is host UI. The overlay package has already finished by the time this
// screen appears; here the example app acts as the "backend" that decided what
// the code meant.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'biometric_gate.dart';
import 'khqr.dart';
import 'payment_models.dart';
import 'receipt_page.dart';
import 'receipt_store.dart';
import '../theme.dart';

/// Collects the amount and account for a scanned payment, then gates it.
class PaymentConfirmationPage extends StatefulWidget {
  /// Creates a confirmation screen for [request].
  const PaymentConfirmationPage({super.key, required this.request});

  /// The host's validated view of the scanned code.
  final PaymentRequest request;

  @override
  State<PaymentConfirmationPage> createState() =>
      _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState extends State<PaymentConfirmationPage> {
  late final TextEditingController _amount;
  late PaymentCurrency _currency;
  late BankAccount _account;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.request.currency;
    _amount = TextEditingController(text: _initialAmountText());
    _account = _firstAccountFor(_currency);
  }

  String _initialAmountText() {
    final double? amount = widget.request.amount;
    if (amount == null || amount <= 0) return '';
    return _currency.hasDecimals
        ? amount.toStringAsFixed(2)
        : amount.round().toString();
  }

  BankAccount _firstAccountFor(PaymentCurrency currency) {
    for (final BankAccount account in kDemoAccounts) {
      if (account.currency == currency) return account;
    }
    return kDemoAccounts.first;
  }

  double? get _parsedAmount {
    final double? value = double.tryParse(_amount.text.trim());
    return (value == null || value <= 0) ? null : value;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _selectCurrency(PaymentCurrency currency) {
    if (currency == _currency) return;
    setState(() {
      _currency = currency;
      _account = _firstAccountFor(currency);
    });
  }

  Future<void> _confirm() async {
    final double? amount = _parsedAmount;
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount to continue')),
      );
      return;
    }

    setState(() => _busy = true);
    final bool ok = await confirmPayment(
      context,
      reason: 'Authorise ${formatMoney(amount, _currency)} to '
          '${widget.request.payee}',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment cancelled')),
      );
      return;
    }

    final PaymentReceipt receipt = PaymentReceipt(
      id: PaymentReceipt.newId(),
      payee: widget.request.payee,
      amount: amount,
      currency: _currency,
      account: _account,
      createdAt: DateTime.now(),
    );
    // Remember it locally, then show the receipt. Saving first means the history
    // is complete even if the user leaves from the receipt screen.
    await ReceiptStore.add(receipt);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ReceiptPage(receipt: receipt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? amount = _parsedAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: <Widget>[
          _PayeeCard(request: widget.request),
          const SizedBox(height: 24),
          Text(
            'Amount',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            autofocus: !widget.request.hasAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixText: '${_currency.symbol} ',
              hintText: _currency.hasDecimals ? '0.00' : '0',
              helperText: widget.request.hasAmount
                  ? 'Amount from the QR code — edit if needed'
                  : 'This code has no amount; enter it here',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<PaymentCurrency>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.accentContainer,
              selectedForegroundColor: AppTheme.onAccentContainer,
              foregroundColor: AppTheme.onSurfaceVariant,
            ),
            segments: const <ButtonSegment<PaymentCurrency>>[
              ButtonSegment<PaymentCurrency>(
                value: PaymentCurrency.usd,
                label: Text('USD'),
              ),
              ButtonSegment<PaymentCurrency>(
                value: PaymentCurrency.khr,
                label: Text('KHR'),
              ),
            ],
            selected: <PaymentCurrency>{_currency},
            onSelectionChanged: (Set<PaymentCurrency> selection) =>
                _selectCurrency(selection.first),
          ),
          const SizedBox(height: 28),
          Text(
            'Pay from',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          for (final BankAccount account in kDemoAccounts)
            _AccountTile(
              account: account,
              selected: account.id == _account.id,
              onTap: () => setState(() => _account = account),
            ),
        ],
      ),
      bottomNavigationBar: _ConfirmBar(
        amount: amount,
        currency: _currency,
        busy: _busy,
        onConfirm: _confirm,
      ),
    );
  }
}

/// A persistent bar: the conversion, then the one action that matters.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.amount,
    required this.currency,
    required this.busy,
    required this.onConfirm,
  });

  final double? amount;
  final PaymentCurrency currency;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PaymentCurrency other = currency == PaymentCurrency.usd
        ? PaymentCurrency.khr
        : PaymentCurrency.usd;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border:
                  Border.all(color: AppTheme.outline.withValues(alpha: 0.7)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'You pay',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      amount == null ? '—' : formatMoney(amount!, currency),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      amount == null
                          ? 'Enter an amount above'
                          : '≈ ${formatMoney(convertCurrency(amount!, currency, other), other)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : onConfirm,
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    amount == null
                        ? 'Confirm'
                        : 'Confirm ${formatMoney(amount!, currency)}',
                  ),
          ),
        ],
      ),
    );
  }
}

class _PayeeCard extends StatelessWidget {
  const _PayeeCard({required this.request});

  final PaymentRequest request;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.accentContainer,
            foregroundColor: AppTheme.onAccentContainer,
            child: Text(
              request.payee.isEmpty
                  ? '?'
                  : request.payee.characters.first.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.onAccentContainer,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  request.payee,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (request.city != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    request.city!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _VerifiedBadge(verified: request.verified),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = verified ? AppTheme.accent : AppTheme.negative;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          verified ? Icons.verified_user : Icons.report_problem,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          verified ? 'Recognised by the host' : 'Unverified merchant',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final BankAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? AppTheme.accentContainer : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? AppTheme.accent
                    : AppTheme.outline.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.account_balance_outlined,
                  color: selected ? AppTheme.accent : AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        account.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (account.maskedNumber != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          '${account.currency.code} • ${account.maskedNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
