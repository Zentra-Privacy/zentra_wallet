import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/zentra_network.dart';
import '../../providers/wallet_provider.dart';
import 'onboarding_screen.dart';
import 'node_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Network'),
            subtitle: Text(wallet.networkConfig?.label ?? '—'),
            trailing: DropdownButton<ZentraNetType>(
              value: wallet.networkType,
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
                    const SnackBar(
                      content: Text('Network changed — tap Reconnect in Settings'),
                    ),
                  );
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Network node (zentrad)'),
            subtitle: Text(wallet.nodeSettings?.daemonAddress ?? '—'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NodeSetupScreen()),
            ),
          ),
          if (!wallet.nativeAvailable)
            const ListTile(
              leading: Icon(Icons.build, color: Colors.orangeAccent),
              title: Text('Native wallet missing'),
              subtitle: Text('./scripts/build_native_wallet.sh'),
            ),
          ListTile(
            title: const Text('Wallet file'),
            subtitle: Text(wallet.walletFilename ?? '—'),
          ),
          ListTile(
            title: const Text('Reconnect'),
            onTap: () async {
              final ok = await wallet.connect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Connected' : 'Failed')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Open different wallet'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
