import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../services/settings_store.dart';
import '../../theme/zentra_theme.dart';
import '../widgets/zentra_ui.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _status;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final provider = context.read<WalletProvider>();
    try {
      setState(() => _status = 'Loading wallet…');
      await provider.initialize();
      if (!mounted) return;

      final onboarded = await SettingsStore().isOnboarded();
      if (!onboarded || !provider.nativeAvailable) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      setState(() => _status = 'Syncing with network…');
      final ok = await provider.connect().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          provider.markConnectFailed(
            'Sync timed out. Check node in Settings.',
          );
          return false;
        },
      );
      if (!mounted) return;
      if (ok) {
        try {
          await provider.refresh().timeout(const Duration(seconds: 20));
        } on TimeoutException {
          provider.errorMessage = provider.errorMessage ??
              'Refresh timed out. Pull down on Home to retry.';
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('Splash boot error: $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZentraGradientScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZentraLogo(size: 88),
            const SizedBox(height: 28),
            const Text(
              'Zentra Wallet',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Private. Secure. Unstoppable.',
              style: TextStyle(color: ZentraTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: ZentraTheme.accent),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, style: const TextStyle(color: ZentraTheme.textMuted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
