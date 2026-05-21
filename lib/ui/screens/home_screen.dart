import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
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
    final pages = [
      _DashboardTab(wallet: wallet),
      const TransactionsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'send',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SendScreen()),
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'recv',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReceiveScreen()),
                  ),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Receive'),
                ),
              ],
            )
          : null,
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.wallet});

  final WalletProvider wallet;

  @override
  Widget build(BuildContext context) {
    final balance = wallet.balance;
    final addr = wallet.primaryAddress?.address ?? '—';
    final state = wallet.connectionState;

    return RefreshIndicator(
      onRefresh: wallet.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const Text('Zentra'),
            actions: [
              if (wallet.isRefreshing)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusChip(state: state, error: wallet.errorMessage),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Colors.white54,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            balance != null
                                ? '${wallet.formatAmount(balance.balanceAtomic)} ZTR'
                                : '—',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balance != null
                                ? 'Unlocked: ${wallet.formatAmount(balance.unlockedAtomic)} ZTR'
                                : '',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: const Text('Primary address'),
                      subtitle: Text(
                        addr,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: addr == '—'
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: addr));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Address copied')),
                                );
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wallet height: ${wallet.walletHeight} · ${wallet.networkConfig?.label ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  if (wallet.daemonBlockHeight > 0)
                    Text(
                      'Daemon (seed): height ${wallet.daemonBlockHeight}'
                      '${wallet.selectedPublicNode != null ? " · ${wallet.selectedPublicNode!.host}" : ""}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  if (wallet.daemonStatus != null &&
                      !wallet.daemonStatus!.startsWith('Daemon OK'))
                    Text(
                      wallet.daemonStatus!,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                    ),
                  if (wallet.isWalletBehindDaemon)
                    const Text(
                      'Wallet is syncing — wait before sending large amounts',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state, this.error});

  final WalletConnectionState state;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      WalletConnectionState.connected => ('Wallet synced', Colors.green),
      WalletConnectionState.connecting => ('Connecting…', Colors.orange),
      WalletConnectionState.error => ('Error', Colors.red),
      _ => ('Disconnected', Colors.grey),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: CircleAvatar(backgroundColor: color, radius: 6),
          label: Text(label),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
      ],
    );
  }
}
