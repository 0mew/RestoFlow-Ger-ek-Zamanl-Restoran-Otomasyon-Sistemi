class CustomerOrderItemModel {
  final int orderItemId;
  final String name;
  final int quantity;
  final String notes;
  final double price;
  final String paymentStatus; // 'unpaid', 'paid'

  CustomerOrderItemModel({
    required this.orderItemId,
    required this.name,
    required this.quantity,
    required this.notes,
    required this.price,
    required this.paymentStatus,
  });

  factory CustomerOrderItemModel.fromJson(Map<String, dynamic> json) {
    return CustomerOrderItemModel(
      orderItemId: json['order_item_id'],
      name: json['name'],
      quantity: json['quantity'],
      notes: json['notes'] ?? '',
      price: (json['price'] as num).toDouble(),
      paymentStatus: json['payment_status'],
    );
  }
}

class CustomerOrderModel {
  final int orderId;
  final String orderStatus; // 'pending', 'ready', 'completed'
  final List<CustomerOrderItemModel> items;

  CustomerOrderModel({
    required this.orderId,
    required this.orderStatus,
    required this.items,
  });

  factory CustomerOrderModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<CustomerOrderItemModel> parsedItems =
        itemsList.map((i) => CustomerOrderItemModel.fromJson(i)).toList();
    return CustomerOrderModel(
      orderId: json['order_id'],
      orderStatus: json['order_status'],
      items: parsedItems,
    );
  }
}
