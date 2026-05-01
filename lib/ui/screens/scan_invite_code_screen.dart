import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanInviteCodeScreen extends StatefulWidget {
  const ScanInviteCodeScreen({super.key});

  @override
  State<ScanInviteCodeScreen> createState() => _ScanInviteCodeScreenState();
}

class _ScanInviteCodeScreenState extends State<ScanInviteCodeScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      return;
    }
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    _handled = true;
    Navigator.of(context).pop(rawValue.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Invite Code')),
      body: Stack(
        children: <Widget>[
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scan patient invite QR/code',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
