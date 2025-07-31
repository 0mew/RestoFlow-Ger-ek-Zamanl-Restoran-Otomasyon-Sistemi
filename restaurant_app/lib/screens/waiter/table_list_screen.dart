import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_app/screens/waiter/table_action_screen.dart';
import '../../api/websocket_service.dart';
//import '../../models/table_model.dart';
//import '../../models/order_pickup_notification_model.dart';
import 'menu_screen.dart';
import 'table_order_details_screen.dart';
import '../role_selection_screen.dart';

class TableListScreen extends StatefulWidget {
  const TableListScreen({super.key});
  @override
  State<TableListScreen> createState() => _TableListScreenState();
}

class _TableListScreenState extends State<TableListScreen> {
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    // Bu fonksiyon, bu widget ağaca ilk eklendiğinde SADECE BİR KEZ çalışır.
    // Veri istemek ve dinleyicileri başlatmak için en doğru yer burasıdır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchTableList();
        _listenForNotifications();
      }
    });
  }

  void _fetchTableList() {
    if (!mounted) return;
    Provider.of<WebSocketService>(
      context,
      listen: false,
    ).sendMessage(jsonEncode({'type': 'get_tables'}));
  }

  void _listenForNotifications() {
    if (!mounted) return;
    final service = Provider.of<WebSocketService>(context, listen: false);
    // Dinleyiciyi yeniden oluştururken eskisini iptal et (güvenli yöntem)
    _notificationSubscription?.cancel();
    _notificationSubscription = service.pickupNotificationEvents.listen((
      notification,
    ) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              notification.message,
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
            action: SnackBarAction(
              label: 'TAMAM',
              textColor: Colors.white,
              onPressed:
                  () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription
        ?.cancel(); // Sayfa kapandığında dinleyiciyi kesinlikle iptal et!
    super.dispose();
  }

  Color _getTableColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green.shade500;
      case 'ordered':
        return Colors.orange.shade500;
      case 'delivered':
        return Colors.red.shade500;
      default:
        return Colors.grey.shade500;
    }
  }

  IconData _getTableStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.event_available_rounded;
      case 'ordered':
        return Icons.hourglass_bottom_rounded;
      case 'delivered':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.table_restaurant_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Masalar', style: GoogleFonts.montserrat()),
        automaticallyImplyLeading: false, // Geri butonunu kaldır
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _fetchTableList,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () {
              Provider.of<WebSocketService>(context, listen: false).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          // **DÖNGÜYÜ ENGELLEYEN ANA KURAL:**
          // Bu `builder` fonksiyonu içinde ASLA `_fetchTableList()` veya
          // `get_tables` isteği gönderen bir kod OLMAMALIDIR.
          // Burası sadece `service.tables` listesindeki mevcut veriyi ekrana çizmelidir.

          if (service.tables.isEmpty && service.isConnected) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!service.isConnected && service.tables.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.signal_wifi_off_outlined,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Sunucuya bağlanılamadı veya masa bilgisi yok.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _fetchTableList();
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 1.0,
              ),
              itemCount: service.tables.length,
              itemBuilder: (context, index) {
                final table = service.tables[index];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: _getTableColor(table.status),
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (table.status == 'available') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => TableActionScreen(
                                    tableId: table.id,
                                    tableNumber: table.tableNumber,
                                  ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => TableActionScreen(
                                    tableId: table.id,
                                    tableNumber: table.tableNumber,
                                  ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16.0),
                      splashColor: Colors.white.withOpacity(0.3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getTableStatusIcon(table.status),
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Masa',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            '${table.tableNumber}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
