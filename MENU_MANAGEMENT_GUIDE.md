# Menü Yönetimi Kullanım Kılavuzu

## Oluşturulan Dosyalar

1. **lib/services/menu_service.dart** - Menü ve menü öğeleri için Firebase servisi
2. **lib/screens/menu_management_screen.dart** - Menü yönetim ana ekranı
3. **lib/screens/menu_item_form_screen.dart** - Menü öğesi ekleme/düzenleme formu
4. **FIREBASE_SETUP.md** - Firebase yapılandırma rehberi

## Özellikler

### ✅ Menü Yönetimi Ekranı
- Menü öğelerini listeleme
- Kategori bazlı filtreleme
- Menü öğesi ekleme/düzenleme/silme
- Menü öğesi mevcut durumunu değiştirme (mevcut/mevcut değil)
- Kategori yönetimi

### ✅ Menü Öğesi Formu
- Menü öğesi adı
- Açıklama
- Kategori seçimi
- Fiyat girişi
- Mevcut durumu (aktif/pasif)

### ✅ Kategori Yönetimi
- Kategori ekleme
- Kategorilere göre menü öğelerini filtreleme

## Firebase'de Yapılması Gerekenler

### 1. Firestore Database Oluşturma
1. Firebase Console'a gidin: https://console.firebase.google.com
2. Projenizi seçin
3. Sol menüden **Firestore Database**'e tıklayın
4. **Create database** butonuna tıklayın
5. **Test mode** seçin (geliştirme için)
6. Bölge seçin (örn: europe-west1)
7. **Enable** butonuna tıklayın

### 2. Güvenlik Kuralları
Firestore Database > Rules sekmesine gidin ve şu kuralları ekleyin:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Kullanıcılar koleksiyonu
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Menüler koleksiyonu
    match /menus/{businessId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == businessId;
    }
    
    // Menü öğeleri koleksiyonu
    match /menuItems/{itemId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                     request.resource.data.businessId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                             resource.data.businessId == request.auth.uid;
    }
  }
}
```

### 3. Index Oluşturma (Opsiyonel)
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

## Kullanım

### Menü Yönetimine Erişim
1. İşletme hesabı ile giriş yapın
2. Ana ekranda **Menü** kartına tıklayın
3. Menü yönetim ekranı açılacak

### Kategori Ekleme
1. Menü yönetim ekranında sağ üstteki **kategori** ikonuna tıklayın
2. Kategori adını girin (örn: "Ana Yemekler", "İçecekler")
3. **Ekle** butonuna tıklayın

### Menü Öğesi Ekleme
1. Menü yönetim ekranında sağ üstteki **+** ikonuna tıklayın
2. Formu doldurun:
   - Menü öğesi adı (zorunlu)
   - Açıklama (opsiyonel)
   - Kategori seçimi (zorunlu)
   - Fiyat (zorunlu)
   - Mevcut durumu (aktif/pasif)
3. **Kaydet** butonuna tıklayın

### Menü Öğesi Düzenleme
1. Menü öğesinin yanındaki **üç nokta** menüsüne tıklayın
2. **Düzenle** seçeneğini seçin
3. Bilgileri güncelleyin
4. **Güncelle** butonuna tıklayın

### Menü Öğesi Silme
1. Menü öğesinin yanındaki **üç nokta** menüsüne tıklayın
2. **Sil** seçeneğini seçin
3. Onaylayın

### Menü Öğesi Mevcut Durumunu Değiştirme
1. Menü öğesinin yanındaki **üç nokta** menüsüne tıklayın
2. **Mevcut Değil Yap** veya **Mevcut Yap** seçeneğini seçin

### Kategoriye Göre Filtreleme
1. Menü yönetim ekranının üst kısmındaki kategori filtrelerinden birini seçin
2. Sadece seçili kategorideki menü öğeleri gösterilecek
3. **Tümü** seçeneğine tıklayarak tüm menü öğelerini görebilirsiniz

## Veri Yapısı

### Menü Dokümanı
```
menus/{businessId}
├── businessId: string
├── businessName: string
├── categories: array
│   ├── id: string
│   ├── name: string
│   └── order: number
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Menü Öğesi Dokümanı
```
menuItems/{itemId}
├── id: string
├── businessId: string
├── name: string
├── description: string
├── price: number
├── categoryId: string
├── categoryName: string
├── imageUrl: string (opsiyonel)
├── isAvailable: boolean
├── order: number
├── createdAt: timestamp
└── updatedAt: timestamp
```

## Notlar

- İlk menü yönetimine girdiğinizde otomatik olarak menü dokümanı oluşturulur
- Kategori eklemeden menü öğesi ekleyemezsiniz
- Menü öğeleri kategoriye göre sıralanır
- Mevcut olmayan menü öğeleri üzeri çizili olarak gösterilir
- Tüm fiyatlar Türk Lirası (₺) cinsindendir

