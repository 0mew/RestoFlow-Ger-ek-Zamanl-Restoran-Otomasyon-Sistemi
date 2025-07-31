# RestoFlow: Gerçek Zamanlı Restoran Otomasyon Sistemi

**RestoFlow**, modern restoran, kafe ve benzeri işletmeler için geliştirilmiş, Dart ve Flutter tabanlı, tam kapsamlı (full-stack) bir otomasyon sistemidir. Bu proje, sipariş alımından mutfak yönetimine, müşteri ödemelerinden admin paneline kadar tüm operasyonel süreçleri tek bir platformda dijitalleştirmeyi ve otomatize etmeyi amaçlamaktadır.

## ✨ Temel Özellikler

RestoFlow, dört ana kullanıcı rolü için zengin ve işlevsel bir deneyim sunar:

### 🤵 Garson

- **Anlık Masa Takibi:** Masaların durumunu (Boş, Siparişli, Teslim Edildi) renk kodları ve animasyonlarla anlık olarak görüntüleme.
- **Birleşik Sipariş Ekranı:** Tek bir ekrandan hem yeni sipariş alma (kategorize edilmiş menü ile) hem de masanın mevcut siparişlerini yönetme.
- **Detaylı Sipariş Alma:** Ürünlere not ekleme, sipariş sepetini yönetme ve tek tuşla siparişi mutfağa gönderme.
- **Anlık Bildirimler:** Mutfaktan gelen "Sipariş Hazır" bildirimlerini anında alma.
- **Sipariş Teslimatı:** Hazır siparişleri teslim edip masanın durumunu güncelleme.

### 🍳 Mutfak

- **Anlık Sipariş Ekranı:** Yeni gelen siparişleri tüm detaylarıyla (masa no, ürünler, adetler, notlar) anlık olarak görme.
- **Sipariş Yönetimi:** "Bekleyenler" ve "Hazırlar" olarak siparişleri kolayca ayırt etme.
- **Tek Tuşla Bildirim:** Hazırlanan siparişleri "Sipariş Hazır" olarak işaretleyip garsona anında bildirim gönderme.

### 👤 Müşteri

- **Kolay Giriş:** Masa numarasını girerek kendi masasının siparişlerine anında erişim.
- **Şeffaf Hesap Takibi:** Masaya ait tüm siparişleri, ürünleri, fiyatları ve ödeme durumlarını görme.
- **Uygulama İçi Ödeme:** Ödemek istediği ürünleri seçerek (sahte) ödeme yapabilme.
- **Ödeme Onayı:** Başarılı ödeme sonrası, ödediği ürünlerin özetini içeren bir onay ekranı.

### 👑 Admin (Yönetici)

- **Merkezi Yönetim Paneli:** Tüm yönetimsel işlemlere tek bir yerden erişim.
- **Personel Yönetimi:** Yeni garson/mutfak personeli ekleme ve mevcut personeli silme.
- **Menü Yönetimi:** Menüye yeni ürün ekleme, mevcut ürünlerin bilgilerini (isim, kategori, fiyat) düzenleme ve (siparişlerde kullanılmıyorsa) silme.
- **Masa Yönetimi:** Restorandaki toplam masa sayısını dinamik olarak artırma ve azaltma.
- **Satış Raporları:** Ödemesi tamamlanmış ürünlere göre toplam geliri ve ürün bazında satış adetlerini görme.

## 🚀 Teknolojiler ve Mimari

Proje, **İstemci-Sunucu (Client-Server)** mimarisi üzerine kurulmuştur. Tüm iş mantığı ve veri depolama işlemleri merkezi bir sunucuda toplanırken, kullanıcı etkileşimi Flutter ile geliştirilmiş tek bir mobil uygulama üzerinden sağlanır.

- **Programlama Dili:** Projenin tamamı **Dart** dili ile geliştirilmiştir.
- **İstemci** (Client): **Flutter** ile geliştirilmiş Android uygulaması.
    - **State Management:** `provider`
    - **UI/UX:** `google_fonts`, `AnimatedContainer`
- **Sunucu (Server):** Saf Dart ile yazılmış WebSocket sunucusu.
    - **WebSocket:** `shelf` ve `shelf_web_socket`
- **Veritabanı:** **SQLite** (`sqlite3` paketi ile)
- **İletişim Protokolü:** **WebSocket** üzerinden JSON mesajları.

### Akış Diyagramı

```
+--------------------------+            +----------------------------------+
|    İSTEMCİ (Telefon)     |            |     SUNUCU (Bilgisayar)          |
|                          |            |                                  |
|  +--------------------+  |<---------->|  +------------------------+      |
|  | Flutter Uygulaması |  | WebSocket  |  |    Dart WebSocket      |      |
|  | (restaurant_app)   |  | Protokolü| |  | Sunucusu (server.dart) |      |
|  +--------------------+  |            |  +------------------------+      |
|                          |            |             |                    |
+--------------------------+            |             | (Doğrudan Erişim)  |
                                        |             |                    |
                                        |  +-----------------------+       |
                                        |  |    SQLite Veritabanı  |       |
                                        |  |    (restaurant.db)    |       |
                                        |  +-----------------------+       |
                                        |                                  |
                                        +----------------------------------+
```

### Veri Tabanı Şeması

```
+-------------+      +--------+      +------------+
|    Users    |      | Tables |      | MenuItems  |
+-------------+      +--------+      +------------+
| id (PK)     |      | id (PK)|      | id (PK)    |
| username    |      | table_ |      | name       |
| password    |      | status |      | category   |
| role        |      +---^----+      | price      |
+-------------+          |           +------^-----+
                         |                  |
                         | (table_id)       | (menu_item_id)
                         |                  |
                    +----v----+        +----v----------+
                    |  Orders |        |  OrderItems   |
                    +---------+        +---------------+
                    | id (PK) |------->| id (PK)       |
                    | table_id|        | order_id      |
                    | order_  |        | menu_item_id  |
                    | status  |        | quantity      |
                    +---------+        | notes         |
                                       | payment_status|
                                       +---------------+
```


## 🛠️ Kurulum ve Çalıştırma

Bu projeyi yerel makinenizde çalıştırmak için aşağıdaki adımları izleyin.

### Gereksinimler

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x veya üstü)
- [Dart SDK](https://dart.dev/get-dart) (Flutter ile birlikte gelir)

### 1. Sunucuyu Çalıştırma

Sunucu, tüm istemcilerin bağlanacağı merkezi noktadır.

```
# 1. Sunucu projesi klasörüne gidin
cd restaurant_server

# 2. Gerekli paketleri yükleyin
dart pub get

# 3. Sunucuyu başlatın
dart run

```

Sunucu varsayılan olarak `8080` portunda çalışmaya başlayacaktır.

### 2. Flutter Uygulamasını Çalıştırma

1. **Sunucu IP Adresini Ayarlama:**
    - Sunucunun çalıştığı bilgisayarın yerel ağdaki IP adresini öğrenin (Windows için `ipconfig`, macOS/Linux için `ifconfig` veya `ip addr`).
    - Flutter projesini ilk kez çalıştırdıktan sonra, uygulama içindeki **"Sunucu IP Ayarı"** ekranından bu IP adresini girip kaydedin.
2. **Uygulamayı Derleme ve Çalıştırma:**
    
    ```
    # 1. Flutter projesi klasörüne gidin
    cd restaurant_app
    
    # 2. Gerekli paketleri yükleyin
    flutter pub get
    
    # 3. Uygulamayı bir emülatörde veya fiziksel bir cihazda çalıştırın
    flutter run
    
    ```
    

## 🔮 Gelecek Geliştirmeler

Projenin bu versiyonu sağlam bir temel oluşturmaktadır. Gelecekteki versiyonlar için aşağıdaki özellikler hedeflenebilir:

- **Gelişmiş Raporlama:** Tarih aralığına göre filtrelenebilen satış raporları.
- **Sipariş Düzenleme/İptal Etme:** Mutfak onayından önce siparişleri değiştirme.
- **Gerçek Ödeme Entegrasyonu:** Gerçek bir ödeme altyapısı sağlayıcısının entegrasyonu.
- **Çevrimdışı (Offline) Mod:** İnternet bağlantısı koptuğunda sipariş alabilme ve bağlantı geldiğinde senkronize etme.

## 📄 Lisans

Bu proje MIT Lisansı altında lisanslanmıştır. Detaylar için `LICENSE` dosyasına bakınız.
