import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/websocket_service.dart'; // WebSocketService'in yolu doğru olmalı

class ServerIpConfigScreen extends StatefulWidget {
  const ServerIpConfigScreen({super.key});

  @override
  State<ServerIpConfigScreen> createState() => _ServerIpConfigScreenState();
}

class _ServerIpConfigScreenState extends State<ServerIpConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  String? _currentSavedIp;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentIp();
  }

  Future<void> _loadCurrentIp() async {
    final prefs = await SharedPreferences.getInstance();
    // Anahtarımızı WebSocketService'teki ile aynı yapalım
    setState(() {
      _currentSavedIp = prefs.getString('server_ip');
      _ipController.text = _currentSavedIp ?? ''; // Kayıtlı IP varsa göster
    });
  }

  Future<void> _saveAndReconnect() async {
    if (_formKey.currentState!.validate()) {
      final newIp = _ipController.text.trim();
      setState(() => _isLoading = true);

      final service = Provider.of<WebSocketService>(context, listen: false);
      await service.updateServerIp(
        newIp,
      ); // Servisteki IP'yi güncelle ve yeniden bağlanmayı tetikle

      // Yeni IP'yi kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', newIp);

      setState(() {
        _currentSavedIp = newIp;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sunucu IP adresi güncellendi: $newIp. Yeniden bağlanılıyor...',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Bir önceki ekrana dön
      }
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sunucu IP Ayarı', style: GoogleFonts.montserrat()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mevcut Kayıtlı IP: ${_currentSavedIp ?? "Ayarlanmamış"}',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Yeni Sunucu IP Adresi',
                  hintText: 'Örn: 192.168.1.105',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.dns_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                keyboardType: TextInputType.url, // IP adresleri için daha uygun
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'IP adresi boş olamaz.';
                  }
                  // Basit bir IP formatı kontrolü (daha karmaşık regex'ler kullanılabilir)
                  final RegExp ipRegExp = RegExp(
                    r"^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$",
                  );
                  if (!ipRegExp.hasMatch(value.trim())) {
                    return 'Lütfen geçerli bir IP adresi formatı girin.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Kaydet ve Yeniden Bağlan'),
                  onPressed: _saveAndReconnect,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Not: Buraya sunucunun çalıştığı bilgisayarın yerel ağdaki IP adresini girmelisiniz. Port numarası (örn: 55555) kod içinde sabittir.',
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
    );
  }
}
