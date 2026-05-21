import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/zentra_network.dart';
import '../../providers/wallet_provider.dart';
import 'home_screen.dart';
import 'rpc_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  ZentraNetType _network = ZentraNetType.mainnet;
  final _filename = TextEditingController(text: 'zentra_mobile');
  final _password = TextEditingController();
  final _seed = TextEditingController();
  bool _loading = false;
  bool _restoreMode = false;
  bool _openMode = false;

  @override
  void dispose() {
    _filename.dispose();
    _password.dispose();
    _seed.dispose();
    super.dispose();
  }

  Future<void> _finishCreate() async {
    final name = _filename.text.trim();
    if (name.isEmpty || name.contains('/') || name.contains('\\')) {
      _snack('Wallet filename must be a simple name (no path separators)');
      return;
    }
    if (_password.text.length < 4) {
      _snack('Password must be at least 4 characters');
      return;
    }
    if (_restoreMode && _seed.text.trim().split(RegExp(r'\s+')).length < 12) {
      _snack('Seed phrase looks too short');
      return;
    }
    setState(() => _loading = true);
    final p = context.read<WalletProvider>();
    await p.updateNetwork(_network);
    if (_network == ZentraNetType.mainnet) {
      await p.pingDaemon();
    }
    final ok = _openMode
        ? await p.openExistingWallet(
            filename: _filename.text.trim(),
            password: _password.text,
          )
        : _restoreMode
            ? await p.restoreFromSeed(
                filename: _filename.text.trim(),
                seed: _seed.text.trim(),
                password: _password.text,
              )
            : await p.createNewWallet(
                filename: _filename.text.trim(),
                password: _password.text,
              );
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      await p.refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _snack(p.errorMessage ?? 'Wallet setup failed');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Zentra Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RpcSetupScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _networkStep() : _walletStep(),
        ),
      ),
    );
  }

  Widget _networkStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose network',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect to zentra-wallet-rpc on the same network as your zentrad node.',
        ),
        const SizedBox(height: 24),
        ...ZentraNetType.values.map((n) {
          final cfg = ZentraNetworkConfig.fromType(n);
          return RadioListTile<ZentraNetType>(
            value: n,
            groupValue: _network,
            title: Text(cfg.label),
            subtitle: Text('Addresses start with ${cfg.addressPrefix} · daemon :${cfg.daemonRpcPort}'),
            onChanged: (v) => setState(() => _network = v!),
          );
        }),
        const Spacer(),
        FilledButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _walletStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('New'),
              selected: !_restoreMode && !_openMode,
              onSelected: (_) => setState(() {
                _restoreMode = false;
                _openMode = false;
              }),
            ),
            ChoiceChip(
              label: const Text('Restore'),
              selected: _restoreMode,
              onSelected: (_) => setState(() {
                _restoreMode = true;
                _openMode = false;
              }),
            ),
            ChoiceChip(
              label: const Text('Open existing'),
              selected: _openMode,
              onSelected: (_) => setState(() {
                _restoreMode = false;
                _openMode = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _filename,
          decoration: const InputDecoration(labelText: 'Wallet filename (on RPC server)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Wallet password'),
        ),
        if (_restoreMode && !_openMode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _seed,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '25-word seed phrase',
              alignLabelWithHint: true,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Requires zentra-wallet-rpc running with --disable-rpc-login (dev) or matching credentials in Settings.',
          style: TextStyle(fontSize: 12, color: Colors.white54),
        ),
        const Spacer(),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading) ...[
          OutlinedButton(
            onPressed: () => setState(() => _step = 0),
            child: const Text('Back'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _finishCreate,
            child: Text(
              _openMode
                  ? 'Open wallet'
                  : _restoreMode
                      ? 'Restore wallet'
                      : 'Create wallet',
            ),
          ),
        ],
      ],
    );
  }
}
