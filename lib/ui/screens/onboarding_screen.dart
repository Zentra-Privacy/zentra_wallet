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
  List<String> _localWallets = [];
  bool _loadingWallets = false;
  String? _selectedLocalWallet;

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
      enabled: _restoreMode && _customRestoreHeight,
      controller: _restoreHeight,
    );
  }

  void _selectNewWallet() {
    setState(() {
      _restoreMode = false;
      _openMode = false;
      _customRestoreHeight = false;
    });
  }

  void _selectRestoreWallet() {
    setState(() {
      _restoreMode = true;
      _openMode = false;
      _customRestoreHeight = true;
    });
  }

  void _selectOpenWallet() {
    setState(() {
      _restoreMode = false;
      _openMode = true;
      _customRestoreHeight = false;
    });
    _refreshLocalWallets();
  }

  Future<void> _refreshLocalWallets() async {
    setState(() => _loadingWallets = true);
    final provider = context.read<WalletProvider>();
    final list = await provider.listLocalWalletFilenames();
    if (!mounted) return;
    final last = provider.walletFilename;
    String? pick;
    if (list.isNotEmpty) {
      pick = (last != null && list.contains(last)) ? last : list.first;
    }
    setState(() {
      _localWallets = list;
      _loadingWallets = false;
      _selectedLocalWallet = pick;
    });
  }

  Future<void> _finishCreate() async {
    final name = _openMode ? (_selectedLocalWallet?.trim() ?? '') : _filename.text.trim();
    if (_openMode) {
      if (_localWallets.isEmpty) {
        _snack('No wallets on this device — create or restore first', error: true);
        return;
      }
      if (name.isEmpty || !_localWallets.contains(name)) {
        _snack('Select a wallet', error: true);
        return;
      }
      if (_password.text.isEmpty) {
        _snack('Enter your wallet password', error: true);
        return;
      }
    } else {
      if (name.isEmpty || name.contains('/') || name.contains('\\')) {
        _snack('Pick a simple name — no slashes or folder paths');
        return;
      }
      if (_password.text.length < 8) {
        _snack('Password needs at least 8 characters', error: true);
        return;
      }
    }
    if (_restoreMode && !SeedUtils.isValidWordCount(_seed.text)) {
      _snack('Enter your full seed — 12, 13, 24, or 25 words');
      return;
    }
    final height = _resolveRestoreHeight();
    if (_restoreMode && _customRestoreHeight && height == null) {
      _snack('Enter a valid block number');
      return;
    }
    final p = context.read<WalletProvider>();
    if (!ZentraNativeWallet.isAvailable) {
      _snack(NativeWalletMessages.detail, error: true);
      return;
    }
    setState(() => _loading = true);
    var ok = false;
    try {
      await p.updateNetwork(_network);
      final syncHeight = height ?? 0;
      ok = _openMode
          ? await p.openExistingWallet(
              filename: name,
              password: _password.text,
            )
          : _restoreMode
              ? await p.restoreFromSeed(
                  filename: name,
                  seed: SeedUtils.normalize(_seed.text),
                  password: _password.text,
                  restoreHeight: _customRestoreHeight ? syncHeight : null,
                )
              : await p.createNewWallet(
                  filename: name,
                  password: _password.text,
                );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    if (ok) {
      if (!mounted) return;
      final isNewWallet = !_openMode && !_restoreMode;
      final savedName = p.walletFilename ?? name;
      if (!_openMode && savedName != name) {
        _snack('Wallet saved as "$savedName" — that name was already in use');
      }
      if (isNewWallet) {
        final backup = await p.fetchBackupInfo();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WalletBackupScreen(
              backup: backup ??
                  WalletBackupInfo(
                    address: p.primaryAddress?.address ?? '',
                    walletName: savedName,
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

  String get _walletAppBarTitle {
    if (_openMode) return 'Open wallet';
    if (_restoreMode) return 'Restore wallet';
    return 'Create wallet';
  }

  String get _primaryButtonLabel {
    if (_openMode) return 'Open';
    if (_restoreMode) return 'Restore';
    return 'Create';
  }

  String get _loadingButtonLabel {
    if (_openMode) return 'Opening wallet…';
    if (_restoreMode) return 'Restoring wallet…';
    return 'Creating wallet…';
  }

  @override
  Widget build(BuildContext context) {
    return ZentraGradientScaffold(
      appBar: _step > 0
          ? AppBar(
              backgroundColor: ZentraTheme.background,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _loading ? null : () => setState(() => _step = 0),
              ),
              title: Text(_walletAppBarTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.dns_outlined),
                  tooltip: 'Node',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NodeSetupScreen()),
                  ),
                ),
              ],
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: switch (_step) {
          0 => _welcomeStep(),
          _ => _walletStep(),
        },
      ),
    );
  }

  Widget _welcomeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  ZentraTheme.accent.withValues(alpha: 0.2),
                  ZentraTheme.card,
                ],
              ),
              border: Border.all(color: ZentraTheme.accent.withValues(alpha: 0.35)),
            ),
            child: const ZentraLogo(size: 72),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Zentra Wallet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your keys stay on this device.\nOnly you control your ZTRA.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZentraTheme.textMuted, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 28),
        _WelcomeFeatureRow(
          items: const [
            _WelcomeFeature(Icons.lock_outline_rounded, 'Encrypted'),
            _WelcomeFeature(Icons.phone_android_rounded, 'On device'),
            _WelcomeFeature(Icons.visibility_off_rounded, 'Private'),
          ],
        ),
        const Spacer(flex: 3),
        FilledButton(
          onPressed: _goCreate,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 20),
              SizedBox(width: 8),
              Text('Create new wallet'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _goRestore,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 20),
              SizedBox(width: 8),
              Text('I already have a wallet'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() => _step = 1);
            _selectOpenWallet();
          },
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
        const SizedBox(height: 8),
        Opacity(
          opacity: _loading ? 0.55 : 1,
          child: Row(
            children: [
              Expanded(
                child: ZentraChoiceCard(
                  compact: true,
                  icon: Icons.add_circle_outline,
                  title: 'New',
                  selected: !_restoreMode && !_openMode,
                  enabled: !_loading,
                  onTap: _selectNewWallet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ZentraChoiceCard(
                  compact: true,
                  icon: Icons.history,
                  title: 'Restore',
                  selected: _restoreMode,
                  enabled: !_loading,
                  onTap: _selectRestoreWallet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ZentraChoiceCard(
                  compact: true,
                  icon: Icons.folder_open_outlined,
                  title: 'Open',
                  selected: _openMode,
                  enabled: !_loading,
                  onTap: _selectOpenWallet,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: AbsorbPointer(
            absorbing: _loading,
            child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ZentraFormCard(
                  children: [
                    if (_openMode) ...[
                      if (_loadingWallets)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.accent),
                            ),
                          ),
                        )
                      else if (_localWallets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No wallets on this device yet.',
                            style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedLocalWallet),
                          initialValue: _selectedLocalWallet,
                          decoration: const InputDecoration(
                            labelText: 'Wallet',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                          ),
                          dropdownColor: ZentraTheme.card,
                          items: _localWallets
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w,
                                  child: Text(w, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedLocalWallet = v),
                        ),
                    ] else
                      TextField(
                        controller: _filename,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'my_wallet',
                          prefixIcon: Icon(Icons.label_outline, size: 20),
                        ),
                      ),
                    TextField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: _openMode ? 'Wallet password' : '8+ characters',
                        prefixIcon: const Icon(Icons.key_outlined, size: 20),
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
                          labelText: 'Seed',
                          hintText: '12 or 25 words',
                          alignLabelWithHint: true,
                        ),
                      ),
                  ],
                ),
                if (!_restoreMode && !_openMode) ...[
                  const SizedBox(height: 12),
                  const _NewWalletSyncNote(),
                ],
                if (_restoreMode) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: ZentraTheme.flatCard(color: ZentraTheme.surface),
                    child: RestoreHeightField(
                      compact: true,
                      restoreOnly: true,
                      enabled: _customRestoreHeight,
                      onEnabledChanged: (v) => setState(() => _customRestoreHeight = v),
                      controller: _restoreHeight,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 8),
          _WalletLoadingBanner(message: _loadingButtonLabel),
        ],
        const SizedBox(height: 8),
        ZentraLoadingButton(
          label: _primaryButtonLabel,
          loadingLabel: _loadingButtonLabel,
          loading: _loading,
          onPressed: _finishCreate,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _WalletLoadingBanner extends StatelessWidget {
  const _WalletLoadingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ZentraTheme.flatCard(color: ZentraTheme.surface),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: ZentraTheme.textMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewWalletSyncNote extends StatelessWidget {
  const _NewWalletSyncNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: ZentraTheme.flatCard(color: ZentraTheme.surface),
      child: const Row(
        children: [
          Icon(Icons.bolt_outlined, size: 20, color: ZentraTheme.accent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sync starts from the latest block automatically.',
              style: TextStyle(fontSize: 13, color: ZentraTheme.textMuted, height: 1.35),
            ),
          ),
        ],
      ),
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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: ZentraTheme.gradientCard(radius: ZentraTheme.radiusLg),
              child: Column(
                children: [
                  Icon(items[i].icon, size: 20, color: ZentraTheme.primary),
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
