import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/zentra_network.dart';
import '../../core/network/zentra_public_nodes.dart';
import '../../models/wallet_models.dart';
import '../../providers/wallet_provider.dart';

class RpcSetupScreen extends StatefulWidget {
  const RpcSetupScreen({super.key});

  @override
  State<RpcSetupScreen> createState() => _RpcSetupScreenState();
}

class _RpcSetupScreenState extends State<RpcSetupScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _daemon = TextEditingController();

  String? _selectedNodeId;
  bool _useCustom = false;

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletProvider>();
    final rpc = wallet.rpcSettings;
    if (rpc != null) {
      _host.text = rpc.host;
      _port.text = rpc.port.toString();
      _user.text = rpc.username ?? '';
      _pass.text = rpc.password ?? '';
      _daemon.text = rpc.daemonAddress ?? '';
      _selectedNodeId = rpc.publicNodeId;
      _useCustom = rpc.publicNodeId == null &&
          wallet.networkType == ZentraNetType.mainnet;
    } else {
      _port.text = wallet.networkConfig?.defaultWalletRpcPort.toString() ?? '8082';
    }
    if (_selectedNodeId == null &&
        wallet.networkType == ZentraNetType.mainnet &&
        !_useCustom) {
      _selectedNodeId = ZentraPublicNode.seedPrimary.id;
      _applyNode(ZentraPublicNode.seedPrimary);
    }
  }

  void _applyNode(ZentraPublicNode node) {
    _host.text = node.host;
    _port.text = node.walletRpcPort.toString();
    _daemon.text = node.daemonAddress;
    _selectedNodeId = node.id;
    _useCustom = false;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _daemon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null) return;
    final settings = RpcConnectionSettings(
      host: _host.text.trim(),
      port: port,
      username: _user.text.isEmpty ? null : _user.text.trim(),
      password: _pass.text.isEmpty ? null : _pass.text,
      daemonAddress: _daemon.text.isEmpty ? null : _daemon.text.trim(),
      publicNodeId: _useCustom ? null : _selectedNodeId,
    );
    final wallet = context.read<WalletProvider>();
    await wallet.updateRpc(settings);
    await wallet.pingDaemon();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final isMainnet = wallet.networkType == ZentraNetType.mainnet;

    return Scaffold(
      appBar: AppBar(title: const Text('RPC connection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isMainnet) ...[
            const Text(
              'Mainnet VPS nodes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Daemon RPC (zentrad) runs on port 19081 on these seeds. '
              'Wallet-RPC must use the same daemon address when started on the VPS.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            ...ZentraPublicNode.mainnetNodes.map((node) {
              return RadioListTile<String>(
                value: node.id,
                groupValue: _useCustom ? '' : (_selectedNodeId ?? ''),
                title: Text(node.label),
                subtitle: Text(
                  'Daemon ${node.daemonAddress} · Wallet-RPC ${node.host}:${node.walletRpcPort}',
                ),
                onChanged: (_) {
                  setState(() => _applyNode(node));
                },
              );
            }),
            RadioListTile<String>(
              value: 'custom',
              groupValue: _useCustom ? 'custom' : '',
              title: const Text('Custom host'),
              onChanged: (_) => setState(() {
                _useCustom = true;
                _selectedNodeId = null;
              }),
            ),
            const Divider(height: 32),
          ],
          TextField(
            controller: _host,
            decoration: InputDecoration(
              labelText: isMainnet ? 'Wallet-RPC host (VPS IP)' : 'Wallet-RPC host',
            ),
            onChanged: (_) => setState(() => _useCustom = true),
          ),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Wallet-RPC port',
              helperText: isMainnet
                  ? '8082 if zentra-wallet-rpc is exposed on the VPS'
                  : 'Default 8082',
            ),
            onChanged: (_) => setState(() => _useCustom = true),
          ),
          TextField(
            controller: _daemon,
            decoration: const InputDecoration(
              labelText: 'Daemon RPC (zentrad)',
              helperText: 'Mainnet seeds: IP:19081 — used to verify chain sync',
            ),
            onChanged: (_) => setState(() => _useCustom = true),
          ),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'RPC username (optional)'),
          ),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'RPC password (optional)'),
          ),
          if (wallet.daemonStatus != null) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                wallet.daemonStatus!.startsWith('Daemon OK')
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color: wallet.daemonStatus!.startsWith('Daemon OK')
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
              ),
              title: Text(wallet.daemonStatus!),
              subtitle: Text(wallet.rpcSettings?.daemonAddress ?? ''),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.read<WalletProvider>().pingDaemon(),
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Test daemon RPC'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
