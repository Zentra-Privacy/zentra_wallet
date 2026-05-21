import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/zentra_network.dart';
import '../core/network/zentra_public_nodes.dart';
import '../models/wallet_models.dart';

class SettingsStore {
  static const _keyNetwork = 'network';
  static const _keyDaemon = 'daemon_address';
  static const _keyPublicNode = 'public_node_id';
  static const _keyWalletName = 'wallet_filename';
  static const _keyWalletPassLegacy = 'wallet_password';
  static const _keyOnboarded = 'onboarded';
  static const _keyRestoreHeight = 'default_restore_height';
  static const _keyWalletNetwork = 'wallet_network';
  static const _secureWalletPass = 'wallet_password';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

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

  /// Wallet password stored in OS secure storage (migrates legacy SharedPreferences).
  Future<String?> loadWalletPassword() async {
    final secure = await _secureStorage.read(key: _secureWalletPass);
    if (secure != null && secure.isNotEmpty) return secure;

    final p = await _prefs;
    final legacy = p.getString(_keyWalletPassLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: _secureWalletPass, value: legacy);
      await p.remove(_keyWalletPassLegacy);
      return legacy;
    }
    return null;
  }

  Future<void> saveWalletPassword(String password) async {
    await _secureStorage.write(key: _secureWalletPass, value: password);
    final p = await _prefs;
    await p.remove(_keyWalletPassLegacy);
  }

  Future<void> clearWalletPassword() async {
    await _secureStorage.delete(key: _secureWalletPass);
    final p = await _prefs;
    await p.remove(_keyWalletPassLegacy);
  }

  Future<int> loadDefaultRestoreHeight() async {
    final p = await _prefs;
    return p.getInt(_keyRestoreHeight) ?? 0;
  }

  Future<void> saveDefaultRestoreHeight(int height) async {
    final p = await _prefs;
    await p.setInt(_keyRestoreHeight, height.clamp(0, 0x7FFFFFFF));
  }

  Future<ZentraNetType?> loadWalletNetwork() async {
    final p = await _prefs;
    final idx = p.getInt(_keyWalletNetwork);
    if (idx == null) return null;
    return ZentraNetType.values[idx.clamp(0, ZentraNetType.values.length - 1)];
  }

  Future<void> saveWalletNetwork(ZentraNetType type) async {
    final p = await _prefs;
    await p.setInt(_keyWalletNetwork, type.index);
  }
}
