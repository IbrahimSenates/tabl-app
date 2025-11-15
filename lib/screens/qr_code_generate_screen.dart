import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import '../services/auth_service.dart';
import '../services/user_service.dart';

class QRCodeGenerateScreen extends StatefulWidget {
  const QRCodeGenerateScreen({super.key});

  @override
  State<QRCodeGenerateScreen> createState() => _QRCodeGenerateScreenState();
}

class _QRCodeGenerateScreenState extends State<QRCodeGenerateScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  String? _businessId;
  String? _businessName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessInfo();
  }

  Future<void> _loadBusinessInfo() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userData = await _userService.getUserData(user.uid);
      setState(() {
        _businessId = user.uid;
        _businessName = userData?['businessName'] ?? 'İşletme';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String get _qrData {
    if (_businessId == null) return '';
    // QR kod formatı: tablapp://menu/{businessId}
    return 'tablapp://menu/$_businessId';
  }

  Future<void> _shareQRCode() async {
    if (_businessId == null) return;

    try {
      // QR kod görselini oluştur
      final painter = QrPainter(
        data: _qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      // Görseli oluştur
      final picRecorder = ui.PictureRecorder();
      final canvas = Canvas(picRecorder);
      final size = 512.0;
      painter.paint(canvas, Size(size, size));
      final picture = picRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code_$_businessId.png');
      await file.writeAsBytes(pngBytes);

      // Paylaş
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${_businessName ?? "İşletme"} menüsüne erişmek için QR kodu okutun!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paylaşım hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyQRData() async {
    await Clipboard.setData(ClipboardData(text: _qrData));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR kod verisi kopyalandı'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod'),
        actions: [
          if (_businessId != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareQRCode,
              tooltip: 'Paylaş',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _businessId == null
              ? const Center(
                  child: Text('İşletme bilgisi yüklenemedi'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // İşletme bilgisi
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.business,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _businessName ?? 'İşletme',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // QR Kod
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _qrData,
                          version: QrVersions.auto,
                          size: 280.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bilgi metni
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Müşteriler bu QR kodu okutarak menünüze erişebilir',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Butonlar
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyQRData,
                              icon: const Icon(Icons.copy),
                              label: const Text('Kopyala'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareQRCode,
                              icon: const Icon(Icons.share),
                              label: const Text('Paylaş'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // QR kod verisi (gizli)
                      TextButton(
                        onPressed: _copyQRData,
                        child: Text(
                          'QR Kod Verisi: $_qrData',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

