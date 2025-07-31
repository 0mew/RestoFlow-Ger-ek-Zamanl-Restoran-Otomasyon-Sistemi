import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tableCountController = TextEditingController();
  // _currentDisplayedTableCount'i Consumer içinde doğrudan service.tables.length'ten alacağız.
  // Bu yüzden state'te tutmaya gerek kalmayabilir, ancak TextField'ı başlangıçta doldurmak için kullanışlı.
  // didChangeDependencies'de güncelleme mantığı iyi çalışıyor.
  int _currentDisplayedTableCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<WebSocketService>(context, listen: false);
      // Ekran açıldığında mevcut masa sayısını almak için get_tables isteği gönderilir.
      // Bu, service.tables listesini doldurur, Consumer bunu dinler.
      service.sendMessage(jsonEncode({'type': 'get_tables'}));
      // Başlangıçta controller'ı doldurmak için
      // _currentDisplayedTableCount'ı da service.tables.length ile güncelleyebiliriz.
      // Ancak didChangeDependencies bunu zaten yapacak.
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = Provider.of<WebSocketService>(
      context,
    ); // listen: true (varsayılan)
    // Servisteki tables listesinin uzunluğu değiştiğinde UI'ı ve controller'ı güncelle
    if (_currentDisplayedTableCount != service.tables.length) {
      setState(() {
        _currentDisplayedTableCount = service.tables.length;
        _tableCountController.text = _currentDisplayedTableCount.toString();
      });
    }
    // SnackBar gösterme mantığı Consumer içine taşındı.
  }

  void _updateTableCount() {
    if (_formKey.currentState!.validate()) {
      final newCount = int.tryParse(_tableCountController.text);
      if (newCount != null && newCount >= 0) {
        // 0 masa da geçerli bir durum olabilir (örn: restoran kapalı)
        final service = Provider.of<WebSocketService>(context, listen: false);
        service.clearTableManagementMessage();
        service.sendMessage(
          jsonEncode({
            'type': 'update_table_count',
            'payload': {'new_count': newCount},
          }),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen geçerli bir sayı (0 veya daha büyük) girin.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tableCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Masa Sayısı Yönetimi',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        // backgroundColor ve foregroundColor temadan gelecek
      ),
      body: Center(
        // İçeriği ortalamak ve maksimum genişlik vermek için
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
          ), // Form için maksimum genişlik
          child: SingleChildScrollView(
            // Küçük ekranlarda kaydırma için
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.table_restaurant_outlined,
                    size: 80,
                    color: primaryColor.withOpacity(0.8),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Masa Ayarları',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Consumer<WebSocketService>(
                    builder: (context, service, child) {
                      // SnackBar işlemleri build metodu içinde olmamalı, addPostFrameCallback ile yönetilmeli.
                      if (service.tableManagementMessage != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && ModalRoute.of(context)!.isCurrent) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(service.tableManagementMessage!),
                                backgroundColor:
                                    service.tableActionSuccess
                                        ? Colors.green
                                        : Colors.orangeAccent,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                margin: const EdgeInsets.all(10),
                              ),
                            );
                            service.clearTableManagementMessage();
                            // Başarılı güncelleme sonrası TextField'ı servisten gelen gerçek sayıyla güncelle
                            // Bu, didChangeDependencies içinde zaten yapılıyor olmalı.
                            if (service.tableActionSuccess) {
                              // _tableCountController.text = service.currentTableCountFromService.toString();
                              // setState(() { _currentDisplayedTableCount = service.currentTableCountFromService; });
                              // Yukarıdakiler yerine, _fetchTables çağrısı daha iyi olabilir
                              // veya service.tables.length'e güvenebiliriz.
                              // En son masa listesini almak için get_tables isteği gönder
                              service.sendMessage(
                                jsonEncode({'type': 'get_tables'}),
                              );
                            }
                          }
                        });
                      }
                      // _currentDisplayedTableCount, didChangeDependencies ile güncelleniyor
                      return Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Mevcut Masa Sayısı: ',
                                style: GoogleFonts.lato(fontSize: 18),
                              ),
                              Text(
                                '$_currentDisplayedTableCount',
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _tableCountController,
                    decoration: InputDecoration(
                      labelText: 'Yeni Toplam Masa Sayısı',
                      // border: OutlineInputBorder(), // Temadan gelecek
                      hintText: 'Örn: 30',
                      prefixIcon: Icon(
                        Icons.edit_outlined,
                        color: primaryColor,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Masa sayısı boş olamaz.';
                      }
                      final count = int.tryParse(value);
                      if (count == null || count < 0) {
                        return 'Geçerli bir sayı girin (0 veya daha büyük).'; // 0 masa da bir durum olabilir
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Masa Sayısını Güncelle'),
                    onPressed: _updateTableCount,
                    // style temadan gelecek
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Not: Masa sayısı azaltılırken, sadece "müsait" durumda olan ve en yüksek numaralı masalar sistemden kaldırılır. Aktif siparişi olan veya müşterisi bulunan masalar etkilenmez.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
