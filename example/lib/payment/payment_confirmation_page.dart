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
    final PaymentCurrency other = _currency == PaymentCurrency.usd
        ? PaymentCurrency.khr
        : PaymentCurrency.usd;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm payment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            _PayeeCard(request: widget.request),
            const SizedBox(height: 24),
            const _SectionLabel('Amount'),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              autofocus: !widget.request.hasAmount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: '${_currency.symbol} ',
                hintText: _currency.hasDecimals ? '0.00' : '0',
                border: const OutlineInputBorder(),
                helperText: widget.request.hasAmount
                    ? 'Amount from the QR code — edit if needed'
                    : 'This code has no amount; enter it here',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Text(
              amount == null
                  ? 'Enter an amount to see the conversion'
                  : '≈ ${formatMoney(convertCurrency(amount, _currency, other), other)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PaymentCurrency>(
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
            const _SectionLabel('Pay from'),
            const SizedBox(height: 4),
            for (final BankAccount account in kDemoAccounts)
              _AccountTile(
                account: account,
                selected: account.id == _account.id,
                onTap: () => setState(() => _account = account),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _confirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      amount == null
                          ? 'Confirm'
                          : 'Confirm ${formatMoney(amount, _currency)}',
                    ),
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              child: Text(
                request.payee.isEmpty
                    ? '?'
                    : request.payee.characters.first.toUpperCase(),
                style: theme.textTheme.titleMedium,
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
                  if (request.city != null)
                    Text(
                      request.city!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _VerifiedBadge(verified: request.verified),
                ],
              ),
            ),
          ],
        ),
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
    final Color color =
        verified ? theme.colorScheme.primary : theme.colorScheme.error;
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? theme.colorScheme.primary : null,
        ),
        title: Text(account.label),
        subtitle: account.maskedNumber == null
            ? null
            : Text('${account.currency.code} • ${account.maskedNumber}'),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
