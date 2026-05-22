import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui_format.dart';
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
        ? ZentraEmptyState(
            icon: Icons.history,
            title: 'No transactions',
            subtitle: _filter == 0
                ? 'Your incoming and outgoing transfers will appear here.'
                : 'Nothing in this filter yet.',
          )
        : RefreshIndicator(
            color: ZentraTheme.accent,
            onRefresh: wallet.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                Container(
                  margin: ZentraTheme.pagePadding,
                  decoration: ZentraTheme.flatCard(),
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++)
                        _row(context, list[i], wallet.formatAmount, i < list.length - 1),
                    ],
                  ),
                ),
              ],
            ),
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded)
          ZentraDashboardHeader(
            title: 'History',
            isRefreshing: wallet.isRefreshing,
            onRefresh: wallet.refresh,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SegmentedButton<int>(
            style: ButtonStyle(
              side: WidgetStateProperty.all(const BorderSide(color: ZentraTheme.border)),
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                return s.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55);
              }),
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                return s.contains(WidgetState.selected) ? ZentraTheme.surface : ZentraTheme.card;
              }),
            ),
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 1, label: Text('Received')),
              ButtonSegment(value: 2, label: Text('Sent')),
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

  Widget _row(BuildContext context, WalletTransfer t, String Function(int) format, bool showDivider) {
    final incoming = t.isIncoming;
    return ZentraTxRow(
      title: incoming ? 'Received' : 'Sent',
      subtitle: '${UiFormat.truncateMiddle(t.txid, head: 8, tail: 6)} · ${UiFormat.relativeTime(t.timestamp)}',
      amount: '${incoming ? '+' : '-'}${format(t.amountAtomic)} ZTR',
      isIncoming: incoming,
      pending: t.pending,
      showDivider: showDivider,
      onTap: () => _showDetail(context, t, format),
    );
  }

  void _showDetail(BuildContext context, WalletTransfer t, String Function(int) format) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZentraTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.isIncoming ? 'Received' : 'Sent',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ZentraCopyField(label: 'Amount', value: '${format(t.amountAtomic)} ZTR', maxLines: 1),
            const SizedBox(height: 12),
            ZentraCopyField(label: 'Transaction ID', value: t.txid),
            const SizedBox(height: 8),
            Text(
              '${UiFormat.relativeTime(t.timestamp)} · ${t.confirmations} confirmations',
              style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
