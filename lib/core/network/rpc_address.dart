/// Parses `host:port` daemon/wallet addresses (IPv4 only).
class RpcAddress {
  const RpcAddress({required this.host, required this.port});

  final String host;
  final int port;

  static RpcAddress? parse(String? address) {
    if (address == null || address.isEmpty) return null;
    final colon = address.lastIndexOf(':');
    if (colon <= 0 || colon >= address.length - 1) return null;
    final host = address.substring(0, colon);
    final port = int.tryParse(address.substring(colon + 1));
    if (host.isEmpty || port == null) return null;
    return RpcAddress(host: host, port: port);
  }
}
