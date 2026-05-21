import '../../models/wallet_models.dart';

/// Mainnet bootstrap nodes from zentra `net_node.inl` / `zentrad.conf.example`.
class ZentraPublicNode {
  const ZentraPublicNode({
    required this.id,
    required this.label,
    required this.host,
    required this.daemonRpcPort,
    this.dnsName,
  });

  final String id;
  final String label;
  final String host;
  final int daemonRpcPort;
  final String? dnsName;

  String get daemonAddress => '$host:$daemonRpcPort';

  NodeConnectionSettings toNodeSettings() => NodeConnectionSettings(
        daemonAddress: daemonAddress,
        publicNodeId: id,
      );

  static const seedPrimary = ZentraPublicNode(
    id: 'seed1',
    label: 'Seed 1 (seed.zentraprivacy.org)',
    host: '185.182.185.127',
    daemonRpcPort: 19081,
    dnsName: 'seed.zentraprivacy.org',
  );

  static const seedSecondary = ZentraPublicNode(
    id: 'seed2',
    label: 'Seed 2 (seed1.zentraprivacy.org)',
    host: '213.136.78.112',
    daemonRpcPort: 19081,
    dnsName: 'seed1.zentraprivacy.org',
  );

  static List<ZentraPublicNode> mainnetNodes = [seedPrimary, seedSecondary];

  static ZentraPublicNode? byId(String? id) {
    if (id == null) return null;
    for (final n in mainnetNodes) {
      if (n.id == id) return n;
    }
    return null;
  }
}
