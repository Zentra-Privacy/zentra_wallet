import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/restore_height_utils.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import 'restore_height_field.dart';

class RestoreHeightSettingsPanel extends StatefulWidget {
  const RestoreHeightSettingsPanel({super.key});

  @override
  State<RestoreHeightSettingsPanel> createState() => _RestoreHeightSettingsPanelState();
}

class _RestoreHeightSettingsPanelState extends State<RestoreHeightSettingsPanel> {
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
      _snack('Enter a valid block height');
      return;
    }
    setState(() => _saving = true);
    await context.read<WalletProvider>().updateDefaultRestoreHeight(height ?? 0);
    setState(() => _saving = false);
    if (mounted) _snack('Default sync height saved');
  }

  Future<void> _applyToWallet() async {
    final height = RestoreHeightField.resolveHeight(
      enabled: _customEnabled,
      controller: _heightController,
    );
    if (_customEnabled && height == null) {
      _snack('Enter a valid block height');
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<WalletProvider>().applyRestoreHeightToOpenWallet(height ?? 0);
    setState(() => _saving = false);
    if (!mounted) return;
    _snack(ok ? 'Applied — resyncing from block ${height ?? 0}' : context.read<WalletProvider>().errorMessage ?? 'Failed');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final canApply = wallet.connectionState == WalletConnectionState.connected && wallet.nativeAvailable;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: ZentraTheme.flatCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.height, size: 20, color: ZentraTheme.textMuted),
              SizedBox(width: 10),
              Text('Restore / sync height', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Default for new wallets and seed restore. Applying to an open wallet triggers a rescan from that block.',
            style: TextStyle(color: ZentraTheme.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          RestoreHeightField(
            enabled: _customEnabled,
            onEnabledChanged: (v) => setState(() => _customEnabled = v),
            controller: _heightController,
            showRestoreHint: true,
          ),
          const SizedBox(height: 12),
          if (_saving)
            const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _saveDefault, child: const Text('Save default')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: canApply ? _applyToWallet : null,
                    child: const Text('Apply to wallet'),
                  ),
                ),
              ],
            ),
          if (!canApply)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Connect a wallet to apply height to the current file.',
                style: TextStyle(color: ZentraTheme.textMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
