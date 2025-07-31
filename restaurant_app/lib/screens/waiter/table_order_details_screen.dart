// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // Fontlar için
// import 'package:provider/provider.dart';
// import '../../api/websocket_service.dart';
// // AKTİF HALE GETİRİLDİ VE KULLANILACAK!
// // Eğer RoleSelectionScreen farklı bir klasördeyse yolu güncelle
// // import '../role_selection_screen.dart'; // Bu ekranda logout için gerekirse

// class TableOrderDetailsScreen extends StatefulWidget {
//   final int tableId;
//   final int tableNumber;

//   const TableOrderDetailsScreen({
//     super.key,
//     required this.tableId,
//     required this.tableNumber,
//   });

//   @override
//   State<TableOrderDetailsScreen> createState() =>
//       _TableOrderDetailsScreenState();
// }

// class _TableOrderDetailsScreenState extends State<TableOrderDetailsScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Ekran açıldığında masanın güncel siparişlerini sunucudan iste
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchTableOrders();
//     });
//   }

//   void _fetchTableOrders() {
//     if (!mounted) return;
//     final service = Provider.of<WebSocketService>(context, listen: false);
//     // Yenileme sırasında veya ilk yüklemede eski siparişleri temizleyebiliriz
//     // Ancak servisteki currentTableOrders zaten get_orders_for_table ile güncelleniyor.
//     // service.currentTableOrders = []; // Bu satıra gerek yok, servis hallediyor
//     // service.notifyListeners();

//     service.sendMessage(
//       jsonEncode({
//         'type': 'get_orders_for_table',
//         'payload': {'table_id': widget.tableId},
//       }),
//     );
//   }

//   void _markOrderAsDelivered(int orderId) {
//     final service = Provider.of<WebSocketService>(context, listen: false);
//     service.sendMessage(
//       jsonEncode({
//         'type': 'order_delivered',
//         'payload': {'order_id': orderId},
//       }),
//     );
//     // Masa listesine geri dön, TableListScreen güncel durumu gösterecek
//     Navigator.pop(context);
//   }

//   // Sipariş durumuna göre renk döndüren yardımcı fonksiyon
//   Color _getOrderStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'pending':
//         return Colors.orange.shade600; // Biraz daha koyu turuncu
//       case 'ready':
//         return Colors.blue.shade600; // Biraz daha koyu mavi
//       case 'completed':
//         return Colors.green.shade600; // Biraz daha koyu yeşil
//       default:
//         return Colors.grey.shade700;
//     }
//   }

//   // Ürün ödeme durumuna göre ikon döndüren yardımcı fonksiyon
//   Widget _getPaymentStatusIcon(String paymentStatus, {double size = 20.0}) {
//     switch (paymentStatus.toLowerCase()) {
//       case 'paid':
//         return Icon(Icons.check_circle, color: Colors.green, size: size);
//       case 'unpaid':
//         return Icon(
//           Icons.radio_button_unchecked_outlined,
//           color: Colors.red.shade600,
//           size: size,
//         );
//       default:
//         return Icon(
//           Icons.help_outline,
//           color: Colors.grey.shade500,
//           size: size,
//         );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Color primaryColor = Theme.of(context).colorScheme.primary;
//     // final Color accentColor = Theme.of(context).colorScheme.secondary;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Masa ${widget.tableNumber} Detayları',
//           style: GoogleFonts.montserrat(),
//         ),
//         // backgroundColor ve foregroundColor temadan gelecek
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             tooltip: 'Yenile',
//             onPressed: _fetchTableOrders,
//           ),
//         ],
//       ),
//       body: Consumer<WebSocketService>(
//         builder: (context, service, child) {
//           // Yüklenme durumu veya veri yoksa
//           if (service.currentTableOrders.isEmpty && service.isConnected) {
//             // Eğer ilk açılışta veya yenileme sonrası liste henüz dolmadıysa.
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (service.currentTableOrders.isEmpty) {
//             // Veri geldi ama hala boşsa (veya bağlantı yoksa)
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.info_outline,
//                       size: 60,
//                       color: Colors.grey.shade400,
//                     ),
//                     const SizedBox(height: 16),
//                     const Text(
//                       "Bu masa için aktif sipariş yok veya sunucuya bağlanılamadı.",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontSize: 16, color: Colors.grey),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }

//           return RefreshIndicator(
//             onRefresh: () async {
//               _fetchTableOrders();
//             },
//             child: ListView.separated(
//               padding: const EdgeInsets.all(12.0),
//               itemCount: service.currentTableOrders.length,
//               separatorBuilder:
//                   (context, index) =>
//                       const SizedBox(height: 12), // Kartlar arası boşluk
//               itemBuilder: (context, index) {
//                 final order =
//                     service.currentTableOrders[index]; // KitchenOrderModel
//                 bool isReadyForDelivery = order.status == 'ready';
//                 bool isOrderCompleted = order.status == 'completed';
//                 bool allItemsInThisOrderPaid = order.items.every(
//                   (item) => item.paymentStatus == 'paid',
//                 );

//                 return Card(
//                   elevation: 3,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12.0),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               'Sipariş ID: ${order.orderId}',
//                               style: GoogleFonts.montserrat(
//                                 fontSize: 17,
//                                 fontWeight: FontWeight.w600,
//                                 color: primaryColor,
//                               ),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 5,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: _getOrderStatusColor(order.status),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Text(
//                                 order.status.toUpperCase(),
//                                 style: GoogleFonts.lato(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const Divider(height: 24, thickness: 1),
//                         if (order.items.isEmpty)
//                           const Text(
//                             'Bu siparişte ürün bulunmuyor.',
//                             style: TextStyle(
//                               fontStyle: FontStyle.italic,
//                               color: Colors.grey,
//                             ),
//                           )
//                         else
//                           // Ürünleri daha okunaklı listelemek için Column kullanıyoruz
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children:
//                                 order.items.map((item) {
//                                   // item burada KitchenOrderItem
//                                   return Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       vertical: 6.0,
//                                     ),
//                                     child: Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.center,
//                                       children: [
//                                         _getPaymentStatusIcon(
//                                           item.paymentStatus,
//                                           size: 22,
//                                         ),
//                                         const SizedBox(width: 10),
//                                         Text(
//                                           '${item.quantity}x',
//                                           style: GoogleFonts.lato(
//                                             fontWeight: FontWeight.bold,
//                                             fontSize: 16,
//                                           ),
//                                         ),
//                                         const SizedBox(width: 8),
//                                         Expanded(
//                                           child: Column(
//                                             crossAxisAlignment:
//                                                 CrossAxisAlignment.start,
//                                             children: [
//                                               Text(
//                                                 item.name,
//                                                 style: GoogleFonts.lato(
//                                                   fontSize: 16,
//                                                 ),
//                                               ),
//                                               if (item.notes.isNotEmpty)
//                                                 Padding(
//                                                   padding:
//                                                       const EdgeInsets.only(
//                                                         top: 2.0,
//                                                       ),
//                                                   child: Text(
//                                                     '(${item.notes})',
//                                                     style: GoogleFonts.lato(
//                                                       fontSize: 13,
//                                                       fontStyle:
//                                                           FontStyle.italic,
//                                                       color: Colors.blueGrey,
//                                                     ),
//                                                   ),
//                                                 ),
//                                             ],
//                                           ),
//                                         ),
//                                         Text(
//                                           '${(item.price * item.quantity).toStringAsFixed(2)} TL',
//                                           style: GoogleFonts.lato(
//                                             fontSize: 15,
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 }).toList(),
//                           ),

//                         if (isReadyForDelivery) ...[
//                           const SizedBox(height: 16),
//                           Align(
//                             alignment: Alignment.centerRight,
//                             child: ElevatedButton.icon(
//                               onPressed:
//                                   () => _markOrderAsDelivered(order.orderId),
//                               icon: const Icon(
//                                 Icons.delivery_dining_outlined,
//                               ), // Daha stilize bir ikon
//                               label: const Text('Teslim Edildi'),
//                               // style ElevatedButtonTheme'den gelecek ama istersek override edebiliriz
//                               // style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
//                             ),
//                           ),
//                         ] else if (isOrderCompleted) ...[
//                           const SizedBox(height: 16),
//                           Align(
//                             alignment: Alignment.centerRight,
//                             child: Row(
//                               // İkon ve metin bir arada
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(
//                                   allItemsInThisOrderPaid
//                                       ? Icons.check_circle
//                                       : Icons.payment_outlined,
//                                   color:
//                                       allItemsInThisOrderPaid
//                                           ? Colors.green
//                                           : Colors.orangeAccent,
//                                   size: 18,
//                                 ),
//                                 const SizedBox(width: 4),
//                                 Text(
//                                   allItemsInThisOrderPaid
//                                       ? "Tamamlandı ve Ödendi"
//                                       : "Teslim Edildi, Ödeme Bekliyor",
//                                   style: TextStyle(
//                                     color:
//                                         allItemsInThisOrderPaid
//                                             ? Colors.green
//                                             : Colors.orangeAccent,
//                                     fontStyle: FontStyle.italic,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//       // "POS ile Ödeme Al" butonu buraya eklenebilir (bir sonraki adımda).
//     );
//   }
// }
