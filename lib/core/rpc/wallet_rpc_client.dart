import 'dart:convert';

import 'package:http/http.dart' as http;

class WalletRpcException implements Exception {
  WalletRpcException(this.message, {this.code});
  final String message;
  final int? code;
  @override
  String toString() => 'WalletRpcException($message${code != null ? ', code=$code' : ''})';
}

class WalletRpcClient {
  WalletRpcClient({
    required this.host,
    required this.port,
    this.username,
    this.password,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String host;
  final int port;
  final String? username;
  final String? password;
  final http.Client _http;

  Uri get _uri => Uri.parse('http://$host:$port/json_rpc');

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (username != null && password != null) {
      final cred = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $cred';
    }
    return headers;
  }

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
    final response = await _http.post(_uri, headers: _headers, body: body);
    if (response.statusCode != 200) {
      throw WalletRpcException('HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      final err = decoded['error'] as Map<String, dynamic>;
      throw WalletRpcException(
        err['message']?.toString() ?? 'RPC error',
        code: err['code'] as int?,
      );
    }
    return decoded['result'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getBalance({bool allAccounts = true}) => call(
        'get_balance',
        params: {'all_accounts': allAccounts},
      );

  Future<Map<String, dynamic>> getAddress({int accountIndex = 0}) => call(
        'get_address',
        params: {'account_index': accountIndex},
      );

  Future<Map<String, dynamic>> getHeight() => call('get_height');

  Future<Map<String, dynamic>> getTransfers({
    bool incoming = true,
    bool outgoing = true,
    bool pending = true,
    bool pool = true,
  }) =>
      call('get_transfers', params: {
        'in': incoming,
        'out': outgoing,
        'pending': pending,
        'pool': pool,
        'failed': true,
      });

  Future<Map<String, dynamic>> createWallet({
    required String filename,
    required String password,
    String language = 'English',
  }) =>
      call('create_wallet', params: {
        'filename': filename,
        'password': password,
        'language': language,
      });

  Future<Map<String, dynamic>> openWallet({
    required String filename,
    required String password,
  }) =>
      call('open_wallet', params: {
        'filename': filename,
        'password': password,
      });

  Future<Map<String, dynamic>> restoreDeterministicWallet({
    required String filename,
    required String seed,
    required String password,
    int restoreHeight = 0,
    String language = 'English',
  }) =>
      call('restore_deterministic_wallet', params: {
        'filename': filename,
        'seed': seed,
        'password': password,
        'restore_height': restoreHeight,
        'language': language,
      });

  Future<Map<String, dynamic>> transfer({
    required String address,
    required int amountAtomic,
    int priority = 1,
  }) =>
      call('transfer', params: {
        'destinations': [
          {'address': address, 'amount': amountAtomic},
        ],
        'priority': priority,
        'ring_size': 16,
        'get_tx_key': true,
      });

  Future<Map<String, dynamic>> store() => call('store');

  Future<Map<String, dynamic>> closeWallet() => call('close_wallet');

  void dispose() => _http.close();
}
