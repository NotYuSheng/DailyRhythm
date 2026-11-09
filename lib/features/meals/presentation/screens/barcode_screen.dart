import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a packaged food's barcode with the camera and returns its digits.
/// Where there's no camera scanning (desktop) or a code won't read, the
/// number can be typed instead.
class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  /// Whether this device can scan with its camera.
  static bool get canScan => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _typed = TextEditingController();
  late final _scanner = BarcodeScreen.canScan
      ? MobileScannerController(formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE])
      : null;
  var _done = false;

  @override
  void dispose() {
    _typed.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done) return;
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return;
    _done = true;
    HapticFeedback.selectionClick();
    Navigator.pop(context, digits);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanner = _scanner;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a barcode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (scanner != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: MobileScanner(
                  controller: scanner,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      if (b.rawValue case final code?) _finish(code);
                    }
                  },
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera access is off. Allow it in the phone’s settings, or type the number below.'
                            : 'The camera couldn’t start. Type the number below instead.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Point the camera at the barcode on the pack.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _typed,
            keyboardType: TextInputType.number,
            autofocus: scanner == null,
            decoration: const InputDecoration(labelText: 'Or type the number under the barcode', hintText: '8 to 14 digits'),
            onSubmitted: _finish,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _finish(_typed.text), child: const Text('Look it up')),
          const SizedBox(height: 12),
          Text('Only the barcode number is sent to Open Food Facts.', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
