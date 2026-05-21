import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui_format.dart';
import '../../models/wallet_models.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/zentra_ui.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    return ZentraScaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _DashboardTab(wallet: wallet, onSeeAllTx: () => setState(() => _tab = 2)),
          _AssetsTab(wallet: wallet),
          const TransactionsScreen(embedded: true),
          const SettingsScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: ZentraBottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.wallet, required this.onSeeAllTx});

  final WalletProvider wallet;
  final VoidCallback onSeeAllTx;

  void _openReceive(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceiveScreen()));
  }

  void _openSend(BuildContext context) {
    if (!wallet.canTransact) {
      final msg = wallet.isWalletBehindDaemon
          ? 'Wait for sync to finish before sending'
          : 'Wait until the wallet is connected';
      zentraSnack(context, msg, isError: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SendScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final balance = wallet.balance;
    final recent = wallet.transfers.take(8).toList();
    final address = wallet.primaryAddress?.address ?? '';

    return RefreshIndicator(
      color: ZentraTheme.accent,
      onRefresh: wallet.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ZentraDashboardHeader(
            title: 'Wallet',
            isRefreshing: wallet.isRefreshing,
            onRefresh: wallet.refresh,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: ZentraConnectionChip(
              label: wallet.connectionStatusLabel,
              isError: wallet.connectionState == WalletConnectionState.error,
              isSyncing: wallet.isWalletBehindDaemon ||
                  wallet.connectionState == WalletConnectionState.connecting,
            ),
          ),
          if (wallet.isWalletBehindDaemon)
            ZentraSyncBanner(
              message: 'Syncing with the network…',
              subtitle: wallet.syncProgressLabel,
              progress: wallet.syncProgressFraction,
            )
          else if (wallet.connectionState == WalletConnectionState.connecting)
            const ZentraSyncBanner(message: 'Connecting to node…')
          else if (wallet.connectionState == WalletConnectionState.error)
            ZentraSyncBanner(message: wallet.errorMessage ?? 'Something went wrong', isError: true),
          ZentraHeroBalanceCard(
            amountZtr: balance != null
                ? '${wallet.formatAmount(balance.balanceAtomic)} ZTR'
                : '— ZTR',
            unlockedZtr: balance != null
                ? '${wallet.formatAmount(balance.unlockedAtomic)} ZTR'
                : null,
            lockedZtr: wallet.lockedBalanceAtomic > 0
                ? '${wallet.formatAmount(wallet.lockedBalanceAtomic)} ZTR'
                : null,
            secondaryLabel: wallet.networkConfig?.label,
          ),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Center(child: ZentraAddressChip(address: address)),
            ),
          ZentraQuickActionsRow(
            actions: [
              ZentraQuickActionItem(icon: Icons.arrow_outward, label: 'Send', onTap: () => _openSend(context)),
              ZentraQuickActionItem(icon: Icons.arrow_downward, label: 'Receive', onTap: () => _openReceive(context)),
              const ZentraQuickActionItem(icon: Icons.swap_horiz, label: 'Swap', enabled: false),
              const ZentraQuickActionItem(icon: Icons.add, label: 'Buy', enabled: false),
            ],
          ),
          ZentraSectionHeader(title: 'Recent activity', actionLabel: 'See all', onAction: onSeeAllTx),
          if (recent.isEmpty)
            ZentraEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              subtitle: 'Receive ZTR to this wallet to see activity here.',
              actionLabel: 'Receive',
              onAction: () => _openReceive(context),
            )
          else
            Container(
              margin: ZentraTheme.pagePadding,
              decoration: ZentraTheme.flatCard(),
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++)
                    _txRow(context, recent[i], wallet.formatAmount, showDivider: i < recent.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _txRow(
    BuildContext context,
    WalletTransfer t,
    String Function(int) format, {
    required bool showDivider,
  }) {
    final incoming = t.isIncoming;
    final id = UiFormat.truncateMiddle(t.txid, head: 8, tail: 6);
    return ZentraTxRow(
      title: incoming ? 'Received' : 'Sent',
      subtitle: '$id · ${UiFormat.relativeTime(t.timestamp)}',
      amount: '${incoming ? '+' : '-'}${format(t.amountAtomic)} ZTR',
      isIncoming: incoming,
      pending: t.pending,
      showDivider: showDivider,
      onTap: () => _showTxDetail(context, t, format),
    );
  }

  void _showTxDetail(BuildContext context, WalletTransfer t, String Function(int) format) {
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
              t.isIncoming ? 'Incoming transfer' : 'Outgoing transfer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ZentraCopyField(label: 'Amount', value: '${format(t.amountAtomic)} ZTR', maxLines: 1),
            const SizedBox(height: 12),
            ZentraCopyField(label: 'Transaction ID', value: t.txid),
            const SizedBox(height: 12),
            Text(
              'Time: ${UiFormat.relativeTime(t.timestamp)} · Confirmations: ${t.confirmations}',
              style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetsTab extends StatelessWidget {
  const _AssetsTab({required this.wallet});

  final WalletProvider wallet;

  @override
  Widget build(BuildContext context) {
    final balance = wallet.balance;
    return RefreshIndicator(
      color: ZentraTheme.accent,
      onRefresh: wallet.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ZentraDashboardHeader(title: 'Assets'),
        ZentraHeroBalanceCard(
          amountZtr: balance != null
              ? '${wallet.formatAmount(balance.balanceAtomic)} ZTR'
              : '— ZTR',
          unlockedZtr: balance != null
              ? '${wallet.formatAmount(balance.unlockedAtomic)} ZTR'
              : null,
          lockedZtr: wallet.lockedBalanceAtomic > 0
              ? '${wallet.formatAmount(wallet.lockedBalanceAtomic)} ZTR'
              : null,
        ),
          const SizedBox(height: 8),
          Container(
            margin: ZentraTheme.pagePadding,
            decoration: ZentraTheme.flatCard(),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: ZentraTheme.card,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZentraTheme.surface,
                    borderRadius: BorderRadius.circular(ZentraTheme.radiusSm),
                    border: Border.all(color: ZentraTheme.border),
                  ),
                  child: const Text('Z', style: TextStyle(fontWeight: FontWeight.w700, color: ZentraTheme.accent)),
                ),
                title: const Text('Zentra', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Native coin · ZTR', style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12)),
                trailing: Text(
                  balance != null ? '${wallet.formatAmount(balance.balanceAtomic)} ZTR' : '0',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
