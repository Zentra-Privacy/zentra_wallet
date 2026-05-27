import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/zentra_ui.dart';

/// Review transfer details before broadcasting (replaces confirmation dialog).
class SendConfirmScreen extends StatefulWidget {
  const SendConfirmScreen({
    super.key,
    required this.address,
    required this.amountDisplay,
    required this.feeAtomic,
    required this.priority,
  });

  final String address;
  final String amountDisplay;
  final int feeAtomic;
  final int priority;

  @override
  State<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends State<SendConfirmScreen> {
  bool _sending = false;

  String _priorityLabel(int p) => switch (p) {
        1 => 'Slow',
        2 => 'Medium',
        3 => 'Fast',
        _ => 'Standard',
      };

  Future<void> _sendNow() async {
    final wallet = context.read<WalletProvider>();
    if (!wallet.canTransact) {
      zentraSnack(
        context,
        !wallet.isSynced ? 'Wait for sync to finish' : 'Wallet not ready',
        isError: true,
      );
      return;
    }
    setState(() => _sending = true);
    wallet.sendPriority = widget.priority;
    final tx = await wallet.sendTransfer(
      address: widget.address,
      amount: widget.amountDisplay,
      priority: widget.priority,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (tx != null && tx.isNotEmpty) {
      zentraSnack(context, 'Sent successfully');
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    zentraSnack(context, wallet.errorMessage ?? 'Send failed', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final amountAtomic = wallet.parseAmount(widget.amountDisplay);
    final totalAtomic = amountAtomic + widget.feeAtomic;

    return ZentraScaffold(
      appBar: zentraAppBar(context, title: 'Confirm send'),
      body: SingleChildScrollView(
        padding: zentraPageScrollPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Review the details below. This transfer cannot be reversed after you send.',
              style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ZentraTheme.flatCard(),
              child: Column(
                children: [
                  _row('Amount', '${widget.amountDisplay} ZTRA'),
                  _row('Network fee', '${wallet.formatAmount(widget.feeAtomic)} ZTRA'),
                  const Divider(height: 24),
                  _row(
                    'Total deducted',
                    '${wallet.formatAmount(totalAtomic)} ZTRA',
                    bold: true,
                    accent: true,
                  ),
                  const SizedBox(height: 12),
                  _row('Fee priority', _priorityLabel(widget.priority)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recipient',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: ZentraTheme.flatCard(color: ZentraTheme.surface),
              child: SelectableText(
                widget.address,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'After sending, change may show as locked until ~10 confirmations.',
              style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 32),
            ZentraLoadingButton(
              label: 'Send now',
              loadingLabel: 'Sending…',
              loading: _sending,
              onPressed: _sendNow,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _sending ? null : () => Navigator.pop(context),
              child: const Text('Back to edit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool accent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 13)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                color: accent ? ZentraTheme.accent : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
