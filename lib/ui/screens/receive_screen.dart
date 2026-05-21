import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/zentra_ui.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final address = wallet.primaryAddress?.address ?? '';

    return ZentraScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Receive'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Your address',
              style: TextStyle(color: ZentraTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (address.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: ZentraTheme.flatCard(color: Colors.white),
                child: QrImageView(
                  data: 'zentra:$address',
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(color: ZentraTheme.background),
                ),
              ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: ZentraTheme.flatCard(),
              child: SelectableText(
                address.isEmpty ? '—' : address,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: address.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: address));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied')),
                        );
                      },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
