# Firebase Firestore Yapısı - Menü Yönetimi

## Firestore Koleksiyon Yapısı

### 1. `menus` Koleksiyonu
Her işletmenin bir menü dokümanı olacak. Doküman ID'si işletme kullanıcısının UID'si olacak.

**Koleksiyon Yolu:** `menus/{businessId}`

**Doküman Yapısı:**
```json
{
  "businessId": "user_uid_123",
  "businessName": "Örnek Restoran",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "categories": [
    {
      "id": "cat_1",
      "name": "Ana Yemekler",
      "order": 1
    },
    {
      "id": "cat_2",
      "name": "İçecekler",
      "order": 2
    },
    {
      "id": "cat_3",
      "name": "Tatlılar",
      "order": 3
    }
  ]
}
```

### 2. `menuItems` Koleksiyonu
Her menü öğesi ayrı bir doküman olarak saklanacak. `businessId` field'ı ile işletmeye bağlanacak.

**Koleksiyon Yolu:** `menuItems/{itemId}`

**Doküman Yapısı:**
```json
{
  "id": "item_123",
  "businessId": "user_uid_123",
  "name": "Adana Kebap",
  "description": "Acılı, özel baharatlı",
  "price": 150.00,
  "categoryId": "cat_1",
  "categoryName": "Ana Yemekler",
  "imageUrl": "https://...",
  "isAvailable": true,
  "order": 1,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

## Firebase Console'da Yapılacaklar

### 1. Firestore Database Oluşturma
1. Firebase Console'a gidin: https://console.firebase.google.com
2. Projenizi seçin
3. Sol menüden **Firestore Database**'e tıklayın
4. **Create database** butonuna tıklayın
5. **Production mode** veya **Test mode** seçin (geliştirme için Test mode yeterli)
6. Bölge seçin (örn: europe-west1)
7. **Enable** butonuna tıklayın

### 2. Güvenlik Kuralları (Security Rules)
Firestore Database > Rules sekmesine gidin ve şu kuralları ekleyin:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Kullanıcılar koleksiyonu - sadece kendi verilerini okuyabilir
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Menüler koleksiyonu - işletmeler sadece kendi menülerini yönetebilir
    match /menus/{businessId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == businessId;
    }
    
    // Menü öğeleri - herkes okuyabilir, sadece sahibi yazabilir
    match /menuItems/{itemId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                     request.resource.data.businessId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                             resource.data.businessId == request.auth.uid;
    }
    
    // Siparişler koleksiyonu
    match /orders/{orderId} {
      // Müşteriler kendi siparişlerini okuyabilir
      // İşletmeler kendi işletmelerine gelen siparişleri okuyabilir
      allow read: if request.auth != null && 
                   (resource.data.customerId == request.auth.uid ||
                    resource.data.businessId == request.auth.uid);
      // Müşteriler sipariş oluşturabilir
      allow create: if request.auth != null && 
                     request.resource.data.customerId == request.auth.uid;
      // İşletmeler kendi siparişlerinin durumunu güncelleyebilir
      allow update: if request.auth != null && 
                     resource.data.businessId == request.auth.uid;
      // Sipariş silinemez
      allow delete: if false;
    }
  }
}
```

### 3. Index Oluşturma (Opsiyonel - Performans için)
Firestore > Indexes sekmesine gidin ve şu index'leri oluşturun:

**Collection:** `menuItems`
**Fields:**
- `businessId` (Ascending)
- `categoryId` (Ascending)
- `order` (Ascending)

**Collection:** `menuItems`
**Fields:**
- `businessId` (Ascending)
- `isAvailable` (Ascending)
- `order` (Ascending)

**Collection:** `orders`
**Fields:**
- `customerId` (Ascending)
- `createdAt` (Descending)

**Collection:** `orders`
**Fields:**
- `businessId` (Ascending)
- `createdAt` (Descending)

## Test Verisi Ekleme (Opsiyonel)

Firebase Console'dan manuel olarak test verisi ekleyebilirsiniz:

1. **menus** koleksiyonuna yeni doküman ekleyin
   - Document ID: Test işletme kullanıcısının UID'si
   - Alanlar: businessId, businessName, categories array

2. **menuItems** koleksiyonuna örnek öğeler ekleyin
   - Her öğe için yukarıdaki yapıyı kullanın

## Notlar

- `businessId` her zaman Firebase Auth'daki kullanıcı UID'si olmalı
- `createdAt` ve `updatedAt` alanları otomatik olarak `FieldValue.serverTimestamp()` ile eklenir
- Kategoriler menü dokümanında array olarak saklanır
- Menü öğeleri ayrı koleksiyonda saklanır ve `businessId` ile filtrelenir
- `order` alanı menü öğelerinin sıralaması için kullanılır

