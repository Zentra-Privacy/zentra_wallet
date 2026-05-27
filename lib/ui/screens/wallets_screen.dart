import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/local_wallet_info.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/wallet_password_dialog.dart';
import '../widgets/zentra_ui.dart';
import 'onboarding_screen.dart';

/// MetaMask-style account list — switch, create, or import wallets.
class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<LocalWalletInfo> _wallets = [];
  bool _loading = true;
  String? _switchingTo;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final provider = context.read<WalletProvider>();
    final list = await provider.listLocalWallets();
    if (!mounted) return;
    setState(() {
      _wallets = list;
      _loading = false;
    });
  }

  Future<void> _switchWallet(LocalWalletInfo info) async {
    if (info.isActive) return;
    final provider = context.read<WalletProvider>();
    setState(() => _switchingTo = info.filename);

    String? password;
    if (!info.hasStoredPassword) {
      password = await showWalletPasswordDialog(context, walletName: info.filename);
      if (password == null || !mounted) {
        setState(() => _switchingTo = null);
        return;
      }
    }

    var ok = await provider.switchToWallet(
      filename: info.filename,
      password: password,
    );
    if (!ok &&
        mounted &&
        info.hasStoredPassword &&
        provider.errorMessage != null) {
      final retry = await showWalletPasswordDialog(context, walletName: info.filename);
      if (retry != null && mounted) {
        ok = await provider.switchToWallet(
          filename: info.filename,
          password: retry,
        );
      }
    }
    if (!mounted) return;
    setState(() => _switchingTo = null);

    if (ok) {
      zentraSnack(context, 'Switched to ${info.filename}');
      await _reload();
      if (mounted) Navigator.pop(context, true);
    } else {
      zentraSnack(
        context,
        provider.errorMessage ?? 'Could not open wallet',
        isError: true,
      );
    }
  }

  void _addWallet() {
    context.read<WalletProvider>().prepareForNewWalletFlow();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    ).then((_) {
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ZentraScaffold(
      appBar: zentraAppBar(context, title: 'Wallets'),
      body: RefreshIndicator(
        color: ZentraTheme.accent,
        onRefresh: _reload,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(color: ZentraTheme.accent)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      'Your wallets on this device. Tap one to switch — like MetaMask accounts.',
                      style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13, height: 1.45),
                    ),
                  ),
                  if (_wallets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: ZentraEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No wallets yet',
                        subtitle: 'Create a new wallet or restore from seed phrase.',
                      ),
                    )
                  else
                    ZentraCard(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < _wallets.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 72),
                            _WalletListTile(
                              info: _wallets[i],
                              busy: _switchingTo == _wallets[i].filename,
                              onTap: () => _switchWallet(_wallets[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton.icon(
                      onPressed: _addWallet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add wallet'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh list'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WalletListTile extends StatelessWidget {
  const _WalletListTile({
    required this.info,
    required this.busy,
    required this.onTap,
  });

  final LocalWalletInfo info;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = info.isActive
        ? (info.addressPreview != null
            ? '${info.addressPreview} · Active'
            : 'Active')
        : (info.hasStoredPassword
            ? '${info.networkLabel ?? "Mainnet"} · Tap to switch'
            : '${info.networkLabel ?? "Mainnet"} · Password required');

    return ListTile(
      onTap: busy ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: info.isActive
            ? ZentraTheme.accent.withValues(alpha: 0.2)
            : ZentraTheme.surface,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.accent),
              )
            : Icon(
                Icons.account_balance_wallet_outlined,
                color: info.isActive ? ZentraTheme.accent : ZentraTheme.textMuted,
              ),
      ),
      title: Text(
        info.filename,
        style: TextStyle(
          fontWeight: info.isActive ? FontWeight.w600 : FontWeight.w500,
          color: info.isActive ? ZentraTheme.accent : ZentraTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
      ),
      trailing: info.isActive
          ? const Icon(Icons.check_circle, color: ZentraTheme.accent)
          : const Icon(Icons.chevron_right, color: ZentraTheme.textMuted, size: 22),
    );
  }
}
