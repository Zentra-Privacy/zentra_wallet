import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/zentra_network.dart';
import '../../core/native_wallet_messages.dart';
import '../../providers/wallet_provider.dart' show WalletConnectionState, WalletProvider;
import '../../theme/zentra_theme.dart';
import '../network_ui.dart';
import '../widgets/restore_height_settings_panel.dart';
import '../widgets/zentra_ui.dart';
import 'node_setup_screen.dart';
import 'wallet_backup_screen.dart';
import 'wallets_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    final list = ListView(
      padding: EdgeInsets.only(bottom: ZentraTheme.navBarHeight + MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: ZentraTheme.gradientCard(radius: ZentraTheme.radiusXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ZentraConnectionChip(
                      label: wallet.connectionStatusLabel,
                      isError: wallet.connectionState == WalletConnectionState.error,
                      isSyncing: wallet.showSyncBanner,
                    ),
                    const Spacer(),
                    if (wallet.isRefreshing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.primary),
                      ),
                  ],
                ),
                ZentraWalletStatusBanner(
                  compact: true,
                  errorMessage: zentraStatusErrorMessage(wallet.errorMessage),
                  isConnecting: wallet.isOpeningWallet,
                  isSyncing: wallet.showSyncBanner,
                  syncSubtitle: wallet.syncBannerSubtitle,
                  syncProgress: wallet.syncProgressFraction,
                ),
                if (wallet.primaryAddress != null) ...[
                  const SizedBox(height: 12),
                  ZentraAddressChip(address: wallet.primaryAddress!.address),
                ],
              ],
            ),
          ),
        ),
        ZentraSettingsSection(
          title: 'Wallet',
          children: [
            ZentraSettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallets',
              subtitle: wallet.walletFilename != null
                  ? 'Active: ${wallet.walletFilename}'
                  : 'Switch or add wallets',
              showDivider: true,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalletsScreen()),
                );
              },
            ),
            ZentraSettingsTile(
              icon: Icons.lock_outline,
              title: 'Backup & seed phrase',
              subtitle: wallet.connectionState == WalletConnectionState.connected
                  ? 'View address and seed to copy'
                  : 'Connect wallet first',
              showDivider: false,
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
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: RestoreHeightSettingsPanel(),
        ),
        ZentraSettingsSection(
          title: 'Network',
          children: [
            ZentraSettingsTile(
              icon: Icons.dns_outlined,
              title: 'Node',
              subtitle: NetworkUi.nodeSubtitle(wallet.nodeSettings),
              showDivider: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NodeSetupScreen()),
              ),
            ),
            ZentraSettingsTile(
              icon: Icons.hub_outlined,
              title: 'Network',
              subtitle: wallet.networkConfig?.label ?? 'Mainnet',
              showDivider: !wallet.nativeAvailable,
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<ZentraNetType>(
                  value: wallet.networkType,
                  dropdownColor: ZentraTheme.surfaceContainerHigh,
                  items: ZentraNetType.values
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text(
                            n == ZentraNetType.mainnet
                                ? ZentraNetworkConfig.fromType(n).label
                                : '${ZentraNetworkConfig.fromType(n).label} (soon)',
                            style: TextStyle(
                              color: n == ZentraNetType.mainnet
                                  ? ZentraTheme.textPrimary
                                  : ZentraTheme.textMuted,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null || v == ZentraNetType.mainnet) return;
                    final label = ZentraNetworkConfig.fromType(v).label;
                    zentraSnack(context, '$label — coming soon');
                  },
                ),
              ),
            ),
            if (!wallet.nativeAvailable)
              const ZentraSettingsTile(
                icon: Icons.build_outlined,
                title: NativeWalletMessages.title,
                subtitle: NativeWalletMessages.subtitle,
                showDivider: false,
              ),
          ],
        ),
        ZentraSettingsSection(
          title: 'App',
          children: [
            ZentraSettingsTile(
              icon: Icons.refresh_rounded,
              title: 'Reconnect',
              subtitle: 'Sync with daemon again',
              showDivider: false,
              onTap: () async {
                final ok = await wallet.connect();
                if (context.mounted) {
                  zentraSnack(
                    context,
                    ok ? 'Connected to node' : wallet.errorMessage ?? 'Reconnect failed',
                    isError: !ok,
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const ZentraLogo(size: 48),
              const SizedBox(height: 12),
              Text(
                'Zentra Wallet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ZentraTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
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

    return ZentraScaffold(
      appBar: zentraAppBar(context, title: 'Settings'),
      body: list,
    );
  }
}
