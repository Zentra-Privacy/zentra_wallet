import 'package:zentra_wallet_core/zentra_wallet_core.dart';

enum ZentraNetType { mainnet, testnet, stagenet }

class ZentraNetworkConfig {
  const ZentraNetworkConfig({
    required this.type,
    required this.label,
    required this.daemonRpcPort,
    required this.defaultWalletRpcPort,
    required this.addressPrefix,
  });

  final ZentraNetType type;
  final String label;
  final int daemonRpcPort;
  final int defaultWalletRpcPort;
  final String addressPrefix;

  static List<ZentraNetworkConfig> all() => [
        for (final t in ZentraNetType.values) fromType(t),
      ];

  static ZentraNetworkConfig fromType(ZentraNetType type) {
    final core = ZentraCore.instance;
    final ffiNet = ZentraNetwork.values[type.index];
    return ZentraNetworkConfig(
      type: type,
      label: switch (type) {
        ZentraNetType.mainnet => 'Mainnet',
        ZentraNetType.testnet => 'Testnet',
        ZentraNetType.stagenet => 'Stagenet',
      },
      daemonRpcPort: core.daemonRpcPort(ffiNet),
      defaultWalletRpcPort: core.defaultWalletRpcPort(),
      addressPrefix: core.addressPrefixChar(ffiNet),
    );
  }

  ZentraNetwork get ffiNetwork => ZentraNetwork.values[type.index];
}
