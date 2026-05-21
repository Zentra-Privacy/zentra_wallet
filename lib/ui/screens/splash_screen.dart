import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../services/settings_store.dart';
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
      setState(() => _status = 'Loading…');
      await provider.initialize();
      if (!mounted) return;

      final onboarded = await SettingsStore().isOnboarded();
      if (!onboarded) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      if (!provider.nativeAvailable) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }
      setState(() => _status = 'Opening wallet & syncing…');
      final ok = await provider.connect().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          provider.errorMessage =
              'Sync timed out. Check daemon node in Settings.';
          return false;
        },
      );
      if (!mounted) return;
      if (ok) {
        await provider.refresh().timeout(const Duration(seconds: 20));
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e, st) {
      debugPrint('Splash boot error: $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet, size: 72, color: Color(0xFF3DDC97)),
            const SizedBox(height: 24),
            const Text(
              'Zentra Wallet',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Color(0xFF3DDC97)),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
