// Sipariş gönderme için gerekebilir
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Fontlar için
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import '../../models/kitchen_order_model.dart'; // Modelimizi import ediyoruz
import '../role_selection_screen.dart'; // Logout için

class KitchenOrdersScreen extends StatelessWidget {
  const KitchenOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final webSocketService = Provider.of<WebSocketService>(
      context,
      listen: false,
    );
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mutfak - Gelen Siparişler',
          style: GoogleFonts.montserrat(),
        ),
        // backgroundColor ve foregroundColor temadan gelecek
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () {
              webSocketService.logout();
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
          if (service.kitchenOrders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.no_food_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz aktif sipariş yok.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Siparişleri "pending" olanlar üste, "ready" olanlar alta gelecek şekilde sıralayabiliriz
          List<KitchenOrderModel> sortedOrders = List.from(
            service.kitchenOrders,
          );
          sortedOrders.sort((a, b) {
            if (a.status == 'pending' && b.status != 'pending') return -1;
            if (a.status != 'pending' && b.status == 'pending') return 1;
            return a.orderId.compareTo(
              b.orderId,
            ); // Aynı durumdakileri ID'ye göre sırala
          });

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: sortedOrders.length,
            itemBuilder: (context, index) {
              final order = sortedOrders[index];
              bool isReady = order.status == 'ready';

              return Card(
                elevation: isReady ? 2.0 : 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                color: isReady ? Colors.grey.shade200 : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Masa ${order.tableNumber} - Sipariş ID: ${order.orderId}',
                            style: GoogleFonts.montserrat(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color:
                                  isReady ? Colors.grey.shade700 : primaryColor,
                            ),
                          ),
                          if (isReady)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                ),
                              ),
                              child: Text(
                                'GARSONA BİLDİRİLDİ',
                                style: GoogleFonts.lato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 20, thickness: 1),
                      // Sipariş kalemlerini listele
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.quantity}x ',
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color:
                                      isReady
                                          ? Colors.grey.shade700
                                          : Colors.black87,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.lato(
                                    fontSize: 16,
                                    color:
                                        isReady
                                            ? Colors.grey.shade700
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                              if (item.notes.isNotEmpty)
                                Expanded(
                                  // Notlar uzunsa alta kayması için
                                  flex: 2, // Not alanına daha fazla yer ver
                                  child: Text(
                                    "(${item.notes})",
                                    style: GoogleFonts.lato(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14,
                                      color:
                                          isReady
                                              ? Colors.grey.shade600
                                              : Colors.blueGrey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!isReady)
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              webSocketService.markKitchenOrderAsReady(
                                order.orderId,
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Sipariş Hazır'),
                            // style: ElevatedButton.styleFrom(backgroundColor: accentColor) // Temadan gelecek
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
