import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import '../../models/sales_report_models.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  // _isLoading bayrağını Consumer içindeki service.salesReportData durumuna göre yöneteceğiz.
  // Bu yüzden _isLoading state'ine burada direkt ihtiyacımız olmayabilir.
  // Ancak _fetchSalesReport çağrıldığında bir yükleme animasyonu tetiklemek için tutulabilir.
  bool _isFetching = true; // İlk yükleme ve yenileme için

  @override
  void initState() {
    super.initState();
    _fetchSalesReport();
  }

  void _fetchSalesReport() {
    if (!mounted) return;
    setState(
      () => _isFetching = true,
    ); // Yeniden fetch ederken yükleniyor göster
    Provider.of<WebSocketService>(
      context,
      listen: false,
    ).sendMessage(jsonEncode({'type': 'get_sales_report'}));
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary;
    final Color onPrimaryColor =
        Theme.of(context).colorScheme.onPrimary; // AppBar metin/ikon rengi

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Satış Raporu',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        // backgroundColor, foregroundColor temadan gelir
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Raporu Yenile',
            onPressed: _fetchSalesReport,
          ),
        ],
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          // _isFetching durumunu, servisten veri geldiğinde (başarılı veya hatalı) false yapalım.
          if (service.salesReportData != null ||
              service.salesReportMessage != null) {
            if (_isFetching) {
              // Sadece bir kez, veri geldikten sonra false yap
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isFetching = false);
              });
            }
          }

          // Hata mesajı varsa SnackBar ile göster
          if (service.salesReportMessage != null &&
              !_isFetching /*hata mesajı yükleme bitince gösterilsin*/ ) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && ModalRoute.of(context)!.isCurrent) {
                // Sadece bu ekran aktifse göster
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(service.salesReportMessage!),
                    backgroundColor: Colors.redAccent, // Hata için farklı renk
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                service
                    .clearSalesReportMessage(); // Mesajı gösterdikten sonra temizle
              }
            });
          }

          if (_isFetching && service.salesReportData == null) {
            // İstek gönderildi ama cevap bekleniyor
            return Center(child: CircularProgressIndicator(color: accentColor));
          }

          if (service.salesReportData == null) {
            // Veri yok ve hata mesajı da yoksa (veya hata mesajı gösterildiyse)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sentiment_dissatisfied_outlined,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Rapor verisi yüklenemedi veya bulunmuyor.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final reportData = service.salesReportData!;

          if (reportData.reportItems.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gösterilecek satış verisi bulunmamaktadır.',
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  // Genel Toplam Gelir için Kart
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  color: primaryColor.withOpacity(
                    0.9,
                  ), // Temanın birincil rengi
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          'Genel Toplam Gelir',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: onPrimaryColor.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${reportData.overallTotalRevenue.toStringAsFixed(2)} TL',
                          style: GoogleFonts.montserrat(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: onPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Detaylı Satışlar",
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Theme(
                  // DataTable için özel tema (opsiyonel)
                  data: Theme.of(context).copyWith(
                    dividerColor: accentColor.withOpacity(0.3),
                    dataTableTheme: DataTableThemeData(
                      headingRowHeight: 48,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      headingTextStyle: GoogleFonts.lato(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                      dataTextStyle: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  child: DataTable(
                    columnSpacing: 12, // Sütunlar arası boşluk
                    horizontalMargin: 8, // Kenar boşlukları
                    headingRowColor: WidgetStateColor.resolveWith(
                      (states) => accentColor.withOpacity(0.1),
                    ),
                    columns: const [
                      DataColumn(label: Text('Ürün Adı')),
                      DataColumn(label: Text('Kategori')),
                      DataColumn(label: Text('Adet'), numeric: true),
                      DataColumn(label: Text('Birim F.'), numeric: true),
                      DataColumn(label: Text('Toplam'), numeric: true),
                    ],
                    rows:
                        reportData.reportItems.map((item) {
                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>((
                              Set<WidgetState> states,
                            ) {
                              // Satırları zebra deseni yapmak için (opsiyonel)
                              // final index = reportData.reportItems.indexOf(item);
                              // if (index.isEven) return Colors.grey.shade100.withOpacity(0.5);
                              return null; // Varsayılan arka plan
                            }),
                            cells: [
                              DataCell(Text(item.productName)),
                              DataCell(Text(item.productCategory)),
                              DataCell(Text(item.totalQuantitySold.toString())),
                              DataCell(Text(item.unitPrice.toStringAsFixed(2))),
                              DataCell(
                                Text(
                                  item.totalRevenueForProduct.toStringAsFixed(
                                    2,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
