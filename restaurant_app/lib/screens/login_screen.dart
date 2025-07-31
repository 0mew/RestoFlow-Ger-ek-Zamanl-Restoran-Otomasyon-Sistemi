import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../api/websocket_service.dart';
import 'waiter/table_list_screen.dart';
import 'kitchen/kitchen_orders_screen.dart';
import 'admin/admin_panel_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText; // UI'da gösterilecek hata metni

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorText = null; // Önceki hatayı temizle
      });
      final service = Provider.of<WebSocketService>(context, listen: false);
      final loginMessage = {
        'type': 'login',
        'payload': {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        },
      };
      service.sendMessage(jsonEncode(loginMessage));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Personel Girişi', style: GoogleFonts.montserrat()),
        // Tema'dan gelen stiller kullanılacak
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          // --- YENİ VE DÖNGÜYÜ ENGELLEYEN MANTIK ---
          // Eğer işlenmemiş bir giriş olayı varsa...
          if (!service.loginEventHandled) {
            // Bu işlemi build metodu bittikten sonra güvenle yap
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              // 1. Durum: Giriş başarılı mı?
              if (service.isLoggedIn) {
                // Yönlendirme yap
                if (service.userRole == 'waiter') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TableListScreen(),
                    ),
                  );
                } else if (service.userRole == 'kitchen') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KitchenOrdersScreen(),
                    ),
                  );
                } else if (service.userRole == 'admin') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminPanelScreen(),
                    ),
                  );
                }

                // EN ÖNEMLİ KISIM: Olayı tüket!
                service.consumeLoginEvent();
              }
              // 2. Durum: Giriş başarısız mı?
              else {
                setState(() {
                  _errorText =
                      service.loginErrorMessage; // Hata metnini UI'a yansıt
                  _isLoading = false; // Yüklenmeyi durdur
                });

                // EN ÖNEMLİ KISIM: Olayı tüket!
                service.consumeLoginEvent();
              }
            });
          }
          // --- MANTIK SONU ---

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
                      Icons.food_bank_rounded,
                      size: 80,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Yönetim Paneli Girişi',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 40),

                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator:
                          (value) =>
                              value!.isEmpty
                                  ? 'Kullanıcı adı boş bırakılamaz.'
                                  : null,
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator:
                          (value) =>
                              value!.isEmpty ? 'Şifre boş bırakılamaz.' : null,
                      onFieldSubmitted:
                          (_) => _login(), // Enter'a basınca giriş yap
                    ),

                    const SizedBox(height: 16),

                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 20),

                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Giriş Yap'),
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
