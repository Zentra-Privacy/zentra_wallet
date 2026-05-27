import 'package:flutter/material.dart';

import '../../theme/zentra_theme.dart';

/// Prompt for wallet file password when switching accounts.
Future<String?> showWalletPasswordDialog(
  BuildContext context, {
  required String walletName,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _WalletPasswordDialog(walletName: walletName),
  );
}

class _WalletPasswordDialog extends StatefulWidget {
  const _WalletPasswordDialog({required this.walletName});

  final String walletName;

  @override
  State<_WalletPasswordDialog> createState() => _WalletPasswordDialogState();
}

class _WalletPasswordDialogState extends State<_WalletPasswordDialog> {
  final _password = TextEditingController();
  bool _hide = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _password.text;
    if (p.isEmpty) return;
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ZentraTheme.card,
      title: Text('Unlock "${widget.walletName}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter the password for this wallet file.',
            style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _hide,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Wallet password',
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Unlock')),
      ],
    );
  }
}
