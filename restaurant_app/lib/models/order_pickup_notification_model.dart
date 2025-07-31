class OrderPickupNotificationModel {
  final int orderId;
  final int? tableNumber; // Masa numarası null olabilir diye nullable yaptık.
  final String message;

  OrderPickupNotificationModel({
    required this.orderId,
    this.tableNumber,
    required this.message,
  });

  factory OrderPickupNotificationModel.fromJson(Map<String, dynamic> json) {
    return OrderPickupNotificationModel(
      orderId: json['order_id'],
      tableNumber: json['table_number'],
      message: json['message'],
    );
  }
}
