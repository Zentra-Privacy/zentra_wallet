import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui_format.dart';
import '../../models/wallet_models.dart';
import '../../providers/wallet_provider.dart' show WalletProvider;
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
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    return ZentraScaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _DashboardTab(
            wallet: wallet,
            onSeeAllTx: () => setState(() => _tab = 2),
            onOpenSettings: () => setState(() => _tab = 3),
          ),
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
  const _DashboardTab({
    required this.wallet,
    required this.onSeeAllTx,
    required this.onOpenSettings,
  });

  final WalletProvider wallet;
  final VoidCallback onSeeAllTx;
  final VoidCallback onOpenSettings;

  void _openReceive(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceiveScreen()));
  }

  void _openSend(BuildContext context) {
    if (!wallet.canTransact) {
      final msg = !wallet.isSynced
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
        padding: EdgeInsets.only(bottom: ZentraTheme.navBarHeight + MediaQuery.paddingOf(context).bottom + 24),
        children: [
          ZentraHomeTopBar(
            walletName: wallet.walletFilename,
            networkLabel: wallet.networkConfig?.label,
            isRefreshing: wallet.isRefreshing,
            onRefresh: wallet.refresh,
            onSettings: onOpenSettings,
          ),
          ZentraHeroBalanceCard(
            amountZtr: balance != null
                ? '${wallet.formatAmount(balance.balanceAtomic)} ZTRA'
                : '— ZTRA',
            unlockedZtr: balance != null
                ? '${wallet.formatAmount(balance.unlockedAtomic)} ZTRA'
                : null,
            lockedZtr: wallet.lockedBalanceAtomic > 0
                ? '${wallet.formatAmount(wallet.lockedBalanceAtomic)} ZTRA'
                : null,
            secondaryLabel: wallet.networkConfig?.label,
          ),
          if (address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Center(child: ZentraAddressChip(address: address)),
            ),
          ZentraQuickActionsRow(
            actions: [
              ZentraQuickActionItem(icon: Icons.arrow_outward_rounded, label: 'Send', onTap: () => _openSend(context)),
              ZentraQuickActionItem(icon: Icons.arrow_downward_rounded, label: 'Receive', onTap: () => _openReceive(context)),
            ],
          ),
          ZentraSectionHeader(title: 'Recent activity', actionLabel: 'See all', onAction: onSeeAllTx),
          if (recent.isEmpty)
            ZentraEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              subtitle: 'Receive ZTRA to this wallet to see activity here.',
              actionLabel: 'Receive',
              onAction: () => _openReceive(context),
            )
          else
            Container(
              margin: ZentraTheme.pagePadding,
              decoration: ZentraTheme.gradientCard(),
              clipBehavior: Clip.antiAlias,
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
      amount: '${incoming ? '+' : '-'}${format(t.amountAtomic)} ZTRA',
      isIncoming: incoming,
      pending: t.pending,
      showDivider: showDivider,
      onTap: () => showZentraTxDetailSheet(context, transfer: t, formatAmount: format),
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
        padding: EdgeInsets.only(bottom: ZentraTheme.navBarHeight + MediaQuery.paddingOf(context).bottom + 24),
        children: [
          const ZentraDashboardHeader(title: 'Assets'),
          ZentraHeroBalanceCard(
            amountZtr: balance != null
                ? '${wallet.formatAmount(balance.balanceAtomic)} ZTRA'
                : '— ZTRA',
            unlockedZtr: balance != null
                ? '${wallet.formatAmount(balance.unlockedAtomic)} ZTRA'
                : null,
            lockedZtr: wallet.lockedBalanceAtomic > 0
                ? '${wallet.formatAmount(wallet.lockedBalanceAtomic)} ZTRA'
                : null,
          ),
          const SizedBox(height: 12),
          Container(
            margin: ZentraTheme.pagePadding,
            decoration: ZentraTheme.gradientCard(),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: ZentraTheme.iconCircle(),
                child: const ZentraLogo(size: 32),
              ),
              title: const Text('Zentra', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: const Text('Native coin · ZTRA', style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12)),
              trailing: Text(
                balance != null ? '${wallet.formatAmount(balance.balanceAtomic)} ZTRA' : '0',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ZentraTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
