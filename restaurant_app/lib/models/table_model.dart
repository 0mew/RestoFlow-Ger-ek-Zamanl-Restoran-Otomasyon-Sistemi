class TableModel {
  final int id;
  final int tableNumber;
  final String status; // 'available', 'ordered', 'delivered'

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.status,
  });

  // Gelen JSON verisinden bir TableModel nesnesi oluşturur.
  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      tableNumber: json['table_number'],
      status: json['status'],
    );
  }
}
