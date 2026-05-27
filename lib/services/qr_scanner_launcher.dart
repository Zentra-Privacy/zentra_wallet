import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/screens/qr_scanner_screen.dart';
import 'qr_scanner_support.dart';

/// Opens camera or image QR scan depending on platform (Cake-style).
abstract final class QrScannerLauncher {
  static Future<String?> scan(BuildContext context) async {
    if (QrScannerSupport.hasLiveCamera) {
      final granted = await _ensureCameraPermission(context);
      if (!granted) return null;
      if (!context.mounted) return null;
      return Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const QrScannerScreen()),
      );
    }
    if (QrScannerSupport.hasImageDecode) {
      return _scanFromImageFile(context);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR scanning is not available on this platform')),
      );
    }
    return null;
  }

  static Future<bool> _ensureCameraPermission(BuildContext context) async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Camera permission'),
            content: const Text(
              'Allow camera access in system settings to scan QR codes.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Settings')),
            ],
          ),
        );
        if (open == true) {
          await openAppSettings();
        }
      }
      return false;
    }
    status = await Permission.camera.request();
    if (!status.isGranted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan QR codes')),
      );
    }
    return status.isGranted;
  }

  static Future<String?> _scanFromImageFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return null;

    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(path);
      if (capture == null || capture.barcodes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in that image')),
          );
        }
        return null;
      }
      return capture.barcodes.first.rawValue?.trim();
    } finally {
      await controller.dispose();
    }
  }
}
