// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // Google Fonts için
// import 'package:provider/provider.dart';
// import '../../api/websocket_service.dart';
// import '../../models/menu_item_model.dart';

// // OrderItem yardımcı sınıfı aynı kalıyor
// class OrderItem {
//   final MenuItemModel menuItem;
//   int quantity;
//   String notes;
//   OrderItem({required this.menuItem, this.quantity = 1, this.notes = ''});
// }

// class MenuScreen extends StatefulWidget {
//   final int tableId;
//   final int tableNumber;

//   const MenuScreen({
//     super.key,
//     required this.tableId,
//     required this.tableNumber,
//   });

//   @override
//   State<MenuScreen> createState() => _MenuScreenState();
// }

// class _MenuScreenState extends State<MenuScreen> {
//   final List<OrderItem> _currentOrder = [];
//   double _totalPrice = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<WebSocketService>(
//         context,
//         listen: false,
//       ).sendMessage(jsonEncode({'type': 'get_menu'}));
//     });
//   }

//   void _addItemToOrder(MenuItemModel item) {
//     setState(() {
//       final index = _currentOrder.indexWhere(
//         (orderItem) => orderItem.menuItem.id == item.id,
//       );
//       if (index != -1) {
//         _currentOrder[index].quantity++;
//       } else {
//         _currentOrder.add(OrderItem(menuItem: item));
//       }
//       _calculateTotalPrice();
//     });
//   }

//   void _removeItemFromOrder(OrderItem orderItem) {
//     setState(() {
//       if (orderItem.quantity > 1) {
//         orderItem.quantity--;
//       } else {
//         _currentOrder.remove(orderItem);
//       }
//       _calculateTotalPrice();
//     });
//   }

//   void _calculateTotalPrice() {
//     _totalPrice = 0.0;
//     for (var orderItem in _currentOrder) {
//       _totalPrice += orderItem.menuItem.price * orderItem.quantity;
//     }
//   }

//   void _submitOrder() {
//     if (_currentOrder.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Lütfen siparişe ürün ekleyin.'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }
//     final webSocketService = Provider.of<WebSocketService>(
//       context,
//       listen: false,
//     );
//     final payloadItems =
//         _currentOrder
//             .map(
//               (orderItem) => {
//                 'id': orderItem.menuItem.id,
//                 'quantity': orderItem.quantity,
//                 'notes': orderItem.notes,
//               },
//             )
//             .toList();
//     final newOrderMessage = {
//       'type': 'new_order',
//       'payload': {'table_id': widget.tableId, 'items': payloadItems},
//     };
//     webSocketService.sendMessage(jsonEncode(newOrderMessage));
//     Navigator.pop(context);
//   }

//   void _showAddNoteDialog(OrderItem orderItem) {
//     final noteController = TextEditingController(text: orderItem.notes);
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: Text('${orderItem.menuItem.name} için Not Ekle'),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(15.0),
//             ),
//             content: TextField(
//               controller: noteController,
//               decoration: const InputDecoration(
//                 hintText: 'Örn: Az pişmiş, bol soslu...',
//               ),
//               autofocus: true,
//               maxLines: 3,
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('İptal'),
//               ),
//               ElevatedButton(
//                 // Ana aksiyon butonu için ElevatedButton
//                 onPressed: () {
//                   setState(() => orderItem.notes = noteController.text);
//                   Navigator.pop(context);
//                 },
//                 child: const Text('Kaydet'),
//               ),
//             ],
//           ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Temadan renkleri alalım (main.dart'ta tanımladığımız)
//     // final Color primaryColor = Theme.of(context).colorScheme.primary;
//     final Color accentColor = Theme.of(context).colorScheme.secondary;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Masa ${widget.tableNumber} Siparişi'),
//         // backgroundColor ve foregroundColor temadan gelecek
//       ),
//       body: Consumer<WebSocketService>(
//         builder: (context, service, child) {
//           if (service.menuItems.isEmpty && service.isConnected) {
//             // Bağlı ama menü boşsa yükleniyor
//             return const Center(child: CircularProgressIndicator());
//           } else if (!service.isConnected && service.menuItems.isEmpty) {
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.signal_wifi_off_outlined,
//                       size: 60,
//                       color: Colors.grey.shade400,
//                     ),
//                     const SizedBox(height: 16),
//                     const Text(
//                       "Sunucuya bağlanılamadı veya menü bilgisi yok.",
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontSize: 16, color: Colors.grey),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }

//           // Menü ürünlerini kategorilere göre grupla
//           Map<String, List<MenuItemModel>> groupedMenu = {};
//           for (var item in service.menuItems) {
//             groupedMenu.putIfAbsent(item.category, () => []).add(item);
//           }
//           // Kategorileri sırala (isteğe bağlı)
//           var sortedCategories = groupedMenu.keys.toList()..sort();

//           return Column(
//             children: [
//               Expanded(
//                 // Kategorili Menü Listesi
//                 child: ListView.builder(
//                   padding: const EdgeInsets.all(8.0),
//                   itemCount: sortedCategories.length,
//                   itemBuilder: (context, categoryIndex) {
//                     String category = sortedCategories[categoryIndex];
//                     List<MenuItemModel> itemsInCategory =
//                         groupedMenu[category]!;

//                     return Card(
//                       // Her kategori için bir Card
//                       margin: const EdgeInsets.symmetric(
//                         vertical: 8.0,
//                         horizontal: 4.0,
//                       ),
//                       elevation: 2.0,
//                       child: ExpansionTile(
//                         key: PageStorageKey<String>(
//                           category,
//                         ), // Scroll pozisyonunu korumak için
//                         title: Text(
//                           category,
//                           style: GoogleFonts.montserrat(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w600,
//                             color: Theme.of(context).colorScheme.primary,
//                           ),
//                         ),
//                         initiallyExpanded: true, // Başlangıçta açık olsun
//                         childrenPadding: const EdgeInsets.symmetric(
//                           horizontal: 8.0,
//                           vertical: 4.0,
//                         ),
//                         children:
//                             itemsInCategory.map((item) {
//                               return Card(
//                                 // Her ürün için bir alt Card
//                                 elevation: 1.0,
//                                 margin: const EdgeInsets.symmetric(
//                                   vertical: 4.0,
//                                 ),
//                                 child: ListTile(
//                                   // leading: Icon(Icons.fastfood_outlined, color: accentColor), // Örnek ikon
//                                   title: Text(
//                                     item.name,
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                   subtitle: Text(
//                                     '${item.price.toStringAsFixed(2)} TL',
//                                     style: TextStyle(
//                                       color: Colors.grey.shade700,
//                                     ),
//                                   ),
//                                   trailing: IconButton(
//                                     icon: Icon(
//                                       Icons.add_circle_outline,
//                                       color: accentColor,
//                                       size: 28,
//                                     ),
//                                     tooltip: 'Siparişe Ekle',
//                                     onPressed: () => _addItemToOrder(item),
//                                   ),
//                                   onTap:
//                                       () => _addItemToOrder(
//                                         item,
//                                       ), // ListTile'a da tıklama özelliği
//                                 ),
//                               );
//                             }).toList(),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               if (_currentOrder.isNotEmpty) ...[
//                 // Sadece siparişte ürün varsa göster
//                 const Divider(thickness: 2, height: 2),
//                 _buildOrderSummary(),
//               ],
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildOrderSummary() {
//     // Bu fonksiyonun içeriği büyük ölçüde aynı, sadece stil güncellemeleri yapılabilir.
//     // Tema renklerini ve fontlarını kullanmaya özen gösterelim.
//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color:
//             Theme.of(
//               context,
//             ).scaffoldBackgroundColor, // Arka plan rengiyle uyumlu
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             spreadRadius: 0,
//             blurRadius: 8,
//             offset: const Offset(0, -4), // Üste gölge
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             'Güncel Sipariş',
//             style: GoogleFonts.montserrat(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Theme.of(context).colorScheme.primary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           if (_currentOrder.isEmpty)
//             const Padding(
//               padding: EdgeInsets.symmetric(vertical: 16.0),
//               child: Text(
//                 'Siparişiniz boş.',
//                 style: TextStyle(fontSize: 16, color: Colors.grey),
//               ),
//             )
//           else
//             ConstrainedBox(
//               constraints: const BoxConstraints(
//                 maxHeight: 180,
//               ), // Sipariş listesi için max yükseklik
//               child: ListView.separated(
//                 shrinkWrap: true,
//                 itemCount: _currentOrder.length,
//                 separatorBuilder: (context, index) => const Divider(height: 1),
//                 itemBuilder: (context, index) {
//                   final orderItem = _currentOrder[index];
//                   return ListTile(
//                     contentPadding: const EdgeInsets.symmetric(horizontal: 0),
//                     leading: Text(
//                       '${orderItem.quantity} x',
//                       style: GoogleFonts.lato(fontWeight: FontWeight.bold),
//                     ),
//                     title: Text(orderItem.menuItem.name),
//                     subtitle:
//                         orderItem.notes.isNotEmpty
//                             ? Text(
//                               orderItem.notes,
//                               style: TextStyle(
//                                 fontStyle: FontStyle.italic,
//                                 color: Colors.blueGrey.shade700,
//                               ),
//                             )
//                             : TextButton(
//                               style: TextButton.styleFrom(
//                                 padding: EdgeInsets.zero,
//                                 alignment: Alignment.centerLeft,
//                               ),
//                               onPressed: () => _showAddNoteDialog(orderItem),
//                               child: const Text(
//                                 'Not Ekle...',
//                                 style: TextStyle(
//                                   color: Colors.blue,
//                                   fontStyle: FontStyle.italic,
//                                 ),
//                               ),
//                             ),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           '${(orderItem.menuItem.price * orderItem.quantity).toStringAsFixed(2)} TL',
//                           style: GoogleFonts.lato(),
//                         ),
//                         IconButton(
//                           icon: Icon(
//                             Icons.remove_circle_outline,
//                             color: Theme.of(context).colorScheme.error,
//                           ),
//                           onPressed: () => _removeItemFromOrder(orderItem),
//                         ),
//                         // Adet artırma butonu, ürüne tıklayarak yapılıyor.
//                         // İstenirse buraya da eklenebilir.
//                       ],
//                     ),
//                     onTap:
//                         () => _showAddNoteDialog(
//                           orderItem,
//                         ), // Satıra tıklayınca da not ekleme
//                   );
//                 },
//               ),
//             ),
//           const Divider(height: 16, thickness: 1),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Toplam: ${_totalPrice.toStringAsFixed(2)} TL',
//                 style: GoogleFonts.montserrat(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Theme.of(context).colorScheme.primary,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _submitOrder,
//                 icon: const Icon(Icons.check_circle_outline),
//                 label: const Text('Siparişi Onayla'),
//                 // Stil temadan gelecek
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
