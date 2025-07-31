import 'package:sqlite3/sqlite3.dart';

class DatabaseHelper {
  static const String dbName = 'restaurant.db';
  static late Database db;

  static void initializeDatabase() {
    db = sqlite3.open(dbName);
    print('✅ Veritabanı bağlantısı kalıcı olarak açıldı: $dbName');

    // Gerekli tüm tabloları oluştur
    _createTables();

    // Veritabanını başlangıç verileriyle doldur
    _seedData();
  }

  static void _createTables() {
    // Users, MenuItems, Tables, Orders, OrderItems tablolarını oluşturur.
    db.execute('''
      CREATE TABLE IF NOT EXISTS Users (id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE, password TEXT NOT NULL, role TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS MenuItems (id INTEGER PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL, price REAL NOT NULL,UNIQUE(name, category));
      CREATE TABLE IF NOT EXISTS Tables (id INTEGER PRIMARY KEY, table_number INTEGER NOT NULL UNIQUE, status TEXT NOT NULL DEFAULT 'available');
      CREATE TABLE IF NOT EXISTS Orders (id INTEGER PRIMARY KEY, table_id INTEGER NOT NULL, order_time TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', FOREIGN KEY (table_id) REFERENCES Tables (id));
      CREATE TABLE IF NOT EXISTS OrderItems (id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, menu_item_id INTEGER NOT NULL, quantity INTEGER NOT NULL DEFAULT 1, notes TEXT, payment_status TEXT NOT NULL DEFAULT 'unpaid', FOREIGN KEY (order_id) REFERENCES Orders (id), FOREIGN KEY (menu_item_id) REFERENCES MenuItems (id));
    ''');
    print('✅ Tüm tablolar oluşturuldu/kontrol edildi.');
  }

  static void _seedData() {
    // Örnek Kullanıcılar
    db.execute(
      "INSERT OR IGNORE INTO Users (id, username, password, role) VALUES (1, 'garson1', 'sifre123', 'waiter')",
    );
    db.execute(
      "INSERT OR IGNORE INTO Users (id, username, password, role) VALUES (2, 'mutfak1', 'sifre456', 'kitchen')",
    );

    db.execute(
      "INSERT OR IGNORE INTO Users (id, username, password, role) VALUES (3, 'admin', 'admin123', 'admin')",
    );

    print('✅ Örnek kullanıcılar eklendi/kontrol edildi.');

    // Masalar
    for (int i = 1; i <= 25; i++) {
      db.execute(
        'INSERT OR IGNORE INTO Tables (id, table_number, status) VALUES (?, ?, ?)',
        [i, i, 'available'],
      );
    }
    print('✅ 25 adet masa eklendi/kontrol edildi.');

    // Örnek Menü Ürünleri (EN ÖNEMLİ KISIM)
    // Örnek Menü Ürünleri
    print(
      'ℹ️ Örnek menü ürünleri ekleniyor/kontrol ediliyor...',
    ); // Mesajı biraz değiştirdim
    final items = [
      {'name': 'Mercimek Çorbası', 'category': 'Çorbalar', 'price': 45.0},
      {'name': 'Adana Kebap', 'category': 'Ana Yemekler', 'price': 180.0},
      {'name': 'İskender', 'category': 'Ana Yemekler', 'price': 220.0},
      {'name': 'Kola', 'category': 'Soğuk İçecekler', 'price': 35.0},
      {'name': 'Ayran', 'category': 'Soğuk İçecekler', 'price': 25.0},
      {'name': 'Çay', 'category': 'Sıcak İçecekler', 'price': 15.0},
      {'name': 'Türk Kahvesi', 'category': 'Sıcak İçecekler', 'price': 40.0},
      {'name': 'Sütlaç', 'category': 'Tatlılar', 'price': 70.0},
      {'name': 'Künefe', 'category': 'Tatlılar', 'price': 90.0},
    ];

    // "INSERT OR IGNORE" komutu sayesinde, bu ürünler zaten varsa tekrar eklenmez.
    final stmt = db.prepare(
      'INSERT OR IGNORE INTO MenuItems (name, category, price) VALUES (?, ?, ?)',
    );
    for (var item in items) {
      stmt.execute([item['name'], item['category'], item['price']]);
    }
    stmt.dispose();
    print(
      '✅ Örnek menü ürünleri eklendi/kontrol edildi.',
    ); // Mesajı biraz değiştirdim
  }
}
