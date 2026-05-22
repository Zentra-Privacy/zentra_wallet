import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../../core/native_wallet_messages.dart';
import '../../core/network/zentra_network.dart';
import '../../models/wallet_backup_info.dart';
import '../../core/restore_height_utils.dart';
import '../../core/seed_utils.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/restore_height_field.dart';
import '../widgets/zentra_ui.dart';
import 'home_screen.dart';
import 'node_setup_screen.dart';
import 'wallet_backup_screen.dart';

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
  bool _hidePassword = true;

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
    if (_password.text.length < 8) {
      _snack('Use at least 8 characters for your wallet password', error: true);
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
      _snack(NativeWalletMessages.detail, error: true);
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
      final isNewWallet = !_openMode && !_restoreMode;
      if (isNewWallet) {
        final backup = await p.fetchBackupInfo();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WalletBackupScreen(
              backup: backup ??
                  WalletBackupInfo(
                    address: p.primaryAddress?.address ?? '',
                    walletName: _filename.text.trim(),
                  ),
            ),
          ),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _snack(p.errorMessage ?? 'Wallet setup failed');
    }
  }

  void _snack(String msg, {bool error = false}) {
    zentraSnack(context, msg, isError: error);
  }

  void _goCreate() {
    setState(() {
      _restoreMode = false;
      _openMode = false;
      _step = 1; // wallet step (mainnet only)
    });
  }

  void _goRestore() {
    setState(() {
      _restoreMode = true;
      _openMode = false;
      _step = 1; // wallet step (mainnet only)
    });
  }

  @override
  Widget build(BuildContext context) {
    return ZentraGradientScaffold(
      appBar: _step > 0
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 0),
              ),
              title: const Text('Your wallet'),
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

  Widget _walletStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          _restoreMode ? 'Restore wallet' : 'Create wallet',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mainnet · sync uses public seed nodes',
          style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
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
                  obscureText: _hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Wallet password',
                    helperText: 'Encrypts your wallet file on this device',
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
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
