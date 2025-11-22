import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Oturum oluştur veya güncelle
  Future<void> createOrUpdateSession({
    required String businessId,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final user = _auth.currentUser;
      final sessionId = '${businessId}_$deviceId';

      await _firestore.collection('active_sessions').doc(sessionId).set({
        'businessId': businessId,
        'userId': user?.uid, // Kullanıcı giriş yapmışsa ID'si, yoksa null
        'deviceId': deviceId,
        'isActive': true,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(), // İlk oluştuğunda
      }, SetOptions(merge: true)); // merge: true ile varsa günceller, yoksa oluşturur
    } catch (e) {
      print('Oturum oluşturulurken hata: $e');
      throw e; // Hatayı yukarı fırlat ki UI'da gösterebilelim
    }
  }

  // Oturumu sonlandır (Opsiyonel - kullanıcı çıkarken vs. kullanılabilir)
  Future<void> endSession(String businessId) async {
    try {
      final deviceId = await _getDeviceId();
      final sessionId = '${businessId}_$deviceId';

      await _firestore.collection('active_sessions').doc(sessionId).update({
        'isActive': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Oturum sonlandırılırken hata: $e');
    }
  }

  // Cihaz ID'sini al
  Future<String> _getDeviceId() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios_device';
    }
    return 'unknown_device';
  }
}
