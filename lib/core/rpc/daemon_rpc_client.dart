import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wallet_rpc_client.dart';

/// JSON-RPC client for `zentrad` (daemon), port 19081 on mainnet seeds.
class DaemonRpcClient {
  DaemonRpcClient({
    required this.host,
    required this.port,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String host;
  final int port;
  final http.Client _http;

  Uri get _uri => Uri.parse('http://$host:$port/json_rpc');

  Future<Map<String, dynamic>> call(
    String method, {
    Map<String, dynamic> params = const {},
  }) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': '0',
      'method': method,
      'params': params,
    });
    final response = await _http.post(
      _uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200) {
      throw WalletRpcException('Daemon HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      final err = decoded['error'] as Map<String, dynamic>;
      throw WalletRpcException(
        err['message']?.toString() ?? 'Daemon RPC error',
        code: err['code'] as int?,
      );
    }
    return decoded['result'] as Map<String, dynamic>? ?? {};
  }

  Future<int> getBlockHeight() async {
    final res = await call('get_block_count');
    return (res['count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> getInfo() => call('get_info');

  void dispose() => _http.close();
}
