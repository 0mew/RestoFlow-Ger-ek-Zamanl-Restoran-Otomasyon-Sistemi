// lib/models/kitchen_order_model.dart
// lib/models/kitchen_order_model.dart dosyasında

class KitchenOrderItem {
  final int orderItemId;
  final String name;
  final int quantity;
  final String notes;
  final double price;
  final String paymentStatus;

  KitchenOrderItem({
    required this.orderItemId,
    required this.name,
    required this.quantity,
    required this.notes,
    required this.price,
    required this.paymentStatus,
  });

  factory KitchenOrderItem.fromJson(Map<String, dynamic> json) {
    // Sunucudan gelen alan adlarını doğrudan kullanıyoruz.
    return KitchenOrderItem(
      orderItemId: json['order_item_id'] ?? 0,
      name: json['menu_item_name'] ?? 'Bilinmeyen Ürün',
      quantity: json['quantity'] ?? 0,
      notes: json['notes'] ?? '',
      price: (json['menu_item_price'] as num? ?? 0.0).toDouble(),
      paymentStatus: json['payment_status'] ?? 'unpaid',
    );
  }
}

// KitchenOrderModel sınıfının geri kalanı aynı kalabilir.

// class KitchenOrderItem {
//   final int
//   orderItemId; // VERİTABANINDAKİ OrderItems.id (benzersiz kalem ID'si)
//   final String name;
//   final int quantity;
//   final String notes;
//   final double price; // Ürünün MenuItems tablosundan gelen birim fiyatı
//   final String paymentStatus; // 'unpaid', 'paid' (OrderItems tablosundan)

//   KitchenOrderItem({
//     required this.orderItemId,
//     required this.name,
//     required this.quantity,
//     required this.notes,
//     required this.price,
//     required this.paymentStatus,
//   });

//   factory KitchenOrderItem.fromJson(Map<String, dynamic> json) {
//     // Sunucudan gelen payload'daki alan adlarıyla eşleştiğinden emin olalım.
//     // _handleGetOrdersForTable fonksiyonunda bu alanları şu şekilde gönderiyoruz:
//     // 'order_item_id': row['order_item_id'],
//     // 'name': row['menu_item_name'], (modelde 'name' olarak mapleniyor)
//     // 'quantity': row['quantity'],
//     // 'notes': row['notes'] ?? '',
//     // 'menu_item_price': row['menu_item_price'], (modelde 'price' olarak mapleniyor)
//     // 'payment_status': row['payment_status']

//     return KitchenOrderItem(
//       orderItemId:
//           json['order_item_id'] as int? ??
//           0, // Eğer null gelirse 0 ata (idealde hep gelmeli)
//       name:
//           json['menu_item_name'] as String? ??
//           json['name'] as String? ??
//           'Bilinmeyen Ürün',
//       quantity: json['quantity'] as int? ?? 0,
//       notes: json['notes'] as String? ?? '',
//       price: (json['menu_item_price'] as num? ?? 0.0).toDouble(),
//       paymentStatus: json['payment_status'] as String? ?? 'unpaid',
//     );
//   }
// }

class KitchenOrderModel {
  final int orderId;
  final int tableNumber;
  final List<KitchenOrderItem> items;
  String status; // Siparişin genel durumu: 'pending', 'ready', 'completed'

  KitchenOrderModel({
    required this.orderId,
    required this.tableNumber,
    required this.items,
    this.status = 'pending',
  });

  factory KitchenOrderModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<KitchenOrderItem> parsedItems =
        itemsList
            .map((i) => KitchenOrderItem.fromJson(i as Map<String, dynamic>))
            .toList();

    return KitchenOrderModel(
      orderId: json['order_id'],
      tableNumber: json['table_number'],
      items: parsedItems,
      status:
          json['order_status'] as String? ??
          json['status'] as String? ??
          'pending',
    );
  }
}
