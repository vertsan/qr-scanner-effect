// The "PIN or biometric before paying" gate.
//
// `local_auth` handles the real device prompt. On platforms without it — a
// desktop, the web, an emulator with nothing enrolled — the example falls back
// to a demo PIN so the gate is still visible. That fallback exists to make the
// example runnable anywhere; a shipping app should not ship one.

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Confirms a payment with the device's biometrics or passcode.
///
/// Returns `true` only when the user actually authenticated. A deliberate
/// cancel returns `false` and does *not* drop through to the PIN fallback.
Future<bool> confirmPayment(
  BuildContext context, {
  required String reason,
}) async {
  final LocalAuthentication auth = LocalAuthentication();

  bool supported = false;
  try {
    supported = await auth.isDeviceSupported();
  } on Object {
    supported = false;
  }

  if (supported) {
    try {
      final bool ok = await auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok;
    } on LocalAuthException catch (error) {
      // The user chose to cancel: honour that instead of silently upgrading to
      // the fallback.
      if (error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled) {
        return false;
      }
      // Any other failure (no credentials, no hardware, UI unavailable) falls
      // through to the demo PIN.
    } on Object {
      // Missing plugin / unsupported platform.
    }
  }

  if (!context.mounted) return false;
  return _showDemoPin(context);
}

Future<bool> _showDemoPin(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => const _DemoPinDialog(),
  );
  return ok ?? false;
}

class _DemoPinDialog extends StatefulWidget {
  const _DemoPinDialog();

  @override
  State<_DemoPinDialog> createState() => _DemoPinDialogState();
}

class _DemoPinDialogState extends State<_DemoPinDialog> {
  static const String _demoPin = '123456';

  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text == _demoPin) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = 'Incorrect PIN');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm with PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'No biometrics are available here, so the example falls back to a '
            'demo PIN.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'PIN',
              errorText: _error,
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 4),
          Text(
            'Demo PIN: $_demoPin',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Authorise'),
        ),
      ],
    );
  }
}
