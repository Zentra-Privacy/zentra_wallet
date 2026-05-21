import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/wallet_backup_info.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/zentra_ui.dart';
import 'home_screen.dart';

/// Shows address + seed after wallet create so the user can copy and store offline.
class WalletBackupScreen extends StatefulWidget {
  const WalletBackupScreen({
    super.key,
    required this.backup,
    this.requireSeedAcknowledgement = true,
    this.blockBack = true,
  });

  final WalletBackupInfo backup;
  final bool requireSeedAcknowledgement;
  /// True after create (no back). False when opened from Settings.
  final bool blockBack;

  @override
  State<WalletBackupScreen> createState() => _WalletBackupScreenState();
}

class _WalletBackupScreenState extends State<WalletBackupScreen> {
  bool _seedSaved = false;
  bool _seedVisible = false;

  static String _formatSeed(String seed) {
    final words = seed.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    for (var i = 0; i < words.length; i += 5) {
      final chunk = words.skip(i).take(5).toList();
      final parts = <String>[];
      for (var j = 0; j < chunk.length; j++) {
        parts.add('${i + j + 1}. ${chunk[j]}');
      }
      lines.add(parts.join('  '));
    }
    return lines.join('\n');
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  bool get _canContinue {
    if (!widget.requireSeedAcknowledgement || !widget.backup.hasSeed) {
      return true;
    }
    return _seedSaved;
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final backup = widget.backup;

    return ZentraScaffold(
      appBar: AppBar(
        title: const Text('Backup your wallet'),
        automaticallyImplyLeading: !widget.blockBack,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ZentraTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ZentraTheme.radiusMd),
              border: Border.all(color: ZentraTheme.danger.withValues(alpha: 0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: ZentraTheme.danger, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Write down your seed phrase and store it offline. Anyone with the seed controls your funds. '
                    'Zentra Wallet cannot recover a lost seed.',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Wallet: ${backup.walletName}',
            style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _BackupSection(
            label: 'Public address',
            value: backup.address,
            onCopy: () => _copy('Address', backup.address),
          ),
          if (backup.hasSeed) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seed phrase (25 words)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _seedVisible = !_seedVisible),
                  icon: Icon(_seedVisible ? Icons.visibility_off : Icons.visibility, size: 18),
                  label: Text(_seedVisible ? 'Hide' : 'Show'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _BackupSection(
              label: 'Seed phrase',
              value: _seedVisible
                  ? _formatSeed(backup.seedPhrase!)
                  : '••••••••  (tap Show to reveal)',
              onCopy: _seedVisible ? () => _copy('Seed phrase', backup.seedPhrase!) : null,
              selectable: _seedVisible,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _seedSaved,
              onChanged: (v) => setState(() => _seedSaved = v ?? false),
              title: const Text(
                'I have saved my seed phrase offline',
                style: TextStyle(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _canContinue ? _goHome : null,
            child: Text(backup.hasSeed ? 'Continue to wallet' : 'Open wallet'),
          ),
        ],
      ),
    );
  }
}

class _BackupSection extends StatelessWidget {
  const _BackupSection({
    required this.label,
    required this.value,
    this.onCopy,
    this.selectable = true,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: ZentraTheme.flatCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              selectable
                  ? SelectableText(value, style: const TextStyle(fontSize: 13, height: 1.5))
                  : Text(value, style: const TextStyle(fontSize: 13, height: 1.5, color: ZentraTheme.textMuted)),
              if (onCopy != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
