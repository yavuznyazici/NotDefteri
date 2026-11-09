# Dijital Not Defteri — Flutter / Android

Modern, local-first Android not defteri. Parmak ve stylus girişini destekleyen çizim alanı ve SQLite tabanlı veri saklama hedeflenmiştir.

## Gereksinimler
- Flutter 3.29.3 stable
- Android SDK ve JDK 17

## Yerelde kurulum
```bash
flutter create --platforms=android --org com.example .
flutter pub get
flutter analyze
flutter test
flutter run
```

## APK
```bash
flutter build apk --debug
flutter build apk --release
```
Çıktı: `build/app/outputs/flutter-apk/`

## GitHub Actions
1. Bu klasörün içeriğini bir GitHub deposunun `main` dalına yükleyin.
2. Actions > Android APK workflow çalışmasını bekleyin.
3. Çalışma sayfasındaki Artifacts bölümünden APK'yı indirin.
4. Manuel derlemede `workflow_dispatch` ile debug veya release seçilebilir.

Flutter 3.29.3 sürümü workflow içinde sabitlenmiştir. Workflow `flutter analyze`, `flutter test` ve APK build adımlarını çalıştırır.

## Release imzalama
Workflow, şu GitHub Actions Secrets değişkenlerini okur:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

**Önemli:** Bu kaynak pakette release keystore secret'larının Gradle `signingConfigs.release` konfigürasyonuna bağlanması henüz tamamlanmış değildir. Play Store veya dağıtım için imzalı release almadan önce Android Gradle signing yapılandırması eklenmeli ve gerçek anahtarla test edilmelidir.

## Bu sürümde bulunanlar
- SQLite tabloları: categories, folders, notes, pages
- Bağımsız not, kategoriye bağlı not ve klasöre bağlı not oluşturma
- Boş başlık veritabanında `NULL`; arayüzde “Başlık Yok”
- Benzersiz UUID kimlikleri
- Kategori/klasör/not listeleme ve kategori/klasör oluşturma
- Kategori veya klasörü altındaki aktif öğelerle arşivleme
- Silme batch kimliğiyle üst öğe geri yüklenince yalnızca aynı işlemde arşivlenen alt öğeleri geri yükleme
- Kalıcı silme öncesi onay
- Vektörel çizgi koordinatları ve kalem stili JSON saklama
- Kalem, fosforlu kalem, silgi, renk ve kalınlık kontrolleri
- Sayfa ekleme ve sayfalar arası geçiş
- 1 saniyelik debounce otomatik kayıt ve uygulama arka plana geçince kayıt
- Galeriden resim ekleyerek sayfa arka planı oluşturma
- Sayfaya metin ekleme, sürükleme ve uzun basarak silme
- Geri al/ileri al çizim geçmişi

## Bilinen sınırlamalar
Bu teslimat kapsamlı bir ilk uygulama sürümüdür; kullanıcının tüm gereksinimlerini tamamlayan, cihazda doğrulanmış üretim sürümü değildir. Şu işler hâlâ tamamlanmalıdır:
- PDF sayfalarını gerçek sayfa arka planı olarak içe aktarma ve PDF üzerinde anotasyon
- PDF export: tüm sayfalarda çizim, metin ve arka planı doğru ölçekle birleştirme
- WhatsApp/e-posta/system share akışını PDF üretimiyle bağlama
- Kamera çekimi ve kenar algılamalı belge tarama
- Metin fontu/boyutu/renk düzenleme paneli ve metin seçme
- Sayfa silme, arka plan seçenekleri ve gerçek undo/redo komutlarının tüm düzenleme türlerini kapsaması
- Çizim tuvalinde stylus basınç hassasiyeti, palm rejection ve gerçek silgi compositing
- Klasör/not yeniden adlandırma ve tüm hiyerarşi öğeleri için kapsamlı yönetim menüleri
- DB migration ve arşiv davranışları için otomatik testler; gerçek widget/integration testleri
- Gradle release signing yapılandırması
- Android cihazlarda performans, lifecycle ve bellek testi

## Veri saklama
Notlar uygulamanın özel yerel dizinindeki SQLite veritabanında, resimler uygulamanın dosya alanındaki referanslarıyla saklanır. Bulut hesabı veya internet bağlantısı gerekmez. Uygulamayı kaldırmak yerel verileri silebilir; ayrıca harici yedekleme özelliği henüz eklenmemiştir.
