import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}
class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _alreadyScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR / Barcode')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) async {
              if (_alreadyScanned) return;

              final barcode = capture.barcodes.first;
              final String? value = barcode.rawValue;

              if (value != null && value.isNotEmpty) {
                _alreadyScanned = true;

                // ⛔ STOP kamera biar tidak scan lagi
                await _controller.stop();

                // kasih delay sedikit biar aman
                await Future.delayed(const Duration(milliseconds: 200));

                if (mounted) {
                  Navigator.pop(context, value);
                }
              }
            },
          ),

          // === Overlay Fokus ===
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // === Area Gelap ===
          _ScannerOverlay(),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScannerOverlayPainter(),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final holeSize = 250.0;
    final holeRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: holeSize,
      height: holeSize,
    );

    final holeRRect = RRect.fromRectAndRadius(
      holeRect,
      const Radius.circular(12),
    );

    // 🔑 INI YANG KURANG: saveLayer dulu
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // Gambar layer gelap
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      overlayPaint,
    );

    // Lubangi bagian tengah (benar-benar transparan)
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(holeRRect, clearPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


