import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';

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
      _msg('Wallet not connected. Check RPC in Settings.');
      return;
    }
    if (!wallet.validateAddress(_address.text.trim())) {
      _msg('Invalid address for ${wallet.networkConfig?.label}');
      return;
    }
    final amountAtomic = wallet.parseAmount(_amount.text.trim());
    if (amountAtomic <= 0) {
      _msg('Enter a valid amount');
      return;
    }
    final unlocked = wallet.balance?.unlockedAtomic ?? 0;
    if (amountAtomic > unlocked) {
      _msg('Insufficient unlocked balance (${wallet.formatAmount(unlocked)} ZTR)');
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
      _msg('Sent! tx: ${tx.substring(0, 16)}…');
      Navigator.pop(context);
    } else {
      _msg(wallet.errorMessage ?? 'Transfer failed');
    }
  }

  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final prefix = wallet.networkConfig?.addressPrefix ?? 'Z';
    return Scaffold(
      appBar: AppBar(title: const Text('Send ZTR')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _address,
              decoration: InputDecoration(
                labelText: 'Recipient address ($prefix…)',
              ),
              maxLines: 3,
            ),
            if (wallet.balance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Unlocked: ${wallet.formatAmount(wallet.balance!.unlockedAtomic)} ZTR',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (ZTR)',
                suffixText: 'ZTR',
              ),
            ),
            const Spacer(),
            if (_sending)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
          ],
        ),
      ),
    );
  }
}
