import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/zentra_network.dart';
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not read wallet backup')),
                    );
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        wallet.connectionState == WalletConnectionState.connected
                            ? 'Network changed — reconnecting'
                            : 'Network changed',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        if (!wallet.nativeAvailable)
          const ZentraSettingsTile(
            icon: Icons.build_outlined,
            title: 'Native wallet missing',
            subtitle: './scripts/build_native_wallet.sh',
          ),
        ZentraSettingsTile(
          icon: Icons.refresh,
          title: 'Reconnect',
          subtitle: 'Sync with daemon again',
          onTap: () async {
            final ok = await wallet.connect();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Connected' : 'Failed')),
              );
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
