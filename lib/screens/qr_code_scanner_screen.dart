import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'menu_view_screen.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});

  @override
  State<QRCodeScannerScreen> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleQRCode(String? code) {
    if (code == null || _isProcessing) return;

    // QR kod formatını kontrol et: tablapp://menu/{businessId}
    if (!code.startsWith('tablapp://menu/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçersiz QR kod. Lütfen işletme QR kodunu okutun.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Business ID'yi çıkar
    final businessId = code.replaceFirst('tablapp://menu/', '');

    if (businessId.isEmpty) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçersiz QR kod formatı.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Menü görüntüleme ekranına yönlendir
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MenuViewScreen(businessId: businessId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Okut'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Flaş',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Kamera Değiştir',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleQRCode(barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Overlay
          CustomPaint(
            painter: QRScannerOverlay(),
            child: Container(),
          ),
          // Talimat metni
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'QR kodu kare içine hizalayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Dış alanı boya
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Ortadaki kareyi temizle
    final scanArea = 250.0;
    final left = (size.width - scanArea) / 2;
    final top = (size.height - scanArea) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanArea, scanArea);

    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;

    canvas.drawRect(scanRect, clearPaint);

    // Köşe çizgileri
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final cornerLength = 30.0;

    // Sol üst köşe
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      cornerPaint,
    );

    // Sağ üst köşe
    canvas.drawLine(
      Offset(left + scanArea, top),
      Offset(left + scanArea - cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanArea, top),
      Offset(left + scanArea, top + cornerLength),
      cornerPaint,
    );

    // Sol alt köşe
    canvas.drawLine(
      Offset(left, top + scanArea),
      Offset(left + cornerLength, top + scanArea),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanArea),
      Offset(left, top + scanArea - cornerLength),
      cornerPaint,
    );

    // Sağ alt köşe
    canvas.drawLine(
      Offset(left + scanArea, top + scanArea),
      Offset(left + scanArea - cornerLength, top + scanArea),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanArea, top + scanArea),
      Offset(left + scanArea, top + scanArea - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

