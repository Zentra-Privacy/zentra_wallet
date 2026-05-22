import '../core/network/zentra_public_nodes.dart';
import '../models/wallet_models.dart';

/// User-facing network/node copy (no raw IPs for public seeds).
abstract final class NetworkUi {
  static String nodeSubtitle(NodeConnectionSettings? settings) {
    if (settings == null) return '—';
    final node = ZentraPublicNode.byId(settings.publicNodeId);
    if (node?.dnsName != null) return node!.dnsName!;
    if (settings.publicNodeId != null) return 'Seed node';
    return 'Custom node';
  }

  static String seedNodeLabel(ZentraPublicNode node) =>
      node.dnsName ?? node.label;
}
