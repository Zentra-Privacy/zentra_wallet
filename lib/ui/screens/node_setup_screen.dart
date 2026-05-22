import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/rpc_address.dart';
import '../../core/network/zentra_network.dart';
import '../../core/network/zentra_public_nodes.dart';
import '../../models/wallet_models.dart';
import '../../core/native_wallet_messages.dart';
import '../../providers/wallet_provider.dart';

/// Configure remote zentrad (daemon) — wallet keys stay on device.
class NodeSetupScreen extends StatefulWidget {
  const NodeSetupScreen({super.key});

  @override
  State<NodeSetupScreen> createState() => _NodeSetupScreenState();
}

class _NodeSetupScreenState extends State<NodeSetupScreen> {
  final _daemon = TextEditingController();
  String? _selectedNodeId;
  bool _useCustom = false;

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletProvider>();
    final node = wallet.nodeSettings;
    if (node != null) {
      _daemon.text = node.daemonAddress;
      _selectedNodeId = node.publicNodeId;
    }
    if (wallet.networkType == ZentraNetType.mainnet &&
        _selectedNodeId == null &&
        !_useCustom) {
      _applyNode(ZentraPublicNode.seedPrimary);
    }
  }

  void _applyNode(ZentraPublicNode node) {
    _daemon.text = node.daemonAddress;
    _selectedNodeId = node.id;
    _useCustom = false;
  }

  @override
  void dispose() {
    _daemon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final addr = _daemon.text.trim();
    if (RpcAddress.parse(addr) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid daemon address (use host:port)')),
      );
      return;
    }
    final settings = NodeConnectionSettings(
      daemonAddress: addr,
      publicNodeId: _useCustom ? null : _selectedNodeId,
    );
    await context.read<WalletProvider>().updateNode(settings);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final isMainnet = wallet.networkType == ZentraNetType.mainnet;

    return Scaffold(
      appBar: AppBar(title: const Text('Network node (zentrad)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Embedded wallet — like Monero/Cake Wallet. Keys stay on this device; '
            'only blockchain sync uses zentrad on the network.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          if (!wallet.nativeAvailable) ...[
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.orangeAccent),
                title: Text(NativeWalletMessages.title),
                subtitle: Text(NativeWalletMessages.subtitle),
              ),
            ),
          ],
          if (isMainnet) ...[
            const SizedBox(height: 16),
            const Text('Mainnet seed nodes', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<String>(
              groupValue: _useCustom ? 'custom' : (_selectedNodeId ?? ''),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  if (v == 'custom') {
                    _useCustom = true;
                  } else {
                    final node = ZentraPublicNode.byId(v);
                    if (node != null) _applyNode(node);
                  }
                });
              },
              child: Column(
                children: [
                  ...ZentraPublicNode.mainnetNodes.map(
                    (node) => RadioListTile<String>(
                      value: node.id,
                      title: Text(node.label),
                      subtitle: Text('Daemon ${node.daemonAddress}'),
                    ),
                  ),
                  const RadioListTile<String>(
                    value: 'custom',
                    title: Text('Custom daemon'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _daemon,
            decoration: const InputDecoration(
              labelText: 'Daemon address (host:port)',
              helperText: 'Mainnet: 185.182.185.127:19081 or 213.136.78.112:19081',
            ),
            onChanged: (_) => setState(() => _useCustom = true),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
