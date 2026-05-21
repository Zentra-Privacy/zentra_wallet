import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wallet_models.dart';
import '../../providers/wallet_provider.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final list = wallet.transfers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: wallet.refresh,
          ),
        ],
      ),
      body: list.isEmpty
          ? const Center(child: Text('No transfers yet'))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => _TransferTile(
                transfer: list[i],
                format: wallet.formatAmount,
              ),
            ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.transfer, required this.format});

  final WalletTransfer transfer;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final sign = transfer.isIncoming ? '+' : '-';
    final color = transfer.isIncoming ? Colors.greenAccent : Colors.orangeAccent;
    final date = DateTime.fromMillisecondsSinceEpoch(transfer.timestamp * 1000);

    return ListTile(
      leading: Icon(
        transfer.isIncoming ? Icons.call_received : Icons.call_made,
        color: color,
      ),
      title: Text('$sign${format(transfer.amountAtomic)} ZTR'),
      subtitle: Text(
        '${transfer.failed ? "Failed · " : transfer.pending ? "Pending · " : ""}'
        'h:${transfer.height} · ${date.toLocal()}',
      ),
      trailing: Text(
        transfer.txid.length > 8 ? '${transfer.txid.substring(0, 8)}…' : transfer.txid,
        style: const TextStyle(fontSize: 11, color: Colors.white38),
      ),
    );
  }
}
