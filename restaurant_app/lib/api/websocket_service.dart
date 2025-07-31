import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Model importları
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/kitchen_order_model.dart';
import '../models/order_pickup_notification_model.dart';
import '../models/customer_order_models.dart';
import '../models/user_model.dart';
import '../models/sales_report_models.dart';
// import '../utils/constants.dart'; // WEBSOCKET_URL için artık gerek yok

class WebSocketService with ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool loginEventHandled = true;
  String _currentServerIp =
      "192.168.1.158"; // Varsayılan IP (ilk kurulum için veya kayıtlı IP yoksa)
  static const String _serverPort = "8080";
  static const String _ipPrefKey =
      'restaurant_server_ip_v1'; // Anahtarın benzersiz olması iyi olur

  // State Değişkenleri
  List<TableModel> tables = [];
  List<MenuItemModel> menuItems = [];
  List<KitchenOrderModel> kitchenOrders = [];
  List<KitchenOrderModel> currentTableOrders = [];

  bool isLoggedIn = false;
  String? userRole;
  String? loginErrorMessage;

  TableModel? currentCustomerTable;
  List<CustomerOrderModel> currentCustomerOrders = [];
  String? customerLoginError;

  List<UserModel> staffList = [];
  String? staffManagementMessage;
  bool staffActionSuccess = false;

  String? menuManagementMessage;
  bool menuActionSuccess = false;

  String? tableManagementMessage;
  bool tableActionSuccess = false;
  // currentTableCountFromService yerine doğrudan tables.length kullanılacak.

  SalesReportDataModel? salesReportData;
  String? salesReportMessage;

  final StreamController<OrderPickupNotificationModel>
  _pickupNotificationController =
      StreamController<OrderPickupNotificationModel>.broadcast();
  Stream<OrderPickupNotificationModel> get pickupNotificationEvents =>
      _pickupNotificationController.stream;

  bool get isConnected => _isConnected;
  String get currentServerIpForDisplay => _currentServerIp;
  String get currentFullWebSocketUrl => 'ws://$_currentServerIp:$_serverPort';

  WebSocketService() {
    print(
      "WebSocketService: Constructor çağrıldı, IP ve bağlantı yükleniyor...",
    );

    print(
      "!!! --- YENİ BİR WEBSOCKET_SERVICE NESNESİ OLUŞTURULDU --- !!! HashCode: ${hashCode}",
    );

    print(
      "WebSocketService: Constructor çağrıldı, IP ve bağlantı yükleniyor...",
    );

    _loadIpAndAttemptConnect();
  }

  Future<void> _loadIpAndAttemptConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString(_ipPrefKey);
    if (savedIp != null && savedIp.isNotEmpty) {
      _currentServerIp = savedIp;
    }
    print(
      'ℹ️ WebSocketService: Kullanılacak sunucu IP: $_currentServerIp port: $_serverPort',
    );
    if (!_isConnected) {
      connect();
    }
  }

  Future<void> updateServerIp(String newIp) async {
    final trimmedNewIp = newIp.trim();
    if (_currentServerIp == trimmedNewIp || trimmedNewIp.isEmpty) {
      print('ℹ️ WebSocketService: IP aynı veya boş, değişiklik yapılmadı.');
      return;
    }
    print('ℹ️ WebSocketService: Sunucu IP adresi güncelleniyor: $trimmedNewIp');
    _currentServerIp = trimmedNewIp;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipPrefKey, _currentServerIp);

    disconnect(isReconnecting: true);
    await Future.delayed(const Duration(milliseconds: 300));
    connect();
  }

  void connect() {
    if (_isConnected && _channel != null && _channel?.closeCode == null) {
      print(
        'ℹ️ WebSocketService (${hashCode}): Zaten bağlı ve aktif: $currentFullWebSocketUrl',
      );
      return;
    }

    print(
      'ℹ️ WebSocketService (${hashCode}): Bağlanmaya çalışılıyor: $currentFullWebSocketUrl',
    );
    try {
      final urlToConnect = Uri.parse(
        currentFullWebSocketUrl,
      ); // DİNAMİK URL KULLANILMALI
      _channel = WebSocketChannel.connect(urlToConnect);
      _isConnected = true;
      print(
        '✅ WebSocketService (${hashCode}): Bağlantı isteği gönderildi: $currentFullWebSocketUrl',
      );
      notifyListeners();

      _channel!.stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            print(
              '✅ WebSocketService (${hashCode}): Veri akışı başladı, bağlantı teyit edildi: $currentFullWebSocketUrl',
            );
            notifyListeners();
          }
          print(
            '*** WebSocketService (${hashCode}): HAM VERİ ALINDI: $data ***',
          );
          _handleIncomingMessage(data);
        },
        onDone: () {
          _isConnected = false;
          isLoggedIn = false;
          userRole = null;
          loginErrorMessage = 'Sunucu bağlantısı beklenmedik şekilde kapandı.';
          print(
            '🔌 WebSocketService (${hashCode}): Bağlantı sonlandı (onDone). URL: $currentFullWebSocketUrl',
          );
          notifyListeners();
        },
        onError: (error) {
          _isConnected = false;
          isLoggedIn = false;
          userRole = null;
          loginErrorMessage = 'Sunucu bağlantı hatası oluştu.';
          print(
            '☠️ WebSocketService (${hashCode}): Bağlantı hatası (onError): $error. URL: $currentFullWebSocketUrl',
          );
          notifyListeners();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print(
        '❌ WebSocketService (${hashCode}): Bağlantı KURULUM hatası: $e. URL: $currentFullWebSocketUrl',
      );
      _isConnected = false;
      loginErrorMessage = 'Sunucuya bağlanılamadı: $e';
      notifyListeners();
    }
  }

  void disconnect({bool isReconnecting = false}) {
    if (_channel != null) {
      print(
        'ℹ️ WebSocketService (${hashCode}): Bağlantı sonlandırılıyor. Mevcut URL: $currentFullWebSocketUrl',
      );
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    if (!isReconnecting) {
      isLoggedIn = false;
      userRole = null;
      loginErrorMessage = 'Bağlantı kesildi.';
      // Gerekirse burada diğer listeleri de temizle (logout'taki gibi)
      // tables.clear(); // vb.
    }
    print(
      'ℹ️ WebSocketService (${hashCode}): Bağlantı durumu: $_isConnected. isReconnecting: $isReconnecting',
    );
    if (!isReconnecting) {
      notifyListeners();
    }
  }

  void _handleIncomingMessage(String message) {
    print('Merkezi Dinleyici Mesaj Aldı: $message');
    // Önceki aksiyon/hata mesajlarını temizle
    staffManagementMessage = null;
    menuManagementMessage = null;
    tableManagementMessage = null;
    salesReportMessage = null;
    loginErrorMessage = null;
    customerLoginError = null;

    final response = jsonDecode(message);
    final type = response['type'] as String?;
    final payload =
        response.containsKey('payload') ? response['payload'] : null;

    print('--- WebSocketService: Mesaj tipi ayrıştırıldı: $type ---');

    switch (type) {
      case 'login_success':
        isLoggedIn = true;
        userRole = payload?['role'];
        loginErrorMessage = null;
        loginEventHandled = false;
        print('ℹ️ Servis: Giriş başarılı. Rol: $userRole');
        break;
      case 'login_failure':
        isLoggedIn = false;
        userRole = null;
        loginEventHandled = false;
        loginErrorMessage = payload?['message'] ?? 'Bilinmeyen giriş hatası.';
        print('⚠️ Servis: Giriş başarısız: $loginErrorMessage');
        break;
      case 'table_list':
        if (payload != null) {
          tables =
              (payload as List)
                  .map((data) => TableModel.fromJson(data))
                  .toList();
          print('ℹ️ Servis: Masa listesi güncelledi (${tables.length} masa).');
        }
        break;
      case 'table_status_update':
        if (payload != null) {
          final tableId = payload['id'];
          final newStatus = payload['status'];
          final index = tables.indexWhere((table) => table.id == tableId);
          if (index != -1) {
            tables[index] = TableModel(
              id: tables[index].id,
              tableNumber: tables[index].tableNumber,
              status: newStatus,
            );
            print('ℹ️ Servis: Masa $tableId durumu güncellendi: $newStatus');
          }
        }
        break;
      case 'menu_list':
        if (payload != null) {
          menuItems =
              (payload as List)
                  .map((data) => MenuItemModel.fromJson(data))
                  .toList();
          print(
            'ℹ️ Servis: Menü listesi güncellendi (${menuItems.length} ürün).',
          );
        }
        break;
      case 'new_order_for_kitchen':
        if (payload != null) {
          final newOrder = KitchenOrderModel.fromJson(payload);
          kitchenOrders.insert(0, newOrder);
          print('ℹ️ Servis: Yeni mutfak siparişi aldı: ID ${newOrder.orderId}');
        }
        break;
      case 'order_pickup_notification':
        if (payload != null) {
          final notification = OrderPickupNotificationModel.fromJson(payload);
          print(
            'ℹ️ Servis: Teslim alma bildirimi alındı (Stream için): ${notification.message}',
          );
          _pickupNotificationController.add(notification);
        }
        break;
      case 'orders_for_table_data':
        if (payload != null) {
          currentTableOrders =
              (payload as List)
                  .map((data) => KitchenOrderModel.fromJson(data))
                  .toList();
          print(
            'ℹ️ Servis, masa için sipariş listesini güncelledi (Detay: ${currentTableOrders.length} sipariş).',
          );
        }
        break;
      case 'customer_table_data':
        customerLoginError = null;
        if (payload != null) {
          currentCustomerTable = TableModel(
            id: payload['table_id'],
            tableNumber: payload['table_number'],
            status: payload['table_status'],
          );
          currentCustomerOrders =
              (payload['orders'] as List)
                  .map((data) => CustomerOrderModel.fromJson(data))
                  .toList();
          print(
            'ℹ️ Servis: Müşteri masa verisini aldı: Masa ${currentCustomerTable?.tableNumber}',
          );
        }
        break;
      case 'customer_table_login_error':
        customerLoginError = payload?['message'];
        currentCustomerTable = null;
        currentCustomerOrders = [];
        print('⚠️ Servis: Müşteri masa girişi hatası: $customerLoginError');
        break;
      case 'staff_list_data':
        if (payload != null) {
          try {
            staffList =
                (payload as List)
                    .map((data) => UserModel.fromJson(data))
                    .toList();
            print(
              'ℹ️ Servis: Personel listesi güncellendi (${staffList.length} personel).',
            );
          } catch (e) {
            print('❌ Servis: staff_list_data parse edilirken HATA: $e');
            staffList = [];
          }
        }
        break;
      case 'add_staff_success':
        staffActionSuccess = true;
        staffManagementMessage = payload?['message'];
        print('ℹ️ Servis: Personel ekleme başarılı: $staffManagementMessage');
        break;
      case 'add_staff_failure':
        staffActionSuccess = false;
        staffManagementMessage = payload?['message'];
        print('⚠️ Servis: Personel ekleme başarısız: $staffManagementMessage');
        break;
      case 'delete_staff_success':
        staffActionSuccess = true;
        staffManagementMessage = payload?['message'];
        print('ℹ️ Servis: Personel silme başarılı: $staffManagementMessage');
        break;
      case 'delete_staff_failure':
        staffActionSuccess = false;
        staffManagementMessage = payload?['message'];
        print('⚠️ Servis: Personel silme başarısız: $staffManagementMessage');
        break;
      case 'add_menu_item_success':
        menuActionSuccess = true;
        menuManagementMessage = payload?['message'];
        print('ℹ️ Servis: Menü ürünü ekleme başarılı: $menuManagementMessage');
        break;
      case 'add_menu_item_failure':
        menuActionSuccess = false;
        menuManagementMessage = payload?['message'];
        print('⚠️ Servis: Menü ürünü ekleme başarısız: $menuManagementMessage');
        break;
      case 'edit_menu_item_success':
        menuActionSuccess = true;
        menuManagementMessage = payload?['message'];
        print(
          'ℹ️ Servis: Menü ürünü düzenleme başarılı: $menuManagementMessage',
        );
        break;
      case 'edit_menu_item_failure':
        menuActionSuccess = false;
        menuManagementMessage = payload?['message'];
        print(
          '⚠️ Servis: Menü ürünü düzenleme başarısız: $menuManagementMessage',
        );
        break;
      case 'delete_menu_item_success':
        menuActionSuccess = true;
        menuManagementMessage = payload?['message'];
        print('ℹ️ Servis: Menü ürünü silme başarılı: $menuManagementMessage');
        break;
      case 'delete_menu_item_failure':
        menuActionSuccess = false;
        menuManagementMessage = payload?['message'];
        print('⚠️ Servis: Menü ürünü silme başarısız: $menuManagementMessage');
        break;
      case 'update_table_count_success':
        tableActionSuccess = true;
        tableManagementMessage = payload?['message'];
        // currentTableCountFromService değişkenine artık gerek yok, tables.length kullanılacak.
        // Ancak, sunucu yeni sayıyı gönderiyorsa ve bu sayı hemen tables.length'e yansımıyorsa
        // (çünkü get_tables ayrı bir istekle gelecek), bu bilgi UI için geçici olarak tutulabilir.
        // Biz 'table_list_refresh_required' gönderip client'ın get_tables yapmasını sağlıyoruz.
        print(
          'ℹ️ Servis: Masa sayısı güncelleme başarılı: $tableManagementMessage',
        );
        break;
      case 'update_table_count_failure':
        tableActionSuccess = false;
        tableManagementMessage = payload?['message'];
        print(
          '⚠️ Servis: Masa sayısı güncelleme başarısız: $tableManagementMessage',
        );
        break;
      /*
      case 'table_list_refresh_required':
        print(
          'ℹ️ Servis: Masa listesi yenileme isteği alındı. `get_tables` gönderiliyor...',
        );
        sendMessage(jsonEncode({'type': 'get_tables'}));
        break;
        */
      case 'sales_report_data':
        if (payload != null) {
          salesReportData = SalesReportDataModel.fromJson(payload);
          print(
            'ℹ️ Servis: Satış raporu verisi alındı. Toplam Gelir: ${salesReportData?.overallTotalRevenue}',
          );
        }
        break;
      case 'sales_report_failure':
        salesReportMessage = payload?['message'];
        salesReportData = null;
        print('⚠️ Servis: Satış raporu alınamadı: $salesReportMessage');
        break;
      default:
        print('⚠️ Servis: Bilinmeyen mesaj tipi alındı: $type');
    }
    notifyListeners();
  }

  void consumeLoginEvent() {
    loginEventHandled = true;
    // Bu fonksiyon UI'ı tekrar çizmemeli, sadece bayrağı değiştirmeli.
    // Bu yüzden burada notifyListeners() ÇAĞIRMIYORUZ.
  }

  void sendMessage(String message) {
    if (_isConnected && _channel != null) {
      print('🚀 WebSocketService (${hashCode}): Mesaj gönderiliyor: $message');
      _channel!.sink.add(message);
    } else {
      print(
        '❌ WebSocketService (${hashCode}): Mesaj GÖNDERİLEMEDİ - Bağlantı yok veya kanal null.',
      );
      // Otomatik bağlanmayı dene?
      // connect(); // Bu sonsuz döngüye sokabilir, dikkatli kullanılmalı.
    }
  }

  void markKitchenOrderAsReady(int orderId) {
    final index = kitchenOrders.indexWhere((order) => order.orderId == orderId);
    if (index != -1) {
      kitchenOrders[index].status = 'ready';
      print(
        'ℹ️ Servis (Yerel): Mutfak Sipariş ID $orderId durumu "ready" olarak güncellendi.',
      );
      notifyListeners();
      sendMessage(
        jsonEncode({
          'type': 'order_ready_for_pickup',
          'payload': {'order_id': orderId},
        }),
      );
    } else {
      print(
        '⚠️ Servis: Hazır olarak işaretlenecek sipariş bulunamadı: ID $orderId',
      );
    }
  }

  void clearStaffManagementMessage() {
    staffManagementMessage = null;
    notifyListeners();
  }

  void clearMenuManagementMessage() {
    menuManagementMessage = null;
    notifyListeners();
  }

  void clearTableManagementMessage() {
    tableManagementMessage = null;
    notifyListeners();
  }

  void clearSalesReportMessage() {
    salesReportMessage = null;
    notifyListeners();
  }

  void clearLoginErrorMessage() {
    loginErrorMessage = null;
    notifyListeners();
  }

  void clearCustomerLoginError() {
    customerLoginError = null;
    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    userRole = null;
    loginErrorMessage = null;
    customerLoginError = null;
    loginEventHandled = true;

    tables.clear();
    menuItems.clear();
    kitchenOrders.clear();
    staffList.clear();
    currentTableOrders.clear();
    currentCustomerTable = null;
    currentCustomerOrders.clear();

    salesReportData = null;
    salesReportMessage = null;

    staffManagementMessage = null;
    menuManagementMessage = null;
    tableManagementMessage = null;

    print(
      'ℹ️ WebSocketService (${hashCode}): Kullanıcı çıkış yaptı. Tüm state\'ler temizlendi.',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    print('ℹ️ WebSocketService (${hashCode}): dispose çağrıldı.');
    _channel?.sink.close();
    _pickupNotificationController.close();
    super.dispose();
  }
}
