class SalesReportItemModel {
  final String productName;
  final String productCategory;
  final int totalQuantitySold;
  final double unitPrice;
  final double totalRevenueForProduct;

  SalesReportItemModel({
    required this.productName,
    required this.productCategory,
    required this.totalQuantitySold,
    required this.unitPrice,
    required this.totalRevenueForProduct,
  });

  factory SalesReportItemModel.fromJson(Map<String, dynamic> json) {
    return SalesReportItemModel(
      productName: json['product_name'] ?? 'Bilinmeyen Ürün',
      productCategory: json['product_category'] ?? 'Kategorisiz',
      totalQuantitySold: (json['total_quantity_sold'] as num? ?? 0).toInt(),
      unitPrice: (json['unit_price'] as num? ?? 0.0).toDouble(),
      totalRevenueForProduct:
          (json['total_revenue_for_product'] as num? ?? 0.0).toDouble(),
    );
  }
}

class SalesReportDataModel {
  final List<SalesReportItemModel> reportItems;
  final double overallTotalRevenue;

  SalesReportDataModel({
    required this.reportItems,
    required this.overallTotalRevenue,
  });

  factory SalesReportDataModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['report_items'] as List? ?? [];
    List<SalesReportItemModel> parsedItems =
        itemsList.map((i) => SalesReportItemModel.fromJson(i)).toList();
    return SalesReportDataModel(
      reportItems: parsedItems,
      overallTotalRevenue:
          (json['overall_total_revenue'] as num? ?? 0.0).toDouble(),
    );
  }
}
