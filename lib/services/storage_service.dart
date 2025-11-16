import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Galeriden resim seç
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw 'Resim seçilirken hata oluştu: $e';
    }
  }

  /// Kameradan resim çek
  Future<XFile?> takeImage() async {
    return pickImage(source: ImageSource.camera);
  }

  /// Menü öğesi fotoğrafını yükle
  Future<String> uploadMenuItemImage({
    required String businessId,
    required String menuItemId,
    required File imageFile,
  }) async {
    try {
      // Dosyanın var olduğunu kontrol et
      if (!await imageFile.exists()) {
        throw 'Seçilen dosya bulunamadı';
      }

      final fileName = 'menu_items/$businessId/$menuItemId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      
      // Upload task'ı oluştur
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Upload'ı bekle - hata varsa otomatik olarak exception fırlatır
      final snapshot = await uploadTask;
      
      // Upload başarılı değilse hata fırlat
      if (snapshot.state != TaskState.success) {
        throw 'Yükleme tamamlanamadı. Durum: ${snapshot.state}';
      }

      // Download URL'i al
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      // Firebase özel hatalarını işle
      String errorMessage = 'Fotoğraf yüklenirken hata oluştu';
      
      // Hata kodunu kontrol et (hem string hem de numeric kodlar için)
      final errorCode = e.code.toLowerCase();
      final errorMessageText = e.message ?? '';
      
      if (errorCode.contains('object-not-found') || 
          errorCode.contains('not-found') ||
          errorMessageText.contains('404') ||
          errorMessageText.contains('Not Found')) {
        errorMessage = 'Firebase Storage bucket bulunamadı veya erişilemiyor.\n\n'
            'Lütfen şunları kontrol edin:\n'
            '1. Firebase Console\'da Storage\'ı etkinleştirdiğinizden emin olun\n'
            '2. Storage güvenlik kurallarının doğru yapılandırıldığından emin olun\n'
            '3. google-services.json dosyasının güncel olduğundan emin olun';
      } else if (errorCode.contains('unauthorized') || 
                 errorCode.contains('permission-denied')) {
        errorMessage = 'Yükleme yetkisi yok.\n\n'
            'Lütfen Firebase Console\'da Storage güvenlik kurallarını kontrol edin.\n'
            'Kuralların authenticated kullanıcılara yazma izni verdiğinden emin olun.';
      } else if (errorCode.contains('canceled') || 
                 errorCode.contains('cancelled')) {
        errorMessage = 'Yükleme iptal edildi.';
      } else if (errorCode.contains('quota-exceeded')) {
        errorMessage = 'Storage kotası aşıldı. Lütfen Firebase Console\'dan kotayı kontrol edin.';
      } else if (errorCode.contains('unauthenticated')) {
        errorMessage = 'Kullanıcı giriş yapmamış. Lütfen tekrar giriş yapın.';
      } else {
        errorMessage = 'Firebase Storage hatası (${e.code}): ${e.message ?? "Bilinmeyen hata"}\n\n'
            'Detaylar: $errorMessageText';
      }
      
      throw errorMessage;
    } catch (e) {
      // Genel hatalar
      throw 'Fotoğraf yüklenirken hata oluştu: $e';
    }
  }

  /// Menü öğesi fotoğrafını sil
  Future<void> deleteMenuItemImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) return;
      
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Silme hatası kritik değil, logla
      print('Fotoğraf silinirken hata oluştu: $e');
    }
  }

  /// Bir işletmenin tüm menü öğesi fotoğraflarını sil
  Future<void> deleteAllMenuItemImages(String businessId) async {
    try {
      final folderRef = _storage.ref().child('menu_items/$businessId');
      
      // Klasördeki tüm dosyaları listele
      final listResult = await folderRef.listAll();
      
      // Tüm dosyaları sil
      for (final item in listResult.items) {
        try {
          await item.delete();
        } catch (e) {
          print('Dosya silinirken hata: ${item.fullPath} - $e');
        }
      }
      
      // Alt klasörleri de sil (menuItemId klasörleri)
      for (final prefix in listResult.prefixes) {
        try {
          final prefixList = await prefix.listAll();
          for (final item in prefixList.items) {
            try {
              await item.delete();
            } catch (e) {
              print('Dosya silinirken hata: ${item.fullPath} - $e');
            }
          }
        } catch (e) {
          print('Klasör listelenirken hata: ${prefix.fullPath} - $e');
        }
      }
    } catch (e) {
      // Toplu silme hatası kritik değil, logla
      print('Tüm fotoğraflar silinirken hata oluştu: $e');
    }
  }

  /// Bir kategoriye ait tüm menü öğesi fotoğraflarını sil
  /// Not: Bu metod, kategoriye ait ürünlerin imageUrl'lerini bilmek gerektiğinden
  /// genellikle MenuService üzerinden çağrılır
  Future<void> deleteMenuItemImagesByUrls(List<String> imageUrls) async {
    try {
      for (final imageUrl in imageUrls) {
        if (imageUrl.isNotEmpty) {
          try {
            await deleteMenuItemImage(imageUrl);
          } catch (e) {
            print('Fotoğraf silinirken hata: $imageUrl - $e');
          }
        }
      }
    } catch (e) {
      print('Toplu fotoğraf silme hatası: $e');
    }
  }
}

