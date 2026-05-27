import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/restore_height_utils.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/restore_height_field.dart';
import '../widgets/zentra_ui.dart';

/// Default restore height and apply resync to the open wallet file.
class RestoreSyncHeightScreen extends StatefulWidget {
  const RestoreSyncHeightScreen({super.key});

  @override
  State<RestoreSyncHeightScreen> createState() => _RestoreSyncHeightScreenState();
}

class _RestoreSyncHeightScreenState extends State<RestoreSyncHeightScreen> {
  late final TextEditingController _heightController;
  bool _customEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = context.read<WalletProvider>().defaultRestoreHeight;
      setState(() {
        _customEnabled = h > 0;
        _heightController.text = RestoreHeightUtils.format(h);
      });
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _saveDefault() async {
    final height = RestoreHeightField.resolveHeight(
      enabled: _customEnabled,
      controller: _heightController,
    );
    if (_customEnabled && height == null) {
      zentraSnack(context, 'Enter a valid block height', isError: true);
      return;
    }
    setState(() => _saving = true);
    await context.read<WalletProvider>().updateDefaultRestoreHeight(height ?? 0);
    if (mounted) setState(() => _saving = false);
    if (mounted) zentraSnack(context, 'Default sync height saved');
  }

  Future<void> _applyToWallet() async {
    final height = RestoreHeightField.resolveHeight(
      enabled: _customEnabled,
      controller: _heightController,
    );
    if (_customEnabled && height == null) {
      zentraSnack(context, 'Enter a valid block height', isError: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<WalletProvider>().applyRestoreHeightToOpenWallet(height ?? 0);
    if (mounted) setState(() => _saving = false);
    if (!mounted) return;
    final wallet = context.read<WalletProvider>();
    zentraSnack(
      context,
      ok ? 'Applied — resyncing from block ${height ?? 0}' : wallet.errorMessage ?? 'Failed',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final connected = wallet.connectionState == WalletConnectionState.connected;
    final canApply = connected && wallet.nativeAvailable;

    return ZentraScaffold(
      appBar: zentraAppBar(context, title: 'Restore / sync height'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            connected
                ? 'Wallet file scans from block ${wallet.walletScanHeight} (auto-saved after sync). '
                  'Default below is for new restore or create only.'
                : 'Default for new wallets and seed restore. Scan progress is saved in the wallet file after each sync.',
            style: const TextStyle(fontSize: 13, color: ZentraTheme.textMuted, height: 1.45),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ZentraTheme.flatCard(),
            child: RestoreHeightField(
              enabled: _customEnabled,
              onEnabledChanged: (v) => setState(() => _customEnabled = v),
              controller: _heightController,
              showRestoreHint: true,
            ),
          ),
          const SizedBox(height: 20),
          if (_saving)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: ZentraTheme.primary),
              ),
            )
          else ...[
            FilledButton(
              onPressed: _saveDefault,
              child: const Text('Save default'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: canApply ? _applyToWallet : null,
              child: const Text('Apply to wallet'),
            ),
          ],
          if (!canApply) ...[
            const SizedBox(height: 12),
            Text(
              connected
                  ? 'Native wallet required to apply height to the current file.'
                  : 'Connect a wallet to apply height to the current file.',
              style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
