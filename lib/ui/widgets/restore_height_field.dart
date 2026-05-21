import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/restore_height_utils.dart';
import '../../theme/zentra_theme.dart';

/// Block height for wallet sync (create / restore / settings).
class RestoreHeightField extends StatelessWidget {
  const RestoreHeightField({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.controller,
    this.showRestoreHint = false,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController controller;
  final bool showRestoreHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Custom sync height', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(
            showRestoreHint
                ? 'Block when wallet was first used (restore) or scan start (new)'
                : 'Start blockchain scan from a specific block',
            style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12),
          ),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        if (enabled) ...[
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Block height',
              hintText: 'e.g. 2500000',
              helperText: showRestoreHint
                  ? 'Restore: height when you created this wallet. New: 0 = full chain.'
                  : '0 = scan from genesis. Higher = faster sync if you know your height.',
              helperMaxLines: 3,
            ),
          ),
        ],
      ],
    );
  }

  /// Returns parsed height, or null if custom enabled but invalid.
  static int? resolveHeight({required bool enabled, required TextEditingController controller}) {
    if (!enabled) return 0;
    return RestoreHeightUtils.parse(controller.text);
  }
}
