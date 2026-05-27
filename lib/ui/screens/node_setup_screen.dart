import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/qr_payload_parser.dart';
import '../../core/network/rpc_address.dart';
import '../../services/qr_scanner_launcher.dart';
import '../../core/network/zentra_network.dart';
import '../../core/network/zentra_public_nodes.dart';
import '../../core/native_wallet_messages.dart';
import '../../models/wallet_models.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../network_ui.dart';
import '../widgets/zentra_ui.dart';

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
      _useCustom = node.publicNodeId == null;
    } else if (wallet.networkType == ZentraNetType.mainnet) {
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

  Future<void> _scanDaemonQr() async {
    final raw = await QrScannerLauncher.scan(context);
    if (raw == null || !mounted) return;
    final daemon = QrPayloadParser.parseDaemonAddress(raw);
    if (daemon == null) {
      zentraSnack(context, 'QR is not a valid daemon address (use host:port)', isError: true);
      return;
    }
    setState(() {
      _useCustom = true;
      _selectedNodeId = null;
      _daemon.text = daemon;
    });
  }

  Future<void> _save() async {
    final addr = _daemon.text.trim();
    if (RpcAddress.parse(addr) == null) {
      zentraSnack(context, 'Invalid daemon address — use host:port', isError: true);
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

    return ZentraScaffold(
      appBar: zentraAppBar(context, title: 'Network node'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'Your keys stay on this device. Blockchain sync uses a remote zentrad node on the network.',
            style: TextStyle(fontSize: 13, color: ZentraTheme.textMuted, height: 1.45),
          ),
          if (!wallet.nativeAvailable) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: ZentraTheme.flatCard(color: ZentraTheme.surface),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: ZentraTheme.danger, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          NativeWalletMessages.title,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          NativeWalletMessages.subtitle,
                          style: TextStyle(fontSize: 12, color: ZentraTheme.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isMainnet) ...[
            const SizedBox(height: 20),
            const Text('Mainnet nodes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ZentraCard(
              margin: EdgeInsets.zero,
              child: RadioGroup<String>(
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
                      (node) => Material(
                        color: Colors.transparent,
                        child: RadioListTile<String>(
                          value: node.id,
                          title: Text(NetworkUi.seedNodeLabel(node)),
                          subtitle: const Text(
                            'Recommended seed node',
                            style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const Material(
                      color: Colors.transparent,
                      child: RadioListTile<String>(
                        value: 'custom',
                        title: Text('Custom daemon'),
                        subtitle: Text(
                          'Your own zentrad host:port',
                          style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_useCustom) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _daemon,
              decoration: InputDecoration(
                labelText: 'Daemon address (host:port)',
                helperText: 'RPC endpoint of your zentrad instance',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan node QR',
                  onPressed: _scanDaemonQr,
                ),
              ),
              onChanged: (_) => setState(() => _useCustom = true),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save node')),
        ],
      ),
    );
  }
}
