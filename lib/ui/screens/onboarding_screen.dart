import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../../core/network/zentra_network.dart';
import '../../core/restore_height_utils.dart';
import '../../core/seed_utils.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/restore_height_field.dart';
import '../widgets/zentra_ui.dart';
import 'home_screen.dart';
import 'node_setup_screen.dart';

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
  final _restoreHeight = TextEditingController();
  bool _loading = false;
  bool _restoreMode = false;
  bool _openMode = false;
  bool _customRestoreHeight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = context.read<WalletProvider>().defaultRestoreHeight;
      if (h > 0) {
        setState(() {
          _customRestoreHeight = true;
          _restoreHeight.text = RestoreHeightUtils.format(h);
        });
      }
    });
  }

  @override
  void dispose() {
    _filename.dispose();
    _password.dispose();
    _seed.dispose();
    _restoreHeight.dispose();
    super.dispose();
  }

  int? _resolveRestoreHeight() {
    return RestoreHeightField.resolveHeight(
      enabled: _customRestoreHeight && !_openMode,
      controller: _restoreHeight,
    );
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
    if (_restoreMode && !SeedUtils.isValidWordCount(_seed.text)) {
      _snack('Seed must be 12, 13, 24, or 25 words');
      return;
    }
    final height = _resolveRestoreHeight();
    if (_customRestoreHeight && !_openMode && height == null) {
      _snack('Enter a valid block height');
      return;
    }
    final p = context.read<WalletProvider>();
    if (!ZentraNativeWallet.isAvailable) {
      _snack('Native wallet not built. Run: ./scripts/build_native_wallet.sh');
      return;
    }
    setState(() => _loading = true);
    await p.updateNetwork(_network);
    final syncHeight = _openMode ? null : (height ?? 0);
    final ok = _openMode
        ? await p.openExistingWallet(
            filename: _filename.text.trim(),
            password: _password.text,
          )
        : _restoreMode
            ? await p.restoreFromSeed(
                filename: _filename.text.trim(),
                seed: SeedUtils.normalize(_seed.text),
                password: _password.text,
                restoreHeight: _customRestoreHeight ? syncHeight : null,
              )
            : await p.createNewWallet(
                filename: _filename.text.trim(),
                password: _password.text,
                restoreHeight: _customRestoreHeight ? syncHeight : null,
              );
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
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

  void _goCreate() {
    setState(() {
      _restoreMode = false;
      _openMode = false;
      _step = 1;
    });
  }

  void _goRestore() {
    setState(() {
      _restoreMode = true;
      _openMode = false;
      _step = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ZentraGradientScaffold(
      appBar: _step > 0
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = _step == 2 ? 1 : 0),
              ),
              title: Text(_step == 1 ? 'Network' : 'Your wallet'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.dns_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NodeSetupScreen()),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: switch (_step) {
            0 => _welcomeStep(),
            1 => _networkStep(),
            _ => _walletStep(),
          },
        ),
      ),
    );
  }

  Widget _welcomeStep() {
    return Column(
      children: [
        const Spacer(flex: 2),
        const ZentraLogo(size: 96),
        const SizedBox(height: 28),
        const Text(
          'Zentra Wallet',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Private. Secure. Unstoppable.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZentraTheme.textMuted, fontSize: 15),
        ),
        const Spacer(flex: 3),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _goCreate,
            child: const Text('Create New Wallet'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _goRestore,
            child: const Text('Restore Wallet'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _networkStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          _restoreMode ? 'Restore wallet' : 'Create wallet',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose network. Sync uses remote zentrad (seed nodes on mainnet).',
          style: TextStyle(color: ZentraTheme.textMuted),
        ),
        const SizedBox(height: 20),
        ...ZentraNetType.values.map((n) {
          final cfg = ZentraNetworkConfig.fromType(n);
          final selected = _network == n;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: selected ? ZentraTheme.surface : ZentraTheme.card,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => setState(() => _network = n),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? ZentraTheme.accent : ZentraTheme.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: selected ? ZentraTheme.accent : ZentraTheme.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cfg.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              'Prefix ${cfg.addressPrefix} · :${cfg.daemonRpcPort}',
                              style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        FilledButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('Continue'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _walletStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('New'),
              selected: !_restoreMode && !_openMode,
              onSelected: (_) => setState(() {
                _restoreMode = false;
                _openMode = false;
              }),
            ),
            FilterChip(
              label: const Text('Restore'),
              selected: _restoreMode,
              onSelected: (_) => setState(() {
                _restoreMode = true;
                _openMode = false;
              }),
            ),
            FilterChip(
              label: const Text('Open existing'),
              selected: _openMode,
              onSelected: (_) => setState(() {
                _restoreMode = false;
                _openMode = true;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _filename,
                  decoration: const InputDecoration(labelText: 'Wallet name (on this device)'),
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
                if (!_openMode) ...[
                  const SizedBox(height: 16),
                  RestoreHeightField(
                    enabled: _customRestoreHeight,
                    onEnabledChanged: (v) => setState(() => _customRestoreHeight = v),
                    controller: _restoreHeight,
                    showRestoreHint: _restoreMode,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: ZentraTheme.accent)),
          )
        else
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
        const SizedBox(height: 24),
      ],
    );
  }
}
