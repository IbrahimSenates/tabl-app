import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String? id;
  final String orderId;
  final String customerId;
  final String businessId;
  final String businessName;
  final int rating; // 1-5 arası
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Review({
    this.id,
    required this.orderId,
    required this.customerId,
    required this.businessId,
    required this.businessName,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'businessId': businessId,
      'businessName': businessName,
      'rating': rating,
      'comment': comment,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map, String docId) {
    return Review(
      id: docId,
      orderId: map['orderId'] as String,
      customerId: map['customerId'] as String,
      businessId: map['businessId'] as String,
      businessName: map['businessName'] as String,
      rating: map['rating'] as int,
      comment: map['comment'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Yorum oluştur veya güncelle
  Future<String> createOrUpdateReview(Review review) async {
    try {
      // Aynı sipariş için daha önce yorum var mı kontrol et
      final existingReview = await _firestore
          .collection('reviews')
          .where('orderId', isEqualTo: review.orderId)
          .limit(1)
          .get();

      if (existingReview.docs.isNotEmpty) {
        // Güncelle
        await existingReview.docs.first.reference.update(review.toMap());
        return existingReview.docs.first.id;
      } else {
        // Yeni oluştur
        final reviewData = review.toMap();
        final docRef = await _firestore.collection('reviews').add(reviewData);
        
        // createdAt alanını ekle
        await docRef.update({
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        return docRef.id;
      }
    } catch (e) {
      throw 'Yorum oluşturulurken hata oluştu: $e';
    }
  }

  // Sipariş için yorum var mı kontrol et
  Future<Review?> getReviewByOrderId(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return Review.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    } catch (e) {
      throw 'Yorum alınırken hata oluştu: $e';
    }
  }

  // İşletmenin tüm yorumlarını al
  Future<List<Review>> getBusinessReviews(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Yorumlar alınırken hata oluştu: $e';
    }
  }

  // İşletmenin yorumlarını stream olarak dinle
  Stream<List<Review>> getBusinessReviewsStream(String businessId) {
    return _firestore
        .collection('reviews')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Review.fromMap(doc.data(), doc.id))
            .toList());
  }

  // İşletmenin ortalama puanını hesapla
  Future<double> getBusinessAverageRating(String businessId) async {
    try {
      final reviews = await getBusinessReviews(businessId);
      if (reviews.isEmpty) {
        return 0.0;
      }

      final totalRating = reviews.fold<int>(
        0,
        (sum, review) => sum + review.rating,
      );

      return totalRating / reviews.length;
    } catch (e) {
      throw 'Ortalama puan hesaplanırken hata oluştu: $e';
    }
  }

  // Yorumu sil
  Future<void> deleteReview(String reviewId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
    } catch (e) {
      throw 'Yorum silinirken hata oluştu: $e';
    }
  }
}

