import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/zentra_ui.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _address = TextEditingController();
  final _amount = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final wallet = context.read<WalletProvider>();
    if (wallet.connectionState != WalletConnectionState.connected) {
      _msg('Wallet not connected');
      return;
    }
    if (!wallet.validateAddress(_address.text.trim())) {
      _msg('Invalid address');
      return;
    }
    if (wallet.parseAmount(_amount.text.trim()) <= 0) {
      _msg('Enter a valid amount');
      return;
    }
    setState(() => _sending = true);
    final tx = await wallet.sendTransfer(
      address: _address.text.trim(),
      amount: _amount.text.trim(),
    );
    setState(() => _sending = false);
    if (!mounted) return;
    if (tx != null && tx.isNotEmpty) {
      _msg('Transaction sent');
      Navigator.pop(context);
    } else {
      _msg(wallet.errorMessage ?? 'Failed');
    }
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final prefix = wallet.networkConfig?.addressPrefix ?? 'Z';

    return ZentraScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Send'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _address,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Recipient',
                hintText: '$prefix…',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: 'ZTR',
                helperText: wallet.balance != null
                    ? 'Unlocked ${wallet.formatAmount(wallet.balance!.unlockedAtomic)} ZTR (fees deducted on send)'
                    : null,
              ),
            ),
            const Spacer(),
            if (_sending)
              const Center(child: CircularProgressIndicator(color: ZentraTheme.accent))
            else
              FilledButton(onPressed: _send, child: const Text('Send')),
          ],
        ),
      ),
    );
  }
}
