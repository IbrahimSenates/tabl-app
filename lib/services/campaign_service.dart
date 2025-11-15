import 'package:cloud_firestore/cloud_firestore.dart';

class Campaign {
  final String? id;
  final String businessId;
  final String businessName;
  final String title;
  final String description;
  final int requiredQuantity; // X ürün (örn: 5)
  final int freeQuantity; // Y ürün bedava (örn: 1)
  final String? applicableMenuItemId; // Belirli bir ürün için (null ise tüm ürünler)
  final String? applicableMenuItemName;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Campaign({
    this.id,
    required this.businessId,
    required this.businessName,
    required this.title,
    required this.description,
    required this.requiredQuantity,
    required this.freeQuantity,
    this.applicableMenuItemId,
    this.applicableMenuItemName,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'title': title,
      'description': description,
      'requiredQuantity': requiredQuantity,
      'freeQuantity': freeQuantity,
      'applicableMenuItemId': applicableMenuItemId,
      'applicableMenuItemName': applicableMenuItemName,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Campaign.fromMap(Map<String, dynamic> map, String docId) {
    return Campaign(
      id: docId,
      businessId: map['businessId'] as String,
      businessName: map['businessName'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      requiredQuantity: map['requiredQuantity'] as int,
      freeQuantity: map['freeQuantity'] as int,
      applicableMenuItemId: map['applicableMenuItemId'] as String?,
      applicableMenuItemName: map['applicableMenuItemName'] as String?,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}

class CampaignProgress {
  final String? id;
  final String customerId;
  final String campaignId;
  final String businessId;
  final int progress; // Tamamlanan sipariş sayısı
  final bool isCompleted; // Kampanya tamamlandı mı
  final DateTime? lastUpdatedAt;

  CampaignProgress({
    this.id,
    required this.customerId,
    required this.campaignId,
    required this.businessId,
    this.progress = 0,
    this.isCompleted = false,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'campaignId': campaignId,
      'businessId': businessId,
      'progress': progress,
      'isCompleted': isCompleted,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory CampaignProgress.fromMap(Map<String, dynamic> map, String docId) {
    return CampaignProgress(
      id: docId,
      customerId: map['customerId'] as String,
      campaignId: map['campaignId'] as String,
      businessId: map['businessId'] as String,
      progress: map['progress'] as int? ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? false,
      lastUpdatedAt: (map['lastUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  CampaignProgress copyWith({
    String? id,
    String? customerId,
    String? campaignId,
    String? businessId,
    int? progress,
    bool? isCompleted,
    DateTime? lastUpdatedAt,
  }) {
    return CampaignProgress(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      campaignId: campaignId ?? this.campaignId,
      businessId: businessId ?? this.businessId,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

class CampaignService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kampanya oluştur
  Future<String> createCampaign(Campaign campaign) async {
    try {
      final campaignData = campaign.toMap();
      final docRef = await _firestore.collection('campaigns').add(campaignData);
      
      // createdAt alanını ekle
      await docRef.update({
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    } catch (e) {
      throw 'Kampanya oluşturulurken hata oluştu: $e';
    }
  }

  // Kampanya güncelle
  Future<void> updateCampaign(Campaign campaign) async {
    try {
      if (campaign.id == null) {
        throw 'Kampanya ID\'si bulunamadı';
      }
      
      final updateData = campaign.toMap();
      updateData.remove('createdAt'); // createdAt'i güncelleme
      
      await _firestore.collection('campaigns').doc(campaign.id).update(updateData);
    } catch (e) {
      throw 'Kampanya güncellenirken hata oluştu: $e';
    }
  }

  // Kampanya sil
  Future<void> deleteCampaign(String campaignId) async {
    try {
      await _firestore.collection('campaigns').doc(campaignId).delete();
    } catch (e) {
      throw 'Kampanya silinirken hata oluştu: $e';
    }
  }

  // İşletmenin kampanyalarını al
  Future<List<Campaign>> getBusinessCampaigns(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('campaigns')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Campaign.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Kampanyalar alınırken hata oluştu: $e';
    }
  }

  // İşletmenin aktif kampanyalarını al (müşteriler için)
  Future<List<Campaign>> getActiveCampaigns(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('campaigns')
          .where('businessId', isEqualTo: businessId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      final campaigns = snapshot.docs
          .map((doc) => Campaign.fromMap(doc.data(), doc.id))
          .toList();

      // Geçerlilik tarihlerini kontrol et
      return campaigns.where((campaign) => campaign.isValid).toList();
    } catch (e) {
      throw 'Kampanyalar alınırken hata oluştu: $e';
    }
  }

  // Kampanyaları stream olarak dinle
  Stream<List<Campaign>> getBusinessCampaignsStream(String businessId) {
    return _firestore
        .collection('campaigns')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Campaign.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Kampanyayı ID ile al
  Future<Campaign?> getCampaignById(String campaignId) async {
    try {
      final doc = await _firestore.collection('campaigns').doc(campaignId).get();
      if (doc.exists && doc.data() != null) {
        return Campaign.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Kampanya alınırken hata oluştu: $e';
    }
  }

  // Kampanya ilerlemesini al veya oluştur
  Future<CampaignProgress> getOrCreateProgress({
    required String customerId,
    required String campaignId,
    required String businessId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('campaignProgress')
          .where('customerId', isEqualTo: customerId)
          .where('campaignId', isEqualTo: campaignId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return CampaignProgress.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }

      // Yeni ilerleme oluştur
      final progress = CampaignProgress(
        customerId: customerId,
        campaignId: campaignId,
        businessId: businessId,
      );
      final docRef = await _firestore
          .collection('campaignProgress')
          .add(progress.toMap());
      
      return CampaignProgress(
        id: docRef.id,
        customerId: customerId,
        campaignId: campaignId,
        businessId: businessId,
      );
    } catch (e) {
      throw 'Kampanya ilerlemesi alınırken hata oluştu: $e';
    }
  }

  // Kampanya ilerlemesini güncelle
  Future<void> updateProgress({
    required String customerId,
    required String campaignId,
    required String businessId,
    required int quantity,
  }) async {
    try {
      final campaign = await getCampaignById(campaignId);
      if (campaign == null) return;

      final progress = await getOrCreateProgress(
        customerId: customerId,
        campaignId: campaignId,
        businessId: businessId,
      );

      final newProgress = progress.progress + quantity;
      final isCompleted = newProgress >= campaign.requiredQuantity;

      if (progress.id != null) {
        await _firestore.collection('campaignProgress').doc(progress.id).update({
          'progress': newProgress,
          'isCompleted': isCompleted,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw 'Kampanya ilerlemesi güncellenirken hata oluştu: $e';
    }
  }

  // Müşterinin kampanya ilerlemelerini al
  Future<List<CampaignProgress>> getCustomerProgresses({
    required String customerId,
    required String businessId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('campaignProgress')
          .where('customerId', isEqualTo: customerId)
          .where('businessId', isEqualTo: businessId)
          .get();

      return snapshot.docs
          .map((doc) => CampaignProgress.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'Kampanya ilerlemeleri alınırken hata oluştu: $e';
    }
  }

  // Müşterinin kampanya ilerlemelerini stream olarak dinle (real-time güncelleme için)
  Stream<List<CampaignProgress>> getCustomerProgressesStream({
    required String customerId,
    required String businessId,
  }) {
    return _firestore
        .collection('campaignProgress')
        .where('customerId', isEqualTo: customerId)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CampaignProgress.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Kampanya ilerlemesini sıfırla (kampanya tamamlandıktan sonra)
  Future<void> resetProgress(String progressId) async {
    try {
      await _firestore.collection('campaignProgress').doc(progressId).update({
        'progress': 0,
        'isCompleted': false,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Kampanya ilerlemesi sıfırlanırken hata oluştu: $e';
    }
  }
}

