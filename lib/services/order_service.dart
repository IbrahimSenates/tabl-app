import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending, // Beklemede
  confirmed, // Onaylandı
  preparing, // Hazırlanıyor
  ready, // Hazır
  completed, // Tamamlandı
  cancelled, // İptal edildi
}

class OrderItem {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuItemId: map['menuItemId'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }

  double get total => price * quantity;
}

class Order {
  final String? id;
  final String customerId;
  final String businessId;
  final String businessName;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final String? customerNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    this.id,
    required this.customerId,
    required this.businessId,
    required this.businessName,
    required this.items,
    required this.totalAmount,
    this.status = OrderStatus.pending,
    this.customerNote,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'businessId': businessId,
      'businessName': businessName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status.name,
      'customerNote': customerNote,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, String docId) {
    final itemsData = map['items'] as List<dynamic>;
    final items = itemsData.map((item) => OrderItem.fromMap(item as Map<String, dynamic>)).toList();
    
    final statusString = map['status'] as String? ?? 'pending';
    final status = OrderStatus.values.firstWhere(
      (s) => s.name == statusString,
      orElse: () => OrderStatus.pending,
    );

    return Order(
      id: docId,
      customerId: map['customerId'] as String,
      businessId: map['businessId'] as String,
      businessName: map['businessName'] as String,
      items: items,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      status: status,
      customerNote: map['customerNote'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sipariş oluştur
  Future<String> createOrder(Order order) async {
    try {
      final orderData = order.toMap();
      final docRef = await _firestore.collection('orders').add(orderData);
      
      // createdAt alanını ekle
      await docRef.update({
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    } catch (e) {
      throw 'Sipariş oluşturulurken hata oluştu: $e';
    }
  }

  // Sipariş durumunu güncelle
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Sipariş durumu güncellenirken hata oluştu: $e';
    }
  }

  // Müşterinin siparişlerini al
  Future<List<Order>> getCustomerOrders(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Order.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Siparişler alınırken hata oluştu: $e';
    }
  }

  // Müşterinin belirli bir işletmeden verdiği siparişleri al
  Future<List<Order>> getCustomerOrdersByBusiness({
    required String customerId,
    required String businessId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Order.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Siparişler alınırken hata oluştu: $e';
    }
  }

  // İşletmenin siparişlerini al
  Future<List<Order>> getBusinessOrders(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Order.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Siparişler alınırken hata oluştu: $e';
    }
  }

  // Siparişleri stream olarak dinle (işletme için)
  Stream<List<Order>> getBusinessOrdersStream(String businessId) {
    return _firestore
        .collection('orders')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Order.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Siparişi ID ile al
  Future<Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        return Order.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Sipariş alınırken hata oluştu: $e';
    }
  }
}

