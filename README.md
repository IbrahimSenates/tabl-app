# Tabl App

Kafe, restoran, otel vb. işletmeler için geliştirilmiş mobil uygulama. Müşteriler QR kod okutarak menüye ulaşabilir, sipariş verebilir ve ödeme yapabilir.

## Özellikler

- ✅ Firebase Authentication ile giriş ve kayıt
- ✅ Email/Şifre ile kimlik doğrulama
- ✅ Şifre sıfırlama
- ✅ Müşteri ve İşletme hesap tipleri
- ✅ Firestore ile kullanıcı verileri yönetimi
- 🔄 QR kod okutma (yakında)
- 🔄 Sipariş verme (yakında)
- 🔄 Ödeme sistemi (yakında)
- 🔄 Puan ve kampanya sistemi (yakında)

## Firebase Kurulumu

Bu proje Firebase Authentication kullanmaktadır. Uygulamayı çalıştırmadan önce Firebase yapılandırmasını tamamlamanız gerekmektedir.

### 1. Firebase Projesi Oluşturma

1. [Firebase Console](https://console.firebase.google.com/)'a gidin
2. "Add project" (Proje Ekle) butonuna tıklayın
3. Proje adını girin ve gerekli adımları tamamlayın
4. Authentication'ı etkinleştirin:
   - Sol menüden "Authentication" seçin
   - "Get started" butonuna tıklayın
   - "Sign-in method" sekmesine gidin
   - "Email/Password" metodunu etkinleştirin

5. **Firestore Database'i etkinleştirin (ÖNEMLİ!):**
   - Sol menüden "Firestore Database" seçin
   - "Create database" butonuna tıklayın
   - **"Start in test mode"** seçeneğini seçin (geliştirme için)
   - Lokasyon seçin (en yakın bölgeyi seçebilirsiniz, örn: europe-west)
   - "Enable" butonuna tıklayın
   
   **Not:** Test modunda 30 gün boyunca tüm okuma/yazma işlemleri izinlidir. Production için güvenlik kuralları ayarlamanız gerekir.

### 2. Android Yapılandırması

1. Firebase Console'da Android uygulaması ekleyin:
   - Proje ayarlarından Android uygulaması ekleyin
   - Package name: `com.example.tabl_app` (AndroidManifest.xml'dan kontrol edin)
   - `google-services.json` dosyasını indirin
   - Dosyayı `android/app/` klasörüne kopyalayın

2. `android/build.gradle.kts` dosyasına ekleyin:
   ```kotlin
   dependencies {
       classpath("com.google.gms:google-services:4.4.0")
   }
   ```

3. `android/app/build.gradle.kts` dosyasının en altına ekleyin:
   ```kotlin
   apply plugin: 'com.google.gms.google-services'
   ```

### 3. iOS Yapılandırması

1. Firebase Console'da iOS uygulaması ekleyin:
   - Proje ayarlarından iOS uygulaması ekleyin
   - Bundle ID'yi girin
   - `GoogleService-Info.plist` dosyasını indirin
   - Dosyayı `ios/Runner/` klasörüne kopyalayın

2. Xcode'da projeyi açın ve `GoogleService-Info.plist` dosyasını projeye ekleyin

### 4. Bağımlılıkları Yükleme

```bash
flutter pub get
```

### 5. Uygulamayı Çalıştırma

```bash
flutter run
```

## Proje Yapısı

```
lib/
├── main.dart                      # Ana uygulama dosyası
├── services/
│   ├── auth_service.dart         # Firebase Authentication servisi
│   └── user_service.dart         # Kullanıcı tipi yönetimi (Firestore)
└── screens/
    ├── login_screen.dart          # Giriş ekranı (kullanıcı tipi seçimi ile)
    ├── register_screen.dart       # Kayıt ekranı (kullanıcı tipi seçimi ile)
    ├── home_screen.dart           # Müşteri ana ekranı
    └── business_home_screen.dart  # İşletme yönetim ekranı
```

## Kullanım

1. Uygulamayı başlattığınızda giriş ekranı açılır
2. Yeni kullanıcılar "Kayıt Ol" butonuna tıklayarak hesap oluşturabilir
3. Mevcut kullanıcılar email ve şifre ile giriş yapabilir
4. Giriş yapıldıktan sonra ana ekrana yönlendirilirsiniz
5. "Çıkış Yap" butonu ile oturum kapatabilirsiniz

## Geliştirme Notları

- Firebase yapılandırma dosyaları (`google-services.json` ve `GoogleService-Info.plist`) `.gitignore` dosyasına eklenmelidir
- Production ortamı için Firebase projesi ayrı oluşturulmalıdır
- **Firestore Güvenlik Kuralları:** Test modunda 30 gün boyunca tüm okuma/yazma işlemleri izinlidir. Production için güvenlik kuralları ayarlamanız gerekir:
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /users/{userId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
  ```

## Firestore Veri Yapısı

Uygulama Firestore'da şu koleksiyonları kullanır:

### `users` koleksiyonu
Her kullanıcı için bir doküman:
```json
{
  "userType": "customer" veya "business",
  "businessName": "İşletme Adı" (sadece işletme için),
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```
