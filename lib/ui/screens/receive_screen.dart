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
      appBar: zentraAppBar(context, title: 'Receive ZTRA'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: ZentraTheme.gradientCard(),
              child: const Text(
                'Share this address or QR code to receive Zentra (ZTRA). Only send ZTRA on the correct network.',
                style: TextStyle(color: ZentraTheme.textMuted, fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),
            if (address.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ZentraTheme.radiusXl),
                    border: Border.all(color: ZentraTheme.accent.withValues(alpha: 0.35), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: ZentraTheme.accent.withValues(alpha: 0.12),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: 'zentra:$address',
                    version: QrVersions.auto,
                    size: 220,
                    eyeStyle: const QrEyeStyle(
                      color: ZentraTheme.background,
                      eyeShape: QrEyeShape.circle,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      color: ZentraTheme.background,
                      dataModuleShape: QrDataModuleShape.circle,
                    ),
                  ),
                ),
              )
            else
              const ZentraEmptyState(
                icon: Icons.hourglass_empty_rounded,
                title: 'Address not ready',
                subtitle: 'Wait for sync to finish, or refresh from Home.',
              ),
            const SizedBox(height: 28),
            ZentraCopyField(label: 'Your address', value: address, maxLines: 4),
          ],
        ),
      ),
    );
  }
}
