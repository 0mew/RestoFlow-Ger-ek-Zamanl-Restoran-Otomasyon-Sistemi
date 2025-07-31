import 'dart:convert';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sqlite3/sqlite3.dart';
import 'database_helper.dart';

final List<WebSocketChannel> _clients = [];

Future<void> runServer() async {
  DatabaseHelper.initializeDatabase();
  final handler = webSocketHandler((WebSocketChannel webSocket) {
    print(
      '🔗 Yeni bir istemci bağlandı! (HashCode: ${webSocket.hashCode})',
    ); // HashCode eklendi
    _clients.add(webSocket);
    print(
      '    -> _clients güncel boyutu (eklendi): ${_clients.length}',
    ); // Eklendikten sonraki boyut

    webSocket.stream.listen(
      (message) => handleMessage(message, webSocket),
      onDone: () {
        print(' İSTEMCİ BAĞLANTISI KESİLDİ (onDone)');
        print('    -> Kesilen İstemci HashCode: ${webSocket.hashCode}');
        _clients.remove(webSocket);
        print('    -> _clients güncel boyutu (çıkarıldı): ${_clients.length}');
      },
      onError: (error) {
        print(' İSTEMCİ BAĞLANTISINDA HATA (onError) ');
        print('    -> Hata Alan İstemci HashCode: ${webSocket.hashCode}');
        print('    -> Hata Detayı: $error');
        _clients.remove(webSocket);
        print('    -> _clients güncel boyutu (çıkarıldı): ${_clients.length}');
      },
    );
  });

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('🚀 Sunucu çalışıyor: ws://${server.address.host}:${server.port}');
}

void handleMessage(String message, WebSocketChannel client) {
  try {
    final decodedMessage = jsonDecode(message);
    final type = decodedMessage['type'];
    final payload =
        decodedMessage.containsKey('payload')
            ? decodedMessage['payload']
            : null;

    print('➡️ Gelen Mesaj Tipi: $type');

    switch (type) {
      case 'login':
        _handleLogin(payload, client);
        break;

      case 'get_tables':
        _handleGetTables(client);
        break;

      case 'get_menu':
        _handleGetMenu(client);
        break;

      case 'new_order':
        _handleNewOrder(payload);
        break;
      case 'order_ready_for_pickup': // Mesaj tipini daha açıklayıcı yapalım
        _handleOrderReadyForPickup(payload);
        break;
      case 'order_delivered':
        _handleOrderDelivered(payload);
        break;

      case 'get_orders_for_table':
        _handleGetOrdersForTable(payload, client);
        break;

      case 'customer_table_login':
        _handleCustomerTableLogin(payload, client);
        break;

      case 'process_payment':
        _handleProcessPayment(
          payload,
          client,
        ); // client'ı da gönderelim, güncel veriyi geri yollamak için
        break;
      case 'add_staff':
        _handleAddStaff(payload, client);
        break;
      case 'get_staff_list':
        _handleGetStaffList(client);
        break;
      case 'delete_staff':
        _handleDeleteStaff(payload, client);
        break;
      case 'add_menu_item':
        _handleAddMenuItem(payload, client);
        break;
      case 'edit_menu_item':
        _handleEditMenuItem(payload, client);
        break;
      case 'delete_menu_item':
        _handleDeleteMenuItem(payload, client);
        break;
      case 'update_table_count':
        _handleUpdateTableCount(payload, client);
        break;
      case 'get_sales_report':
        _handleGetSalesReport(payload, client);
        break;
      case 'clear_table':
        _handleClearTable(payload);
        break;
      default:
        print(' bilinmeyen mesaj tipi: $type');
    }
  } catch (e) {
    print('❌ Sunucu: Gelen mesaj işlenirken hata oluştu: $e');
    print('Hatalı Ham Mesaj: $message');
    print('Gelen mesaj işlenirken hata oluştu: $e');
  }
}

void _handleClearTable(dynamic payload) {
  if (payload == null || payload['table_id'] == null) {
    print('❌ Masa temizlenemedi: Eksik payload.');
    return;
  }
  final tableId = payload['table_id'] as int;
  final db = DatabaseHelper.db;

  try {
    // Bu masaya ait tüm siparişlerin ID'lerini bul
    final orderIdsResult = db.select(
      'SELECT id FROM Orders WHERE table_id = ?',
      [tableId],
    );

    if (orderIdsResult.isNotEmpty) {
      final orderIds = orderIdsResult.map((row) => row['id'] as int).toList();
      final placeholders = orderIds.map((_) => '?').join(',');

      // Önce bu siparişlere ait tüm OrderItems kayıtlarını sil
      print(
        'ℹ️ Masa ID $tableId için OrderItems temizleniyor (Sipariş ID\'leri: $orderIds)...',
      );
      db.execute(
        'DELETE FROM OrderItems WHERE order_id IN ($placeholders)',
        orderIds,
      );

      // Sonra Orders kayıtlarını sil
      print('ℹ️ Masa ID $tableId için Orders temizleniyor...');
      db.execute('DELETE FROM Orders WHERE id IN ($placeholders)', orderIds);
    } else {
      print('ℹ️ Masa ID $tableId için zaten temizlenecek sipariş yok.');
    }

    // Son olarak masanın durumunu 'available' yap
    final stmt = db.prepare(
      "UPDATE Tables SET status = 'available' WHERE id = ?",
    );
    stmt.execute([tableId]);
    stmt.dispose();
    print(
      '✅ Masa ID $tableId durumu "available" olarak güncellendi (Masa Boşaltıldı).',
    );

    // Değişikliği tüm istemcilere yayınla
    _broadcast(
      jsonEncode({
        'type': 'table_status_update',
        'payload': {'id': tableId, 'status': 'available'},
      }),
    );
  } catch (e) {
    print('❌ Masa temizlenirken hata: $e');
    // İsteğe bağlı olarak istemciye hata mesajı gönderilebilir.
  }
}

void _handleGetSalesReport(dynamic payload, WebSocketChannel client) {
  final db = DatabaseHelper.db;

  try {
    final reportItemsQuery = '''
      SELECT
        mi.name AS product_name,
        mi.category AS product_category,
        SUM(oi.quantity) AS total_quantity_sold,
        mi.price AS unit_price,
        SUM(oi.quantity * mi.price) AS total_revenue_for_product
      FROM OrderItems oi
      JOIN MenuItems mi ON oi.menu_item_id = mi.id
      WHERE oi.payment_status = 'paid'
      GROUP BY mi.id, mi.name, mi.category, mi.price
      ORDER BY total_revenue_for_product DESC;
    ''';
    final reportItems = db.select(reportItemsQuery);

    // ...
    // Genel toplam geliri hesapla
    double overallTotalRevenue = 0;
    for (var item in reportItems) {
      overallTotalRevenue +=
          (item['total_revenue_for_product'] as num).toDouble();
    }

    print(
      '✅ Satış raporu oluşturuldu. ${reportItems.length} farklı ürün, Toplam Gelir: $overallTotalRevenue',
    );
    client.sink.add(
      jsonEncode({
        'type': 'sales_report_data',
        'payload': {
          'report_items': reportItems,
          'overall_total_revenue': overallTotalRevenue,
        },
      }),
    );
  } catch (e) {
    print('❌ Satış raporu oluşturulurken hata: $e');
    client.sink.add(
      jsonEncode({
        'type': 'sales_report_failure',
        'payload': {'message': 'Satış raporu oluşturulurken bir hata oluştu.'},
      }),
    );
  }
}

/*
void _handleUpdateTableCount(dynamic payload, WebSocketChannel client) {
  if (payload == null || payload['new_count'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_failure',
        'payload': {'message': 'Yeni masa sayısı bilgisi eksik.'},
      }),
    );
    return;
  }

  final newCount = payload['new_count'] as int;
  if (newCount <= 0) {
    // En az 1 masa olmalı gibi bir kural koyabiliriz
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_failure',
        'payload': {'message': 'Masa sayısı pozitif bir değer olmalı.'},
      }),
    );
    return;
  }

  final db = DatabaseHelper.db;
  String operationMessage = "";

  try {
    final currentTablesResult = db.select(
      'SELECT id, table_number, status FROM Tables ORDER BY table_number ASC',
    );
    final currentCount = currentTablesResult.length;

    if (newCount > currentCount) {
      // Masa sayısını artır
      int addedCount = 0;
      int maxTableNumber = 0;
      if (currentTablesResult.isNotEmpty) {
        maxTableNumber = currentTablesResult
            .map((row) => row['table_number'] as int)
            .reduce((a, b) => a > b ? a : b);
      }

      final stmt = db.prepare(
        'INSERT INTO Tables (table_number, status) VALUES (?, \'available\')',
      );
      for (int i = 0; i < (newCount - currentCount); i++) {
        maxTableNumber++;
        stmt.execute([maxTableNumber]);
        addedCount++;
      }
      stmt.dispose();
      operationMessage = '$addedCount adet yeni masa eklendi.';
    } else if (newCount < currentCount) {
      // Masa sayısını azalt
      int removedCount = 0;
      int MusaitOlmayanSilinemeyenSayisi = 0;
      // En yüksek numaralı masalardan başlayarak sil, sadece 'available' olanları
      final tablesToDelete = db.select(
        'SELECT id, table_number FROM Tables WHERE status = \'available\' ORDER BY table_number DESC LIMIT ?',
        [currentCount - newCount],
      );

      if (tablesToDelete.length < (currentCount - newCount) &&
          tablesToDelete.isNotEmpty) {
        MusaitOlmayanSilinemeyenSayisi =
            (currentCount - newCount) - tablesToDelete.length;
      } else if (tablesToDelete.isEmpty && currentCount > newCount) {
        MusaitOlmayanSilinemeyenSayisi = currentCount - newCount;
      }

      if (tablesToDelete.isNotEmpty) {
        final stmt = db.prepare('DELETE FROM Tables WHERE id = ?');
        for (var table in tablesToDelete) {
          stmt.execute([table['id']]);
          removedCount++;
        }
        stmt.dispose();
      }
      operationMessage = '$removedCount adet masa silindi.';
      if (MusaitOlmayanSilinemeyenSayisi > 0) {
        operationMessage +=
            ' $MusaitOlmayanSilinemeyenSayisi adet masa kullanımda olduğu için silinemedi.';
      }
    } else {
      operationMessage = 'Masa sayısında değişiklik yapılmadı.';
    }

    final updatedTablesAfterOperation = db.select('SELECT * FROM Tables');
    print(
      '✅ Masa sayısı güncellendi. Yeni toplam: ${updatedTablesAfterOperation.length}. Mesaj: $operationMessage',
    );
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_success',
        'payload': {
          'message': operationMessage,
          'new_actual_count':
              updatedTablesAfterOperation.length, // Gerçekleşen sayıyı gönder
        },
      }),
    );

    // Tüm istemcilere güncel masa listesini veya bir "yenileme" mesajı yayınla
    _broadcast(jsonEncode({'type': 'table_list_refresh_required'}));
  } catch (e) {
    print('❌ Masa sayısı güncellenirken hata: $e');
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_failure',
        'payload': {'message': 'Masa sayısı güncellenirken bir hata oluştu.'},
      }),
    );
  }
}
*/
void _handleUpdateTableCount(dynamic payload, WebSocketChannel client) {
  if (payload == null || payload['new_count'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_failure',
        'payload': {'message': 'Yeni masa sayısı bilgisi eksik.'},
      }),
    );
    return;
  }

  final newCount = payload['new_count'] as int;
  if (newCount < 0) {
    // Masa sayısı 0 olabilir ama negatif olamaz
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_failure',
        'payload': {'message': 'Masa sayısı negatif olamaz.'},
      }),
    );
    return;
  }

  final db = DatabaseHelper.db;
  String operationMessage = "";

  try {
    final currentTablesResult = db.select(
      'SELECT id, table_number, status FROM Tables ORDER BY table_number ASC',
    );
    final currentCount = currentTablesResult.length;

    if (newCount > currentCount) {
      // Masa sayısını artırma mantığı
      int addedCount = 0;
      int maxTableNumber = 0;
      if (currentTablesResult.isNotEmpty) {
        maxTableNumber = currentTablesResult
            .map((row) => row['table_number'] as int)
            .reduce((a, b) => a > b ? a : b);
      }

      final stmt = db.prepare(
        'INSERT INTO Tables (table_number, status) VALUES (?, \'available\')',
      );
      for (int i = 0; i < (newCount - currentCount); i++) {
        maxTableNumber++;
        stmt.execute([maxTableNumber]);
        addedCount++;
      }
      stmt.dispose();
      operationMessage = '$addedCount adet yeni masa eklendi.';
    } else if (newCount < currentCount) {
      // Masa sayısını azaltma mantığı
      int removedCount = 0;
      int notAvailableCount = 0;
      final tablesToDeleteQuery = db.select(
        'SELECT id FROM Tables WHERE status = \'available\' ORDER BY table_number DESC LIMIT ?',
        [currentCount - newCount],
      );
      notAvailableCount =
          (currentCount - newCount) - tablesToDeleteQuery.length;

      if (tablesToDeleteQuery.isNotEmpty) {
        final stmt = db.prepare('DELETE FROM Tables WHERE id = ?');
        for (var table in tablesToDeleteQuery) {
          stmt.execute([table['id']]);
          removedCount++;
        }
        stmt.dispose();
      }
      operationMessage = '$removedCount adet masa silindi.';
      if (notAvailableCount > 0) {
        operationMessage +=
            ' $notAvailableCount adet masa kullanımda olduğu için silinemedi.';
      }
    } else {
      operationMessage = 'Masa sayısında değişiklik yapılmadı.';
    }

    // --- DÖNGÜYÜ KIRAN DEĞİŞİKLİĞİN OLDUĞU KISIM BURASI ---

    // 1. İşlem sonrası güncel masa listesini al
    final updatedTablesAfterOperation = db.select(
      'SELECT * FROM Tables ORDER BY table_number ASC',
    );
    print(
      '✅ Masa sayısı güncellendi. Yeni toplam: ${updatedTablesAfterOperation.length}. Mesaj: $operationMessage',
    );

    // 2. İsteği yapan admine özel başarı mesajı gönder
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_success',
        'payload': {
          'message': operationMessage,
          'new_actual_count': updatedTablesAfterOperation.length,
        },
      }),
    );

    // 3. "Yenile" mesajı göndermek yerine, TÜM İSTEMCİLERE doğrudan güncel masa listesini yayınla
    _broadcast(
      jsonEncode({
        'type': 'table_list', // Tipi 'table_list' yapıyoruz
        'payload':
            updatedTablesAfterOperation, // Payload'a güncel listeyi koyuyoruz
      }),
    );
    print(
      '📢 Güncel masa listesi (${updatedTablesAfterOperation.length} adet) tüm istemcilere yayınlandı.',
    );
  } catch (e) {
    print('❌ Masa sayısı güncellenirken hata: $e');
    client.sink.add(
      jsonEncode({
        'type': 'update_table_count_failure',
        'payload': {'message': 'Masa sayısı güncellenirken bir hata oluştu.'},
      }),
    );
  }
}

void _handleDeleteMenuItem(dynamic payload, WebSocketChannel client) {
  if (payload == null || payload['item_id'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'delete_menu_item_failure',
        'payload': {'message': 'Silinecek ürün ID\'si eksik.'},
      }),
    );
    return;
  }

  final itemId = payload['item_id'] as int;
  final db = DatabaseHelper.db;

  try {
    final stmt = db.prepare('DELETE FROM MenuItems WHERE id = ?');
    stmt.execute([itemId]);
    stmt.dispose();
    // SQLite'ta execute sonrası etkilenen satır sayısı için db.getUpdatedRows() kullanılabilir,
    // ancak stmt.execute hata vermediyse ve ürün o ID ile varsa silinmiştir.
    // Eğer bir FOREIGN KEY kısıtlaması varsa (OrderItems'da bu menu_item_id kullanılıyorsa),
    // execute metodu bir SqliteException fırlatacaktır.
    print('✅ Menü ürünü silindi. ID: $itemId');
    client.sink.add(
      jsonEncode({
        'type': 'delete_menu_item_success',
        'payload': {'message': 'Menü ürünü başarıyla silindi.'},
      }),
    );

    // Başarılı silme sonrası tüm istemcilere güncel menüyü yayınlayabiliriz.
    // final allMenuItems = db.select('SELECT * FROM MenuItems ORDER BY category, name');
    // _broadcast(jsonEncode({'type': 'menu_list', 'payload': allMenuItems}));
  } on SqliteException catch (e) {
    // Artık SqliteException tanınmalı
    // Genellikle FOREIGN KEY constraint hatası için result code'lar 19 veya 787 olur.
    // Farklı SQLite implementasyonlarında veya versiyonlarında değişebilir.
    // e.message.contains('FOREIGN KEY constraint failed') gibi bir kontrol daha genel olabilir.
    if (e.toString().toLowerCase().contains('foreign key constraint failed') ||
        e.extendedResultCode == 19 ||
        e.extendedResultCode == 787) {
      print(
        '❌ Menü ürünü silinemedi (siparişlerde kullanılıyor). ID: $itemId, Hata Kodu: ${e.extendedResultCode}, Hata: $e',
      );
      client.sink.add(
        jsonEncode({
          'type': 'delete_menu_item_failure',
          'payload': {
            'message':
                'Bu ürün mevcut siparişlerde kullanıldığı için silinemez.',
          },
        }),
      );
    } else {
      print('❌ Menü ürünü silinirken veritabanı hatası: $e');
      client.sink.add(
        jsonEncode({
          'type': 'delete_menu_item_failure',
          'payload': {
            'message': 'Menü ürünü silinirken bir veritabanı hatası oluştu.',
          },
        }),
      );
    }
  } catch (e) {
    print('❌ Menü ürünü silinirken genel hata: $e');
    client.sink.add(
      jsonEncode({
        'type': 'delete_menu_item_failure',
        'payload': {
          'message': 'Menü ürünü silinirken beklenmedik bir hata oluştu.',
        },
      }),
    );
  }
}

void _handleEditMenuItem(dynamic payload, WebSocketChannel client) {
  if (payload == null ||
      payload['id'] == null ||
      payload['name'] == null ||
      payload['category'] == null ||
      payload['price'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'edit_menu_item_failure',
        'payload': {'message': 'Eksik ürün bilgisi gönderildi.'},
      }),
    );
    return;
  }

  final id = payload['id'] as int;
  final name = payload['name'] as String;
  final category = payload['category'] as String;
  final price = (payload['price'] as num).toDouble();

  if (name.isEmpty || category.isEmpty || price <= 0) {
    client.sink.add(
      jsonEncode({
        'type': 'edit_menu_item_failure',
        'payload': {'message': 'Geçersiz ürün adı, kategori veya fiyat.'},
      }),
    );
    return;
  }

  final db = DatabaseHelper.db;

  try {
    // Yeni isim ve kategori kombinasyonunun başka bir ürüne ait olup olmadığını kontrol et
    final existingItem = db.select(
      'SELECT id FROM MenuItems WHERE name = ? AND category = ? AND id != ?',
      [name, category, id],
    );
    if (existingItem.isNotEmpty) {
      client.sink.add(
        jsonEncode({
          'type': 'edit_menu_item_failure',
          'payload': {
            'message': 'Bu isim ve kategoride başka bir ürün zaten mevcut.',
          },
        }),
      );
      return;
    }

    // Ürünü güncelle
    final stmt = db.prepare(
      'UPDATE MenuItems SET name = ?, category = ?, price = ? WHERE id = ?',
    );
    stmt.execute([name, category, price, id]);
    stmt.dispose();

    // Güncellemenin etkisini kontrol et (opsiyonel, execute hata vermediyse başarılıdır)
    // final changes = db.getUpdatedRows();
    // if (changes == 0) { ... }

    print('✅ Menü ürünü güncellendi: ID: $id, Yeni Ad: $name');
    client.sink.add(
      jsonEncode({
        'type': 'edit_menu_item_success',
        'payload': {'message': '"$name" başarıyla güncellendi.'},
      }),
    );
  } catch (e) {
    print('❌ Menü ürünü güncellenirken veritabanı hatası: $e');
    client.sink.add(
      jsonEncode({
        'type': 'edit_menu_item_failure',
        'payload': {
          'message': 'Menü ürünü güncellenirken bir sunucu hatası oluştu.',
        },
      }),
    );
  }
}

void _handleAddMenuItem(dynamic payload, WebSocketChannel client) {
  if (payload == null ||
      payload['name'] == null ||
      payload['category'] == null ||
      payload['price'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'add_menu_item_failure',
        'payload': {'message': 'Eksik ürün bilgisi gönderildi.'},
      }),
    );
    return;
  }

  final name = payload['name'] as String;
  final category = payload['category'] as String;
  final price =
      (payload['price'] as num)
          .toDouble(); // Fiyatın double olduğundan emin olalım

  if (name.isEmpty || category.isEmpty || price <= 0) {
    client.sink.add(
      jsonEncode({
        'type': 'add_menu_item_failure',
        'payload': {'message': 'Geçersiz ürün adı, kategori veya fiyat.'},
      }),
    );
    return;
  }

  final db = DatabaseHelper.db;

  try {
    // İsteğe bağlı: Aynı isim ve kategoride ürün var mı diye kontrol edilebilir.
    // Şimdilik bu kontrolü eklemiyoruz, aynı isimde farklı ID'li ürünler olabilir.

    final stmt = db.prepare(
      'INSERT INTO MenuItems (name, category, price) VALUES (?, ?, ?)',
    );
    stmt.execute([name, category, price]);
    final newItemId = db.lastInsertRowId;
    stmt.dispose();

    print(
      '✅ Yeni menü ürünü eklendi: $name, Kategori: $category, Fiyat: $price, ID: $newItemId',
    );
    client.sink.add(
      jsonEncode({
        'type': 'add_menu_item_success',
        'payload': {'message': '$name başarıyla menüye eklendi.'},
      }),
    );

    // Tüm istemcilere (özellikle garson ve diğer adminlere) güncel menüyü yayınla
    // _handleGetMenu'nun içindeki mantığı kullanarak bir broadcast yapabiliriz.
    // Ya da basitçe tüm menüyü bu client'a geri gönderebiliriz veya client'ın yeniden çekmesini bekleyebiliriz.
    // Şimdilik client'ın yeniden çekmesini bekleyelim.
    // Ancak, daha iyi bir UX için burada güncel menüyü tüm client'lara broadcast etmek daha iyi olurdu:
    // final allMenuItems = db.select('SELECT * FROM MenuItems ORDER BY category, name');
    // _broadcast(jsonEncode({'type': 'menu_list', 'payload': allMenuItems}));
    // print('📢 Güncel menü listesi tüm istemcilere yayınlandı.');
  } catch (e) {
    print('❌ Menü ürünü eklenirken veritabanı hatası: $e');
    client.sink.add(
      jsonEncode({
        'type': 'add_menu_item_failure',
        'payload': {
          'message': 'Menü ürünü eklenirken bir sunucu hatası oluştu.',
        },
      }),
    );
  }
}

void _handleDeleteStaff(dynamic payload, WebSocketChannel client) {
  if (payload == null || payload['user_id'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'delete_staff_failure',
        'payload': {'message': 'Silinecek personel ID\'si eksik.'},
      }),
    );
    return;
  }

  final userId = payload['user_id'] as int;
  final db = DatabaseHelper.db;

  try {
    // Admin rolündeki kullanıcıların bu yolla silinmesini engelleyelim (güvenlik için)
    final userToDelete = db.select('SELECT role FROM Users WHERE id = ?', [
      userId,
    ]);
    if (userToDelete.isEmpty) {
      client.sink.add(
        jsonEncode({
          'type': 'delete_staff_failure',
          'payload': {'message': 'Silinecek personel bulunamadı.'},
        }),
      );
      return;
    }
    if (userToDelete.first['role'] == 'admin') {
      client.sink.add(
        jsonEncode({
          'type': 'delete_staff_failure',
          'payload': {'message': 'Admin kullanıcısı bu arayüzden silinemez.'},
        }),
      );
      return;
    }

    final stmt = db.prepare('DELETE FROM Users WHERE id = ?');
    stmt.execute([userId]);
    stmt.dispose();

    // Silme işleminin başarılı olup olmadığını kontrol et (etkilenen satır sayısı)
    // sqlite3 paketi doğrudan etkilenen satır sayısını vermiyor,
    // bu yüzden silme sonrası kullanıcıyı tekrar sorgulayarak kontrol edebiliriz veya
    // direkt başarılı kabul edebiliriz eğer execute hata vermediyse.
    // Şimdilik execute hata vermediyse başarılı kabul edelim.

    print('✅ Personel silindi. ID: $userId');
    client.sink.add(
      jsonEncode({
        'type': 'delete_staff_success',
        'payload': {'message': 'Personel başarıyla silindi.'},
      }),
    );
  } catch (e) {
    print('❌ Personel silinirken veritabanı hatası: $e');
    client.sink.add(
      jsonEncode({
        'type': 'delete_staff_failure',
        'payload': {'message': 'Personel silinirken bir sunucu hatası oluştu.'},
      }),
    );
  }
}

void _handleGetStaffList(WebSocketChannel client) {
  final db = DatabaseHelper.db;
  final staff = db.select(
    "SELECT id, username, role FROM Users WHERE role = 'waiter' OR role = 'kitchen' ORDER BY role, username",
  );

  // --- YENİ DEBUG PRINT ---
  final payloadToPrint = {'type': 'staff_list_data', 'payload': staff};
  print(
    'DEBUG SERVER: _handleGetStaffList payload gönderiliyor: ${jsonEncode(payloadToPrint)}',
  );
  // ------------------------

  client.sink.add(jsonEncode(payloadToPrint));
  // Eski log mesajı, payloadToPrint içinde type olduğu için sadeleştirilebilir:
  print(
    'ℹ️ ${staff.length} adet personel bilgisi admin istemcisine gönderildi.',
  );
}

void _handleAddStaff(dynamic payload, WebSocketChannel client) {
  if (payload == null ||
      payload['username'] == null ||
      payload['password'] == null ||
      payload['role'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'add_staff_failure',
        'payload': {'message': 'Eksik bilgi gönderildi.'},
      }),
    );
    return;
  }

  final username = payload['username'] as String;
  final password = payload['password'] as String;
  final role = payload['role'] as String;

  if (username.isEmpty ||
      password.isEmpty ||
      (role != 'waiter' && role != 'kitchen')) {
    client.sink.add(
      jsonEncode({
        'type': 'add_staff_failure',
        'payload': {'message': 'Geçersiz kullanıcı adı, şifre veya rol.'},
      }),
    );
    return;
  }

  final db = DatabaseHelper.db;

  try {
    // Kullanıcı adının benzersiz olup olmadığını kontrol et
    final existingUser = db.select('SELECT id FROM Users WHERE username = ?', [
      username,
    ]);
    if (existingUser.isNotEmpty) {
      client.sink.add(
        jsonEncode({
          'type': 'add_staff_failure',
          'payload': {'message': 'Bu kullanıcı adı zaten mevcut.'},
        }),
      );
      return;
    }

    // Yeni kullanıcıyı ekle
    final stmt = db.prepare(
      'INSERT INTO Users (username, password, role) VALUES (?, ?, ?)',
    );
    stmt.execute([username, password, role]);
    final newUserId = db.lastInsertRowId;
    stmt.dispose();

    print('✅ Yeni personel eklendi: $username, Rol: $role, ID: $newUserId');
    client.sink.add(
      jsonEncode({
        'type': 'add_staff_success',
        'payload': {'message': '$username başarıyla eklendi.'},
        // İsteğe bağlı olarak yeni eklenen kullanıcının tüm bilgileri de gönderilebilir.
      }),
    );

    // Diğer adminlere veya tüm adminlere güncel personel listesini yayınlayabiliriz.
    // Şimdilik, isteği yapan adminin listeyi yeniden çekmesini bekleyeceğiz.
  } catch (e) {
    print('❌ Personel eklenirken veritabanı hatası: $e');
    client.sink.add(
      jsonEncode({
        'type': 'add_staff_failure',
        'payload': {'message': 'Personel eklenirken bir sunucu hatası oluştu.'},
      }),
    );
  }
}

void _handleProcessPayment(dynamic payload, WebSocketChannel client) {
  if (payload == null ||
      payload['table_id'] == null ||
      payload['paid_order_item_ids'] == null) {
    // Gerekli bilgi eksikse istemciye hata döndürebiliriz, şimdilik loglayalım.
    print('❌ Ödeme işlenemedi: Eksik payload.');
    return;
  }

  final tableId = payload['table_id'] as int;
  final paidOrderItemIds = (payload['paid_order_item_ids'] as List).cast<int>();
  final db = DatabaseHelper.db;

  try {
    // 1. Seçilen OrderItem'ların payment_status'unu 'paid' yap
    if (paidOrderItemIds.isNotEmpty) {
      final placeholders = paidOrderItemIds.map((_) => '?').join(',');
      final stmtUpdateItems = db.prepare(
        'UPDATE OrderItems SET payment_status = \'paid\' WHERE id IN ($placeholders)',
      );
      stmtUpdateItems.execute(paidOrderItemIds);
      stmtUpdateItems.dispose();
      print(
        '✅ ${paidOrderItemIds.length} adet sipariş kalemi "paid" olarak güncellendi.',
      );
    }

    // 2. Bu masaya ait tüm sipariş kalemlerinin ödenip ödenmediğini kontrol et
    final unpaidItemsResult = db.select(
      '''
      SELECT COUNT(*) as unpaid_count 
      FROM OrderItems oi
      JOIN Orders o ON oi.order_id = o.id
      WHERE o.table_id = ? AND oi.payment_status = 'unpaid'
      ''',
      [tableId],
    );

    bool allItemsPaidForTable = false;
    if (unpaidItemsResult.isNotEmpty &&
        (unpaidItemsResult.first['unpaid_count'] as int) == 0) {
      allItemsPaidForTable = true;
    }

    // 3. Eğer masadaki tüm ürünler ödendiyse, masanın durumunu 'available' yap
    if (allItemsPaidForTable) {
      print(
        '✅ Masa ID $tableId için tüm ürünler ödendi. Durum "Masa Boş" butonuna kadar değiştirilmeyecek.',
      );
    } else {
      print('ℹ️ Masa ID $tableId için hala ödenmemiş ürünler var.');
    }

    print(
      'ℹ️ Masa ID $tableId için güncel sipariş detayları ödeme yapan istemciye gönderiliyor.',
    );
    _handleGetOrdersForTable({'table_id': tableId}, client);
  } catch (e) {
    print('❌ Ödeme işlenirken veritabanı hatası: $e');
    client.sink.add(
      jsonEncode({
        'type': 'payment_processing_error',
        'payload': {'message': 'Ödeme işlenirken bir sunucu hatası oluştu.'},
      }),
    );
  }
}

void _handleCustomerTableLogin(dynamic payload, WebSocketChannel client) {
  if (payload == null || payload['table_number'] == null) {
    client.sink.add(
      jsonEncode({
        'type': 'customer_table_login_error',
        'payload': {'message': 'Masa numarası eksik.'},
      }),
    );
    return;
  }

  final tableNumber = payload['table_number'] as int;
  final db = DatabaseHelper.db;

  // 1. Masa numarasından table_id ve durumunu bul
  final tableResult = db.select(
    'SELECT id, status FROM Tables WHERE table_number = ?',
    [tableNumber],
  );
  if (tableResult.isEmpty) {
    client.sink.add(
      jsonEncode({
        'type': 'customer_table_login_error',
        'payload': {'message': 'Masa bulunamadı.'},
      }),
    );
    return;
  }
  final tableId = tableResult.first['id'] as int;
  final tableStatus = tableResult.first['status'] as String;

  // 2. Bu masaya ait tüm siparişleri (OrderItems ile birlikte) çek
  // Bu sorgu, _handleGetOrdersForTable'dakine çok benzer olacak, ödeme durumunu da ekleyelim.
  final query = '''
    SELECT
      o.id as order_id,
      t.table_number,
      o.status as order_status, 
      mi.name as menu_item_name,
      mi.price as menu_item_price,
      oi.id as order_item_id,
      oi.quantity,
      oi.notes,
      oi.payment_status
    FROM Orders o
    JOIN Tables t ON o.table_id = t.id
    JOIN OrderItems oi ON o.id = oi.order_id
    JOIN MenuItems mi ON oi.menu_item_id = mi.id
    WHERE o.table_id = ? 
    ORDER BY o.id ASC, oi.id ASC 
  '''; // Müşteri tüm siparişleri (completed dahil) görmeli
  final orderItemsResults = db.select(query, [tableId]);

  Map<int, Map<String, dynamic>> groupedOrders = {};
  for (var row in orderItemsResults) {
    final orderId = row['order_id'] as int;
    if (!groupedOrders.containsKey(orderId)) {
      groupedOrders[orderId] = {
        'order_id': orderId,
        'table_number': row['table_number'],
        'order_status': row['order_status'],
        'items': [],
      };
    }
    (groupedOrders[orderId]!['items'] as List).add({
      'order_item_id': row['order_item_id'],
      'name': row['menu_item_name'],
      'quantity': row['quantity'],
      'notes': row['notes'] ?? '',
      'price': row['menu_item_price'],
      'payment_status': row['payment_status'],
    });
  }

  client.sink.add(
    jsonEncode({
      'type': 'customer_table_data',
      'payload': {
        'table_id': tableId,
        'table_number': tableNumber,
        'table_status': tableStatus,
        'orders': groupedOrders.values.toList(),
      },
    }),
  );
  print('✅ Müşteri için Masa $tableNumber (ID: $tableId) verileri gönderildi.');
}

void _handleGetOrdersForTable(dynamic payload, WebSocketChannel client) {
  if (payload == null || payload['table_id'] == null) {
    print("❌ _handleGetOrdersForTable: table_id eksik.");
    return;
  }
  final tableId = payload['table_id'];
  final db = DatabaseHelper.db;

  final query = '''
    SELECT
      o.id as order_id,
      t.table_number,
      o.status as order_status, 
      mi.name as menu_item_name,
      mi.price as menu_item_price,
      oi.id as order_item_id,
      oi.quantity,
      oi.notes,
      oi.payment_status
    FROM Orders o
    JOIN Tables t ON o.table_id = t.id
    JOIN OrderItems oi ON o.id = oi.order_id
    JOIN MenuItems mi ON oi.menu_item_id = mi.id
    WHERE o.table_id = ?
    ORDER BY o.id ASC, oi.id ASC 
  ''';
  final results = db.select(query, [tableId]);

  Map<int, Map<String, dynamic>> groupedOrders = {};
  for (var row in results) {
    final orderId = row['order_id'] as int;
    if (!groupedOrders.containsKey(orderId)) {
      groupedOrders[orderId] = {
        'order_id': orderId,
        'table_number': row['table_number'],
        'order_status': row['order_status'],
        'items': [],
      };
    }

    (groupedOrders[orderId]!['items'] as List).add({
      'order_item_id': row['order_item_id'],
      'menu_item_name': row['menu_item_name'],
      'quantity': row['quantity'],
      'notes': row['notes'] ?? '',
      'menu_item_price': row['menu_item_price'],
      'payment_status': row['payment_status'],
    });
  }

  final ordersForTablePayload = groupedOrders.values.toList();
  client.sink.add(
    jsonEncode({
      'type': 'orders_for_table_data',
      'payload': ordersForTablePayload,
    }),
  );
}

void _handleOrderDelivered(dynamic payload) {
  if (payload == null) return;

  final orderId = payload['order_id'];
  final db = DatabaseHelper.db;

  try {
    var stmt = db.prepare('UPDATE Orders SET status = ? WHERE id = ?');
    stmt.execute(['completed', orderId]);
    stmt.dispose();
    print('✅ Sipariş ID $orderId durumu "completed" olarak güncellendi.');

    final orderInfo = db.select('SELECT table_id FROM Orders WHERE id = ?', [
      orderId,
    ]);
    if (orderInfo.isNotEmpty) {
      final tableId = orderInfo.first['table_id'];

      stmt = db.prepare("UPDATE Tables SET status = 'delivered' WHERE id = ?");
      stmt.execute([tableId]);
      stmt.dispose();
      print('✅ Masa ID $tableId durumu "delivered" olarak güncellendi.');

      _broadcast(
        jsonEncode({
          'type': 'table_status_update',
          'payload': {'id': tableId, 'status': 'delivered'},
        }),
      );
      print('✅ Masa ID $tableId için "delivered" durumu yayınlandı.');
    }
  } catch (e) {
    print('❌ Sipariş teslim edildi bilgisi işlenirken hata: $e');
  }
}

void _handleLogin(dynamic payload, WebSocketChannel client) {
  if (payload == null) return;

  final username = payload['username'];
  final password = payload['password'];

  final stmt = DatabaseHelper.db.prepare(
    'SELECT * FROM Users WHERE username = ? AND password = ?',
  );
  final result = stmt.select([username, password]);
  stmt.dispose();

  if (result.isNotEmpty) {
    final user = result.first;
    print('✅ Başarılı Giriş -> Cevap Gönderiliyor: ${user['username']}');
    client.sink.add(
      jsonEncode({
        'type': 'login_success',
        'payload': {'username': user['username'], 'role': user['role']},
      }),
    );
  } else {
    print('❌ Başarısız Giriş -> Cevap Gönderiliyor: $username');
    client.sink.add(
      jsonEncode({
        'type': 'login_failure',
        'payload': {'message': 'Kullanıcı adı veya şifre hatalı!'},
      }),
    );
  }
}

void _handleGetTables(WebSocketChannel client) {
  final tables = DatabaseHelper.db.select(
    'SELECT * FROM Tables ORDER BY table_number ASC',
  );
  print('ℹ️ ${tables.length} adet masa bilgisi istemciye gönderiliyor.');

  client.sink.add(jsonEncode({'type': 'table_list', 'payload': tables}));
}

void _handleGetMenu(WebSocketChannel client) {
  final menuItems = DatabaseHelper.db.select(
    'SELECT * FROM MenuItems ORDER BY category, name',
  );
  print('ℹ️ ${menuItems.length} adet menü ürünü istemciye gönderiliyor.');

  client.sink.add(jsonEncode({'type': 'menu_list', 'payload': menuItems}));
}

void _handleNewOrder(dynamic payload) {
  if (payload == null) return;
  final db = DatabaseHelper.db;
  try {
    final tableId = payload['table_id'];
    final itemsFromClient = payload['items'] as List;
    final now = DateTime.now().toIso8601String();

    var stmt = db.prepare(
      'INSERT INTO Orders (table_id, order_time, status) VALUES (?, ?, ?)',
    );
    stmt.execute([tableId, now, 'pending']);
    final newOrderId = db.lastInsertRowId;
    stmt.dispose();
    print('✅ Yeni sipariş oluşturuldu. Sipariş ID: $newOrderId');

    stmt = db.prepare(
      'INSERT INTO OrderItems (order_id, menu_item_id, quantity, notes) VALUES (?, ?, ?, ?)',
    );
    for (var item in itemsFromClient) {
      stmt.execute([newOrderId, item['id'], item['quantity'], item['notes']]);
    }
    stmt.dispose();

    stmt = db.prepare("UPDATE Tables SET status = 'ordered' WHERE id = ?");
    stmt.execute([tableId]);
    stmt.dispose();
    print('✅ Masa ID $tableId durumu "ordered" olarak güncellendi.');

    _broadcast(
      jsonEncode({
        'type': 'table_status_update',
        'payload': {'id': tableId, 'status': 'ordered'},
      }),
    );

    final orderDetailsQuery = '''
      SELECT 
        o.id as order_id, 
        t.table_number, 
        o.status as order_status, 
        mi.name as menu_item_name, 
        oi.id as order_item_id, 
        oi.quantity, 
        oi.notes, 
        mi.price as menu_item_price, 
        oi.payment_status
      FROM Orders o
      JOIN Tables t ON o.table_id = t.id 
      JOIN OrderItems oi ON o.id = oi.order_id 
      JOIN MenuItems mi ON oi.menu_item_id = mi.id
      WHERE o.id = ?
    ''';
    final orderDetailsResult = db.select(orderDetailsQuery, [newOrderId]);

    if (orderDetailsResult.isNotEmpty) {
      final tableNumber = orderDetailsResult.first['table_number'];
      final orderStatus = orderDetailsResult.first['order_status'];

      final kitchenOrderItems =
          orderDetailsResult
              .map(
                (row) => {
                  'order_item_id': row['order_item_id'],
                  'menu_item_name': row['menu_item_name'],
                  'quantity': row['quantity'],
                  'notes': row['notes'] ?? '',
                  'menu_item_price': row['menu_item_price'],
                  'payment_status': row['payment_status'],
                },
              )
              .toList();

      _broadcast(
        jsonEncode({
          'type': 'new_order_for_kitchen',
          'payload': {
            'order_id': newOrderId,
            'table_number': tableNumber,
            'items': kitchenOrderItems,
            'order_status': orderStatus,
          },
        }),
      );
      print('✅ Sipariş ID $newOrderId mutfağa gönderildi.');
    }
  } catch (e) {
    print('❌ Sipariş işlenirken hata oluştu: $e');
  }
}

void _broadcast(String message) {
  print('📢 Herkese yayın yapılıyor: $message');
  final List<WebSocketChannel> currentClients = List.from(_clients);
  print('ℹ️ Yayın yapılacak istemci sayısı: ${currentClients.length}');
  for (final client in currentClients) {
    try {
      print('➡️ İstemciye gönderiliyor (hashCode: ${client.hashCode})');
      client.sink.add(message);
    } catch (e) {
      print(
        '❌ Bir istemciye yayın yapılırken hata (muhtemelen bağlantısı koptu) for client ${client.hashCode}: $e',
      );
    }
  }
}

void _handleOrderReadyForPickup(dynamic payload) {
  if (payload == null) return;

  final orderId = payload['order_id'];
  final db = DatabaseHelper.db;

  try {
    var stmt = db.prepare('UPDATE Orders SET status = ? WHERE id = ?');
    stmt.execute(['ready', orderId]);
    stmt.dispose();
    print('✅ Sipariş ID $orderId durumu "ready" olarak güncellendi.');

    final orderInfo = db.select('SELECT table_id FROM Orders WHERE id = ?', [
      orderId,
    ]);
    if (orderInfo.isNotEmpty) {
      final tableId = orderInfo.first['table_id'];
      final tableInfo = db.select(
        'SELECT table_number FROM Tables WHERE id = ?',
        [tableId],
      );
      int? tableNumber;
      if (tableInfo.isNotEmpty) {
        tableNumber = tableInfo.first['table_number'];
      }

      _broadcast(
        jsonEncode({
          'type': 'order_pickup_notification',
          'payload': {
            'order_id': orderId,
            'table_number': tableNumber,
            'message': 'Masa $tableNumber için Sipariş ID $orderId hazır!',
          },
        }),
      );
      print('✅ Sipariş ID $orderId için teslim alma bildirimi yayınlandı.');
    }
  } catch (e) {
    print('❌ Sipariş hazır bilgisi işlenirken hata: $e');
  }
}
