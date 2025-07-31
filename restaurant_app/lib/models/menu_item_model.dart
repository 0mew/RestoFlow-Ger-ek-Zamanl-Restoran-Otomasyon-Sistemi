class MenuItemModel {
  final int id;
  final String name;
  final String category;
  final double price;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      // price veritabanından REAL (double) veya INTEGER olarak gelebilir.
      price: (json['price'] as num).toDouble(),
    );
  }
}
