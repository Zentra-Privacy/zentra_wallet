import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/wallet_models.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/zentra_ui.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    var list = wallet.transfers;
    if (_filter == 1) list = list.where((t) => t.isIncoming).toList();
    if (_filter == 2) list = list.where((t) => !t.isIncoming).toList();

    final listBody = list.isEmpty
        ? const Center(child: Text('No transactions', style: TextStyle(color: ZentraTheme.textMuted)))
        : ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              Container(
                margin: ZentraTheme.pagePadding,
                decoration: ZentraTheme.flatCard(),
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      _row(list[i], wallet.formatAmount, i < list.length - 1),
                  ],
                ),
              ),
            ],
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded) const ZentraDashboardHeader(title: 'History'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SegmentedButton<int>(
            style: ButtonStyle(
              side: WidgetStateProperty.all(const BorderSide(color: ZentraTheme.border)),
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                return s.contains(WidgetState.selected) ? ZentraTheme.surface : ZentraTheme.card;
              }),
            ),
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 1, label: Text('In')),
              ButtonSegment(value: 2, label: Text('Out')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        Expanded(child: listBody),
      ],
    );

    if (widget.embedded) return content;

    return ZentraScaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: wallet.refresh),
        ],
      ),
      body: content,
    );
  }

  Widget _row(WalletTransfer t, String Function(int) format, bool showDivider) {
    final incoming = t.isIncoming;
    String timeLabel = 'Pending';
    if (t.timestamp > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t.timestamp * 1000);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeLabel = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 48) {
        timeLabel = '${diff.inHours}h ago';
      } else {
        timeLabel = DateFormat.MMMd().format(dt);
      }
    }
    return ZentraTxRow(
      title: incoming ? 'Received' : 'Sent',
      subtitle: '${t.txid.length > 8 ? '${t.txid.substring(0, 8)}…' : t.txid} · $timeLabel',
      amount: '${incoming ? '+' : '-'}${format(t.amountAtomic)}',
      isIncoming: incoming,
      showDivider: showDivider,
    );
  }
}
