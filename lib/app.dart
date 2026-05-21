import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/wallet_provider.dart';
import 'theme/zentra_theme.dart';
import 'ui/screens/splash_screen.dart';

class ZentraWalletApp extends StatelessWidget {
  const ZentraWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WalletProvider(),
      child: MaterialApp(
        title: 'Zentra Wallet',
        debugShowCheckedModeBanner: false,
        theme: ZentraTheme.dark(),
        home: const SplashScreen(),
      ),
    );
  }
}
