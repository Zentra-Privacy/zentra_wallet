import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/wallet_provider.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final address = wallet.primaryAddress?.address ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Receive ZTR')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (address.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: 'zentra:$address',
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(color: Color(0xFF0F1419)),
                ),
              ),
            const SizedBox(height: 24),
            SelectableText(
              address,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: address.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: address));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied')),
                      );
                    },
              icon: const Icon(Icons.copy),
              label: const Text('Copy address'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Share this address to receive ZTR on the selected network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
