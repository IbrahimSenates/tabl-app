import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'customer_business_home_screen.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});

  @override
  State<QRCodeScannerScreen> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();
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

    // İşletme ana sayfasına yönlendir
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CustomerBusinessHomeScreen(businessId: businessId),
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null || !mounted) {
        return;
      }

      // Resim dosyasının var olup olmadığını kontrol et
      final file = File(image.path);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seçilen resim bulunamadı.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isProcessing = true;
      });

      // Debug: Dosya yolunu logla
      debugPrint('Selected image path: ${image.path}');
      debugPrint('File exists: ${await file.exists()}');
      debugPrint('File size: ${await file.length()} bytes');

      // Resimden QR kod okut
      // MobileScanner ile resim analiz et (file path kullan)
      try {
        // Dosya yolunu absolute path'e çevir
        final absolutePath = file.absolute.path;
        debugPrint('Absolute path: $absolutePath');
        
        final result = await _controller.analyzeImage(absolutePath);
        
        debugPrint('Analysis result: ${result != null ? "Success" : "Null"}');
        if (result != null) {
          debugPrint('Barcodes found: ${result.barcodes.length}');
        }

        if (!mounted) return;

        if (result != null && result.barcodes.isNotEmpty) {
          final barcode = result.barcodes.first;
          debugPrint('Barcode type: ${barcode.type}');
          debugPrint('Barcode raw value: ${barcode.rawValue}');
          
          if (barcode.rawValue != null) {
            // _isProcessing'i false yap ki _handleQRCode çalışabilsin
            setState(() {
              _isProcessing = false;
            });
            // Kısa bir delay ekle
            await Future.delayed(const Duration(milliseconds: 100));
            _handleQRCode(barcode.rawValue);
            return;
          }
        }
      } catch (analyzeError) {
        debugPrint('Analyze image error: $analyzeError');
        // Alternatif yöntem: Bytes olarak okumayı dene
        try {
          final imageBytes = await file.readAsBytes();
          debugPrint('Trying with bytes, size: ${imageBytes.length}');
          
          // Not: mobile_scanner'ın bazı versiyonlarında bytes desteği olmayabilir
          // Bu durumda hata mesajı göster
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('QR kod analizi başarısız: $analyzeError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (bytesError) {
          debugPrint('Bytes read error: $bytesError');
        }
      }

      // QR kod bulunamadı
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Resimde QR kod bulunamadı. Lütfen geçerli bir QR kod içeren resim seçin.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim seçilirken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      // Debug için log
      debugPrint('Image picker error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Okut'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _isProcessing ? null : _pickImageFromGallery,
            tooltip: 'Galeriden Seç',
          ),
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
          CustomPaint(painter: QRScannerOverlay(), child: Container()),
          // Talimat metni ve butonlar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'QR kodu kare içine hizalayın veya galeriden seçin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Galeriden seç butonu
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeriden QR Kod Seç'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // İşleme göstergesi
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'QR kod okunuyor...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
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
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Ortadaki tarama alanı
    final scanArea = 250.0;
    final left = (size.width - scanArea) / 2;
    final top = (size.height - scanArea) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanArea, scanArea);

    // Path ile dış alanı çiz (orta kareyi exclude et)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

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
