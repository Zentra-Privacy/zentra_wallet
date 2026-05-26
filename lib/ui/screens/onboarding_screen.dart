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
  final ZentraNetType _network = ZentraNetType.mainnet;
  final _filename = TextEditingController(text: 'my_wallet');
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
      _snack('Pick a simple name — no slashes or folder paths');
      return;
    }
    if (_password.text.length < 8) {
      _snack('Password needs at least 8 characters', error: true);
      return;
    }
    if (_restoreMode && !SeedUtils.isValidWordCount(_seed.text)) {
      _snack('Enter your full seed — 12, 13, 24, or 25 words');
      return;
    }
    final height = _resolveRestoreHeight();
    if (_customRestoreHeight && !_openMode && height == null) {
      _snack('Enter a valid block number');
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
      _snack(p.errorMessage ?? 'Something went wrong — please try again');
    }
  }

  void _snack(String msg, {bool error = false}) {
    zentraSnack(context, msg, isError: error);
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

  String get _walletModeTitle {
    if (_openMode) return 'Open your wallet';
    if (_restoreMode) return 'Restore your wallet';
    return 'Create your wallet';
  }

  String get _walletModeSubtitle {
    if (_openMode) {
      return 'Unlock a wallet already saved on this device.';
    }
    if (_restoreMode) {
      return 'Use your seed phrase to recover funds on this device.';
    }
    return 'A new wallet will be created and encrypted on this device.';
  }

  String get _primaryButtonLabel {
    if (_openMode) return 'Open wallet';
    if (_restoreMode) return 'Restore wallet';
    return 'Create wallet';
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your wallet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Text(
                    'Step 2 of 2',
                    style: TextStyle(
                      fontSize: 12,
                      color: ZentraTheme.textMuted.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.dns_outlined),
                  tooltip: 'Node settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NodeSetupScreen()),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        const Center(child: ZentraLogo(size: 88)),
        const SizedBox(height: 24),
        const Text(
          'Zentra Wallet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your keys stay on this device.\nOnly you control your ZTRA.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZentraTheme.textMuted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 28),
        _WelcomeFeatureRow(
          items: const [
            _WelcomeFeature(Icons.lock_outline, 'Encrypted'),
            _WelcomeFeature(Icons.phone_android_outlined, 'On device'),
            _WelcomeFeature(Icons.visibility_off_outlined, 'Private'),
          ],
        ),
        const Spacer(flex: 3),
        FilledButton.icon(
          onPressed: _goCreate,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text('Create new wallet'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _goRestore,
          icon: const Icon(Icons.history, size: 20),
          label: const Text('I already have a wallet'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _restoreMode = false;
            _openMode = true;
            _step = 1;
          }),
          child: const Text('Open wallet saved on this device'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _walletStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          _walletModeTitle,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.2),
        ),
        const SizedBox(height: 6),
        Text(
          _walletModeSubtitle,
          style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ZentraTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ZentraTheme.success.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public, size: 14, color: ZentraTheme.success),
                  SizedBox(width: 6),
                  Text(
                    'Mainnet',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZentraTheme.success),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Syncs via public nodes',
                style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ZentraChoiceCard(
                compact: true,
                icon: Icons.add_circle_outline,
                title: 'New',
                selected: !_restoreMode && !_openMode,
                onTap: () => setState(() {
                  _restoreMode = false;
                  _openMode = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ZentraChoiceCard(
                compact: true,
                icon: Icons.history,
                title: 'Restore',
                selected: _restoreMode,
                onTap: () => setState(() {
                  _restoreMode = true;
                  _openMode = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ZentraChoiceCard(
                compact: true,
                icon: Icons.folder_open_outlined,
                title: 'Open',
                selected: _openMode,
                onTap: () => setState(() {
                  _restoreMode = false;
                  _openMode = true;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Wallet details',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ZentraFormCard(
                  children: [
                    TextField(
                      controller: _filename,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        labelText: 'Wallet name',
                        hintText: 'e.g. my_zentra',
                        prefixIcon: Icon(Icons.label_outline, size: 20),
                        helperText: 'How this wallet appears on your device',
                      ),
                    ),
                    TextField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'At least 8 characters',
                        prefixIcon: const Icon(Icons.key_outlined, size: 20),
                        helperText: 'Encrypts your wallet file — do not lose it',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                    ),
                    if (_restoreMode && !_openMode)
                      TextField(
                        controller: _seed,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Seed phrase',
                          hintText: 'Paste your 12 or 25 words here',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 48),
                            child: Icon(Icons.format_quote_outlined, size: 20),
                          ),
                          helperText: 'Never share this with anyone',
                        ),
                      ),
                  ],
                ),
                if (!_openMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: ZentraTheme.flatCard(color: ZentraTheme.surface),
                    child: RestoreHeightField(
                      enabled: _customRestoreHeight,
                      onEnabledChanged: (v) => setState(() => _customRestoreHeight = v),
                      controller: _restoreHeight,
                      showRestoreHint: _restoreMode,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.accent),
                ),
                SizedBox(width: 12),
                Text('Setting up your wallet…', style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13)),
              ],
            ),
          )
        else
          FilledButton(
            onPressed: _finishCreate,
            child: Text(_primaryButtonLabel),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _WelcomeFeature {
  const _WelcomeFeature(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _WelcomeFeatureRow extends StatelessWidget {
  const _WelcomeFeatureRow({required this.items});

  final List<_WelcomeFeature> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: ZentraTheme.flatCard(color: ZentraTheme.surface, radius: ZentraTheme.radiusSm),
              child: Column(
                children: [
                  Icon(items[i].icon, size: 18, color: ZentraTheme.accent),
                  const SizedBox(height: 6),
                  Text(
                    items[i].label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ZentraTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
