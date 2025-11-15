import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserType {
  customer, // Müşteri
  business, // İşletme
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kullanıcı tipini kaydet
  Future<void> saveUserType({
    required String userId,
    required UserType userType,
    String? businessName,
  }) async {
    try {
      final userData = {
        'userType': userType.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Eğer işletme ise işletme adını da ekle
      if (userType == UserType.business && businessName != null) {
        userData['businessName'] = businessName;
      }

      await _firestore.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: true),
      );
    } catch (e) {
      throw 'Kullanıcı bilgileri kaydedilirken hata oluştu: $e';
    }
  }

  // Kullanıcı tipini al
  Future<UserType?> getUserType(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final userTypeString = doc.data()!['userType'] as String?;
        if (userTypeString != null) {
          return UserType.values.firstWhere(
            (type) => type.name == userTypeString,
            orElse: () => UserType.customer,
          );
        }
      }
      return null;
    } catch (e) {
      throw 'Kullanıcı bilgileri alınırken hata oluştu: $e';
    }
  }

  // Kullanıcı bilgilerini al
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw 'Kullanıcı bilgileri alınırken hata oluştu: $e';
    }
  }

  // Mevcut kullanıcının tipini al
  Future<UserType?> getCurrentUserType() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await getUserType(user.uid);
    }
    return null;
  }

  // Kullanıcı tipi stream'i (gerçek zamanlı güncellemeler için)
  Stream<UserType?> getUserTypeStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final userTypeString = snapshot.data()!['userType'] as String?;
        if (userTypeString != null) {
          try {
            return UserType.values.firstWhere(
              (type) => type.name == userTypeString,
              orElse: () => UserType.customer,
            );
          } catch (e) {
            return null;
          }
        }
      }
      return null;
    });
  }
}


