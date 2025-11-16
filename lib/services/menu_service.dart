import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class MenuCategory {
  final String id;
  final String name;
  final int order;

  MenuCategory({
    required this.id,
    required this.name,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'order': order,
    };
  }

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      order: map['order'] as int,
    );
  }
}

class MenuItem {
  final String? id;
  final String businessId;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String categoryName;
  final String? imageUrl;
  final bool isAvailable;
  final int order;

  MenuItem({
    this.id,
    required this.businessId,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    this.imageUrl,
    this.isAvailable = true,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map, String docId) {
    return MenuItem(
      id: docId,
      businessId: map['businessId'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      price: (map['price'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      imageUrl: map['imageUrl'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
      order: map['order'] as int? ?? 0,
    );
  }

  MenuItem copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? categoryName,
    String? imageUrl,
    bool? isAvailable,
    int? order,
  }) {
    return MenuItem(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      order: order ?? this.order,
    );
  }
}

class MenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  // Menü dokümanını oluştur veya güncelle
  Future<void> createOrUpdateMenu({
    required String businessId,
    required String businessName,
  }) async {
    try {
      await _firestore.collection('menus').doc(businessId).set({
        'businessId': businessId,
        'businessName': businessName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw 'Menü oluşturulurken hata oluştu: $e';
    }
  }

  // Menü dokümanını al
  Future<Map<String, dynamic>?> getMenu(String businessId) async {
    try {
      final doc = await _firestore.collection('menus').doc(businessId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw 'Menü alınırken hata oluştu: $e';
    }
  }

  // Kategorileri kaydet
  Future<void> saveCategories({
    required String businessId,
    required List<MenuCategory> categories,
  }) async {
    try {
      final categoriesData = categories.map((cat) => cat.toMap()).toList();
      await _firestore.collection('menus').doc(businessId).update({
        'categories': categoriesData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Kategoriler kaydedilirken hata oluştu: $e';
    }
  }

  // Kategorileri al
  Future<List<MenuCategory>> getCategories(String businessId) async {
    try {
      final doc = await _firestore.collection('menus').doc(businessId).get();
      if (doc.exists && doc.data() != null) {
        final categoriesData = doc.data()!['categories'] as List<dynamic>?;
        if (categoriesData != null) {
          return categoriesData
              .map((cat) => MenuCategory.fromMap(cat as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
        }
      }
      return [];
    } catch (e) {
      throw 'Kategoriler alınırken hata oluştu: $e';
    }
  }

  // Menü öğesi ekle
  Future<String> addMenuItem(MenuItem item) async {
    try {
      final docRef = await _firestore.collection('menuItems').add(item.toMap());
      
      // createdAt alanını ekle
      await docRef.update({
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    } catch (e) {
      throw 'Menü öğesi eklenirken hata oluştu: $e';
    }
  }

  // Menü öğesini güncelle
  Future<void> updateMenuItem(MenuItem item) async {
    try {
      if (item.id == null) {
        throw 'Menü öğesi ID\'si bulunamadı';
      }
      
      final updateData = item.toMap();
      updateData.remove('createdAt'); // createdAt'i güncelleme
      
      await _firestore.collection('menuItems').doc(item.id).update(updateData);
    } catch (e) {
      throw 'Menü öğesi güncellenirken hata oluştu: $e';
    }
  }

  // Menü öğesini sil (Firestore ve Storage'dan)
  Future<void> deleteMenuItem(String itemId) async {
    try {
      // Önce menü öğesini al (fotoğraf URL'si için)
      final menuItem = await getMenuItemById(itemId);
      
      // Fotoğraf varsa Storage'dan sil
      if (menuItem != null && menuItem.imageUrl != null && menuItem.imageUrl!.isNotEmpty) {
        try {
          await _storageService.deleteMenuItemImage(menuItem.imageUrl!);
        } catch (e) {
          // Fotoğraf silme hatası kritik değil, devam et
          print('Menü öğesi fotoğrafı silinirken hata: $e');
        }
      }
      
      // Firestore'dan sil
      await _firestore.collection('menuItems').doc(itemId).delete();
    } catch (e) {
      throw 'Menü öğesi silinirken hata oluştu: $e';
    }
  }
  
  // Kategoriye ait tüm menü öğelerini sil (kategori silinirken kullanılır)
  Future<void> deleteMenuItemsByCategory(String businessId, String categoryId) async {
    try {
      // Kategoriye ait tüm menü öğelerini al
      final items = await getMenuItemsByCategory(businessId, categoryId);
      
      // Her bir öğeyi sil (fotoğrafları da dahil)
      for (final item in items) {
        if (item.id != null) {
          await deleteMenuItem(item.id!);
        }
      }
    } catch (e) {
      throw 'Kategori menü öğeleri silinirken hata oluştu: $e';
    }
  }

  // İşletmenin tüm menü öğelerini al
  Future<List<MenuItem>> getMenuItems(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('menuItems')
          .where('businessId', isEqualTo: businessId)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Menü öğeleri alınırken hata oluştu: $e';
    }
  }

  // Kategoriye göre menü öğelerini al
  Future<List<MenuItem>> getMenuItemsByCategory(
    String businessId,
    String categoryId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('menuItems')
          .where('businessId', isEqualTo: businessId)
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Menü öğeleri alınırken hata oluştu: $e';
    }
  }

  // Menü öğelerini stream olarak dinle
  Stream<List<MenuItem>> getMenuItemsStream(String businessId) {
    return _firestore
        .collection('menuItems')
        .where('businessId', isEqualTo: businessId)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MenuItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Menü öğesini ID ile al
  Future<MenuItem?> getMenuItemById(String itemId) async {
    try {
      final doc = await _firestore.collection('menuItems').doc(itemId).get();
      if (doc.exists && doc.data() != null) {
        return MenuItem.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Menü öğesi alınırken hata oluştu: $e';
    }
  }
}

