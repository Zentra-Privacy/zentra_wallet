import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/zentra_network.dart';
import '../../core/native_wallet_messages.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/restore_height_settings_panel.dart';
import '../widgets/zentra_ui.dart';
import 'onboarding_screen.dart';
import 'node_setup_screen.dart';
import 'wallet_backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    final list = ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: ZentraTheme.flatCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ZentraConnectionChip(
                      label: wallet.connectionStatusLabel,
                      isError: wallet.connectionState == WalletConnectionState.error,
                      isSyncing: wallet.isWalletBehindDaemon,
                    ),
                    const Spacer(),
                    if (wallet.isRefreshing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.accent),
                      ),
                  ],
                ),
                if (wallet.syncProgressLabel != null) ...[
                  const SizedBox(height: 10),
                  Text(wallet.syncProgressLabel!, style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12)),
                ],
                if (wallet.primaryAddress != null) ...[
                  const SizedBox(height: 12),
                  ZentraAddressChip(address: wallet.primaryAddress!.address),
                ],
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('Wallet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZentraTheme.textMuted)),
        ),
        ZentraSettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'My Wallet',
          subtitle: wallet.walletFilename ?? '—',
        ),
        ZentraSettingsTile(
          icon: Icons.lock_outline,
          title: 'Backup & seed phrase',
          subtitle: wallet.connectionState == WalletConnectionState.connected
              ? 'View address and seed to copy'
              : 'Connect wallet first',
          onTap: wallet.connectionState == WalletConnectionState.connected
              ? () async {
                  final backup = await wallet.fetchBackupInfo();
                  if (!context.mounted) return;
                  if (backup == null) {
                    zentraSnack(context, 'Could not read wallet backup', isError: true);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WalletBackupScreen(
                        backup: backup,
                        requireSeedAcknowledgement: false,
                        blockBack: false,
                      ),
                    ),
                  );
                }
              : null,
        ),
        const RestoreHeightSettingsPanel(),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text('Network', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZentraTheme.textMuted)),
        ),
        ZentraSettingsTile(
          icon: Icons.dns_outlined,
          title: 'Node',
          subtitle: wallet.nodeSettings?.daemonAddress ?? '—',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NodeSetupScreen()),
          ),
        ),
        ZentraSettingsTile(
          icon: Icons.hub_outlined,
          title: 'Network',
          subtitle: wallet.networkConfig?.label ?? '—',
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<ZentraNetType>(
              value: wallet.networkType,
              dropdownColor: ZentraTheme.card,
              items: ZentraNetType.values
                  .map(
                    (n) => DropdownMenuItem(
                      value: n,
                      child: Text(ZentraNetworkConfig.fromType(n).label),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await wallet.updateNetwork(v);
                if (!context.mounted) return;
                if (wallet.networkType != v) {
                  zentraSnack(
                    context,
                    wallet.errorMessage ?? 'Network not changed',
                    isError: true,
                  );
                  return;
                }
                zentraSnack(
                  context,
                  wallet.connectionState == WalletConnectionState.connected
                      ? 'Network changed — reconnecting'
                      : 'Network changed',
                );
              },
            ),
          ),
        ),
        if (!wallet.nativeAvailable)
          const ZentraSettingsTile(
            icon: Icons.build_outlined,
            title: NativeWalletMessages.title,
            subtitle: NativeWalletMessages.subtitle,
          ),
        ZentraSettingsTile(
          icon: Icons.refresh,
          title: 'Reconnect',
          subtitle: 'Sync with daemon again',
          onTap: () async {
            final ok = await wallet.connect();
            if (context.mounted) {
              zentraSnack(context, ok ? 'Connected to node' : wallet.errorMessage ?? 'Reconnect failed', isError: !ok);
            }
          },
        ),
        const Divider(height: 32),
        ZentraSettingsTile(
          icon: Icons.swap_horiz,
          title: 'Open different wallet',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ZentraDashboardHeader(title: 'Settings'),
          Expanded(child: list),
        ],
      );
    }

    return ZentraGradientScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: list,
    );
  }
}
