import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/zentra_network.dart';
import '../core/network/zentra_public_nodes.dart';
import '../models/wallet_models.dart';

class SettingsStore {
  static const _keyNetwork = 'network';
  static const _keyDaemon = 'daemon_address';
  static const _keyPublicNode = 'public_node_id';
  static const _keyWalletName = 'wallet_filename';
  static const _keyWalletPass = 'wallet_password';
  static const _keyOnboarded = 'onboarded';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<bool> isOnboarded() async {
    final p = await _prefs;
    return p.getBool(_keyOnboarded) ?? false;
  }

  Future<void> setOnboarded(bool value) async {
    final p = await _prefs;
    await p.setBool(_keyOnboarded, value);
  }

  Future<ZentraNetType> loadNetwork() async {
    final p = await _prefs;
    final idx = p.getInt(_keyNetwork) ?? 0;
    return ZentraNetType.values[idx.clamp(0, ZentraNetType.values.length - 1)];
  }

  Future<void> saveNetwork(ZentraNetType type) async {
    final p = await _prefs;
    await p.setInt(_keyNetwork, type.index);
  }

  Future<NodeConnectionSettings> loadNode() async {
    final p = await _prefs;
    final net = await loadNetwork();
    final cfg = ZentraNetworkConfig.fromType(net);

    if (net == ZentraNetType.mainnet) {
      final nodeId = p.getString(_keyPublicNode) ?? ZentraPublicNode.seedPrimary.id;
      final node = ZentraPublicNode.byId(nodeId) ?? ZentraPublicNode.seedPrimary;
      return NodeConnectionSettings(
        daemonAddress: p.getString(_keyDaemon) ?? node.daemonAddress,
        publicNodeId: node.id,
      );
    }

    return NodeConnectionSettings(
      daemonAddress: p.getString(_keyDaemon) ?? '127.0.0.1:${cfg.daemonRpcPort}',
    );
  }

  Future<void> saveNode(NodeConnectionSettings settings) async {
    final p = await _prefs;
    await p.setString(_keyDaemon, settings.daemonAddress);
    if (settings.publicNodeId != null) {
      await p.setString(_keyPublicNode, settings.publicNodeId!);
    } else {
      await p.remove(_keyPublicNode);
    }
  }

  Future<String?> loadWalletFilename() async {
    final p = await _prefs;
    return p.getString(_keyWalletName);
  }

  Future<void> saveWalletFilename(String name) async {
    final p = await _prefs;
    await p.setString(_keyWalletName, name);
  }

  Future<String?> loadWalletPassword() async {
    final p = await _prefs;
    return p.getString(_keyWalletPass);
  }

  Future<void> saveWalletPassword(String password) async {
    final p = await _prefs;
    await p.setString(_keyWalletPass, password);
  }
}
