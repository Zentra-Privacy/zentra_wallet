import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/qr_payload_parser.dart';
import '../../providers/wallet_provider.dart';
import '../../services/qr_scanner_launcher.dart';
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
  int _feeAtomic = 0;
  bool _estimatingFee = false;
  int _priority = 0;
  int _feeEstimateGeneration = 0;

  @override
  void initState() {
    super.initState();
    _address.addListener(_scheduleFeeEstimate);
    _amount.addListener(_scheduleFeeEstimate);
  }

  @override
  void dispose() {
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _scheduleFeeEstimate() {
    if (mounted) setState(() {});
    final gen = ++_feeEstimateGeneration;
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted && gen == _feeEstimateGeneration) _updateFeeEstimate(gen);
    });
  }

  Future<void> _updateFeeEstimate(int gen) async {
    final wallet = context.read<WalletProvider>();
    final addr = _address.text.trim();
    final amount = _amount.text.trim();
    if (!wallet.validateAddress(addr) || wallet.parseAmount(amount) <= 0) {
      if (mounted && gen == _feeEstimateGeneration) setState(() => _feeAtomic = 0);
      return;
    }
    if (mounted) setState(() => _estimatingFee = true);
    try {
      final fee = await wallet.estimateTransferFee(
        address: addr,
        amount: amount,
        priority: _priority,
      );
      if (mounted && gen == _feeEstimateGeneration) {
        setState(() {
          _feeAtomic = fee ?? 0;
          _estimatingFee = false;
        });
      }
    } catch (_) {
      if (mounted && gen == _feeEstimateGeneration) {
        setState(() {
          _feeAtomic = 0;
          _estimatingFee = false;
        });
      }
    }
  }

  Future<void> _pasteAddress() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _address.text = text);
      _scheduleFeeEstimate();
    }
  }

  Future<void> _scanQr() async {
    final raw = await QrScannerLauncher.scan(context);
    if (raw == null || !mounted) return;
    final wallet = context.read<WalletProvider>();
    final payment = QrPayloadParser.parsePayment(
      raw,
      validateAddress: wallet.validateAddress,
    );
    if (payment == null) {
      zentraSnack(
        context,
        'QR does not contain a valid ${wallet.networkConfig?.label ?? "network"} address',
        isError: true,
      );
      return;
    }
    setState(() {
      _address.text = payment.address;
      if (payment.amountDisplay != null) {
        _amount.text = payment.amountDisplay!;
      }
    });
    _scheduleFeeEstimate();
    if (payment.paymentId != null && mounted) {
      zentraSnack(context, 'Payment ID in QR is not used for this send');
    }
  }

  void _fillMaxAmount(WalletProvider wallet) {
    final unlocked = wallet.balance?.unlockedAtomic ?? 0;
    if (unlocked <= 0) return;
    final spendable = unlocked - _feeAtomic;
    if (spendable <= 0) {
      zentraSnack(context, 'Not enough unlocked balance for amount + fee', isError: true);
      return;
    }
    setState(() => _amount.text = wallet.formatAmount(spendable));
    _scheduleFeeEstimate();
  }

  Future<bool> _confirmSend(WalletProvider wallet, String addr, String amount) async {
    final amountAtomic = wallet.parseAmount(amount);
    final totalAtomic = amountAtomic + _feeAtomic;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZentraTheme.card,
        title: const Text('Confirm send'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Amount', '$amount ZTRA'),
            _confirmRow('Network fee', '${wallet.formatAmount(_feeAtomic)} ZTRA'),
            _confirmRow('Total deducted', '${wallet.formatAmount(totalAtomic)} ZTRA',
                bold: true),
            const SizedBox(height: 12),
            const Text('To:', style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(addr, style: const TextStyle(fontSize: 12)),
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

  Widget _confirmRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final wallet = context.read<WalletProvider>();
    if (!wallet.canTransact) {
      final msg = !wallet.isSynced
          ? 'Wait for sync to finish before sending'
          : 'Wallet is not ready. Check connection in Settings.';
      zentraSnack(context, msg, isError: true);
      return;
    }
    final addr = _address.text.trim();
    if (!wallet.validateAddress(addr)) {
      zentraSnack(context, 'That address does not look valid for ${wallet.networkConfig?.label ?? "this network"}', isError: true);
      return;
    }
    final amountStr = _amount.text.trim();
    final amountAtomic = wallet.parseAmount(amountStr);
    if (amountAtomic <= 0) {
      zentraSnack(context, 'Enter an amount greater than zero', isError: true);
      return;
    }
    final unlocked = wallet.balance?.unlockedAtomic ?? 0;
    if (_feeAtomic <= 0) {
      zentraSnack(context, 'Fee estimate unavailable — check address, amount, and sync', isError: true);
      return;
    }
    if (amountAtomic + _feeAtomic > unlocked) {
      zentraSnack(
        context,
        'Need ${wallet.formatAmount(amountAtomic + _feeAtomic)} ZTRA unlocked (amount + fee)',
        isError: true,
      );
      return;
    }
    if (!await _confirmSend(wallet, addr, amountStr)) return;

    wallet.sendPriority = _priority;
    setState(() => _sending = true);
    final tx = await wallet.sendTransfer(address: addr, amount: amountStr, priority: _priority);
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
    final amountAtomic = wallet.parseAmount(_amount.text.trim());
    final totalNeeded = amountAtomic > 0 ? amountAtomic + _feeAtomic : 0;

    return ZentraScaffold(
      appBar: zentraAppBar(context, title: 'Send ZTRA'),
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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Scan QR',
                      onPressed: _scanQr,
                    ),
                    IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: 'Paste',
                      onPressed: _pasteAddress,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_priority),
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Fee priority'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Standard')),
                DropdownMenuItem(value: 1, child: Text('Slow (lower fee)')),
                DropdownMenuItem(value: 2, child: Text('Medium')),
                DropdownMenuItem(value: 3, child: Text('Fast')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _priority = v);
                _scheduleFeeEstimate();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: 'ZTRA',
                helperText: unlocked != null
                    ? 'Unlocked: ${wallet.formatAmount(unlocked)} ZTRA'
                    : null,
              ),
            ),
            if (unlocked != null && unlocked > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _fillMaxAmount(wallet),
                  child: const Text('Max (minus fee)'),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: ZentraTheme.flatCard(),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated fee', style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13)),
                      if (_estimatingFee)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.accent),
                        )
                      else
                        Text(
                          '${wallet.formatAmount(_feeAtomic)} ZTRA',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  if (amountAtomic > 0) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total from wallet', style: TextStyle(fontSize: 13)),
                        Text(
                          '${wallet.formatAmount(totalNeeded)} ZTRA',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: ZentraTheme.accent),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (wallet.isWalletBehindDaemon) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZentraTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  wallet.syncProgressLabel ?? 'Syncing — send disabled until caught up',
                  style: const TextStyle(color: ZentraTheme.accent, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'After sending, change may show as locked until ~10 confirmations.',
              style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 24),
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
