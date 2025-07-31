import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter için
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../api/websocket_service.dart';
import 'login_screen.dart';
import 'customer/customer_order_view_screen.dart';
import '../screens/settings/server_ip_config_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tableNumberController = TextEditingController();
  bool _isLoadingCustomerLogin = false;
  String? _customerLoginErrorText;

  void _loginToTable(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoadingCustomerLogin = true;
        _customerLoginErrorText = null;
        Provider.of<WebSocketService>(context, listen: false)
            .customerLoginError = null;
      });

      final tableNumber = int.parse(_tableNumberController.text);
      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );

      webSocketService.sendMessage(
        jsonEncode({
          'type': 'customer_table_login',
          'payload': {'table_number': tableNumber},
        }),
      );
    }
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Restoranımıza Hoş Geldiniz',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          if (service.currentCustomerTable != null && _isLoadingCustomerLogin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _isLoadingCustomerLogin = false; // Yüklenmeyi durdur
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerOrderViewScreen(),
                ),
              );
            });
          } else if (service.customerLoginError != null &&
              _isLoadingCustomerLogin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _customerLoginErrorText = service.customerLoginError;
                _isLoadingCustomerLogin = false;
                service.customerLoginError = null;
              });
            });
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 30.0,
                vertical: 20.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.restaurant_menu_sharp,
                      size: 100,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Lezzet Durağımıza Hoş Geldiniz!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.pacifico(
                        // Farklı bir font denemesi
                        fontSize: 26,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Devam etmek için lütfen masa numaranızı girin:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _tableNumberController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: 'Masa No'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Masa numarası boş bırakılamaz.';
                        }
                        final num = int.tryParse(value);
                        if (num == null || num <= 0) {
                          // Max masa sayısını sunucudan alabiliriz veya sabit bırakabiliriz
                          return 'Geçerli bir masa numarası girin.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Hata Mesajı Alanı
                    if (_customerLoginErrorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _customerLoginErrorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Giriş Butonu
                    _isLoadingCustomerLogin
                        ? Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        )
                        : ElevatedButton(
                          // style: ElevatedButton.styleFrom( // Temadan gelecek
                          //   padding: const EdgeInsets.symmetric(vertical: 15),
                          //   textStyle: const TextStyle(fontSize: 18),
                          // ),
                          onPressed:
                              () => _loginToTable(context), // context'i gönder
                          child: const Text('Masaya Giriş Yap'),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.admin_panel_settings_outlined),
        label: const Text('Personel'),
        tooltip: 'Personel Girişi',
        onPressed: () {
          // Personel giriş ekranına yönlendirme
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
      ),
      // --- YENİ EKLENEN KISIM: IP AYAR BUTONU ---
      // Sol alta küçük bir buton ekleyelim
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextButton.icon(
              icon: Icon(
                Icons.settings_ethernet_outlined,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
              label: Text(
                'Sunucu IP Ayarı',
                style: GoogleFonts.lato(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServerIpConfigScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
