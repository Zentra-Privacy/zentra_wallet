import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final balance = wallet.balance;
    final recent = wallet.transfers.take(8).toList();

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
          if (wallet.isWalletBehindDaemon)
            const ZentraSyncBanner(message: 'Syncing blockchain data…')
          else if (wallet.connectionState == WalletConnectionState.connecting)
            const ZentraSyncBanner(message: 'Connecting to node…')
          else if (wallet.connectionState == WalletConnectionState.error)
            ZentraSyncBanner(message: wallet.errorMessage ?? 'Error', isError: true),
          ZentraHeroBalanceCard(
            amountZtr: balance != null
                ? '${wallet.formatAmount(balance.balanceAtomic)} ZTR'
                : '— ZTR',
            unlockedZtr: balance != null
                ? '${wallet.formatAmount(balance.unlockedAtomic)} ZTR'
                : null,
            secondaryLabel: wallet.networkConfig?.label,
          ),
          const SizedBox(height: 20),
          ZentraQuickActionsRow(
            actions: [
              ZentraQuickActionItem(
                icon: Icons.arrow_outward,
                label: 'Send',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SendScreen()),
                ),
              ),
              ZentraQuickActionItem(
                icon: Icons.arrow_downward,
                label: 'Receive',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReceiveScreen()),
                ),
              ),
              const ZentraQuickActionItem(icon: Icons.swap_horiz, label: 'Swap', enabled: false),
              const ZentraQuickActionItem(icon: Icons.add, label: 'Buy', enabled: false),
            ],
          ),
          ZentraSectionHeader(title: 'Recent activity', actionLabel: 'See all', onAction: onSeeAllTx),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'No activity yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZentraTheme.textMuted.withValues(alpha: 0.8)),
              ),
            )
          else
            Container(
              margin: ZentraTheme.pagePadding,
              decoration: ZentraTheme.flatCard(),
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++)
                    _txRow(recent[i], wallet.formatAmount, showDivider: i < recent.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _txRow(WalletTransfer t, String Function(int) format, {required bool showDivider}) {
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
    final id = t.txid.length > 10 ? '${t.txid.substring(0, 8)}…' : t.txid;
    return ZentraTxRow(
      title: incoming ? 'Received' : 'Sent',
      subtitle: '$id · $timeLabel',
      amount: '${incoming ? '+' : '-'}${format(t.amountAtomic)}',
      isIncoming: incoming,
      showDivider: showDivider,
    );
  }
}

class _AssetsTab extends StatelessWidget {
  const _AssetsTab({required this.wallet});

  final WalletProvider wallet;

  @override
  Widget build(BuildContext context) {
    final balance = wallet.balance;
    return ListView(
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
        ),
        const SizedBox(height: 8),
        Container(
          margin: ZentraTheme.pagePadding,
          decoration: ZentraTheme.flatCard(),
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
            subtitle: const Text('ZTR', style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12)),
            trailing: Text(
              balance != null ? wallet.formatAmount(balance.balanceAtomic) : '0',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
