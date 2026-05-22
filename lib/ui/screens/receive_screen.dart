import 'package:flutter/material.dart';
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Receive ZTRA'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share this address or QR code to receive Zentra (ZTRA). Only send ZTRA on the correct network.',
              style: TextStyle(color: ZentraTheme.textMuted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 24),
            if (address.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: ZentraTheme.flatCard(color: Colors.white),
                  child: QrImageView(
                    data: 'zentra:$address',
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(color: ZentraTheme.background),
                  ),
                ),
              )
            else
              const ZentraEmptyState(
                icon: Icons.hourglass_empty,
                title: 'Address loading',
                subtitle: 'Pull to refresh on Home if this takes too long.',
              ),
            const SizedBox(height: 24),
            ZentraCopyField(label: 'Your address', value: address, maxLines: 4),
          ],
        ),
      ),
    );
  }
}
