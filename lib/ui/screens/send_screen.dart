import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _pasteAddress() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _address.text = text);
    }
  }

  void _fillMaxAmount(WalletProvider wallet) {
    final unlocked = wallet.balance?.unlockedAtomic ?? 0;
    if (unlocked <= 0) return;
    setState(() => _amount.text = wallet.formatAmount(unlocked));
  }

  Future<bool> _confirmSend(WalletProvider wallet, String addr, String amount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZentraTheme.card,
        title: const Text('Confirm send'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to send $amount ZTR', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('To:', style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(addr, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            const Text(
              'Network fees will be deducted from your balance. This cannot be undone.',
              style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send now')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _send() async {
    final wallet = context.read<WalletProvider>();
    if (!wallet.canTransact) {
      zentraSnack(context, 'Wallet is not ready. Check connection in Settings.', isError: true);
      return;
    }
    final addr = _address.text.trim();
    if (!wallet.validateAddress(addr)) {
      zentraSnack(context, 'That address does not look valid for ${wallet.networkConfig?.label ?? "this network"}', isError: true);
      return;
    }
    final amountStr = _amount.text.trim();
    if (wallet.parseAmount(amountStr) <= 0) {
      zentraSnack(context, 'Enter an amount greater than zero', isError: true);
      return;
    }
    if (!await _confirmSend(wallet, addr, amountStr)) return;

    setState(() => _sending = true);
    final tx = await wallet.sendTransfer(address: addr, amount: amountStr);
    setState(() => _sending = false);
    if (!mounted) return;
    if (tx != null && tx.isNotEmpty) {
      zentraSnack(context, 'Sent successfully');
      Navigator.pop(context);
    } else {
      zentraSnack(context, wallet.errorMessage ?? 'Send failed', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final prefix = wallet.networkConfig?.addressPrefix ?? 'Z';
    final unlocked = wallet.balance?.unlockedAtomic;

    return ZentraScaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Send ZTR'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _address,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Recipient address',
                hintText: 'Paste a $prefix address',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  tooltip: 'Paste',
                  onPressed: _pasteAddress,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: 'ZTR',
                helperText: unlocked != null
                    ? 'Available to send: ${wallet.formatAmount(unlocked)} ZTR (fees extra)'
                    : null,
              ),
            ),
            if (unlocked != null && unlocked > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _fillMaxAmount(wallet),
                  child: const Text('Use max unlocked'),
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _sending || !wallet.canTransact ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Review & send'),
            ),
          ],
        ),
      ),
    );
  }
}
