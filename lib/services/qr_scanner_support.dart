import 'dart:io';

import 'package:flutter/foundation.dart';

/// Platform capabilities for QR scanning (camera vs image file).
abstract final class QrScannerSupport {
  static bool get isWeb => kIsWeb;

  /// Live camera preview (mobile_scanner).
  static bool get hasLiveCamera {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Decode QR from an image file (desktop + fallback).
  static bool get hasImageDecode => !kIsWeb;
}
