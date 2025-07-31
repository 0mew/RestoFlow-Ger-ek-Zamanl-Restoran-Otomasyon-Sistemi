import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import '../role_selection_screen.dart';
import 'staff_management_screen.dart';
import 'menu_management_screen.dart';
import 'table_management_screen.dart';
import 'sales_report_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Temadan renkleri alalım
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor =
        Theme.of(
          context,
        ).colorScheme.onPrimary; // AppBar'daki yazı/ikonlar için
    final Color cardBackgroundColor =
        Theme.of(context).cardColor; // Kartların arka planı için
    final Color iconColor =
        Theme.of(context).colorScheme.secondary; // İkonlar için vurgu rengi

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Paneli',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        // backgroundColor ve foregroundColor zaten temadan geliyor olmalı
        // Eğer `main.dart` içindeki AppBarTheme'de renkler ayarlıysa, burada tekrar belirtmeye gerek yok.
        // Örnek olması açısından, temadaki birincil rengi kullanalım:
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () {
              Provider.of<WebSocketService>(context, listen: false).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      // Hafif bir arka plan rengi (opsiyonel)
      // backgroundColor: Colors.grey.shade100,
      body: Column(
        // Üst başlık ve GridView için Column
        children: [
          // Başlık veya Hoş Geldin Bölümü
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 16.0,
            ),
            // color: primaryColor.withOpacity(0.1), // Hafif bir arka plan
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yönetim Merkezi',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Restoran verilerini ve ayarlarını buradan yönetebilirsiniz.',
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // GridView'ı Expanded ile sarmalayarak kalan alanı kaplamasını sağlıyoruz
          Expanded(
            child: GridView.count(
              crossAxisCount:
                  MediaQuery.of(context).size.width > 600
                      ? 3
                      : 2, // Geniş ekranlarda 3 sütun
              padding: const EdgeInsets.all(16.0),
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.1, // Kartların oranını biraz değiştirelim
              children: <Widget>[
                _buildAdminButton(
                  context,
                  icon: Icons.people_alt_rounded, // Daha dolgun ikonlar
                  label: 'Çalışan Yönetimi',
                  description: 'Personel ekle, sil, listele.', // Açıklama
                  color: iconColor, // Tema rengi
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StaffManagementScreen(),
                        ),
                      ),
                ),
                _buildAdminButton(
                  context,
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Menü Yönetimi',
                  description: 'Ürün ekle, düzenle, sil.',
                  color: iconColor,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MenuManagementScreen(),
                        ),
                      ),
                ),
                _buildAdminButton(
                  context,
                  icon: Icons.table_restaurant_rounded,
                  label: 'Masa Yönetimi',
                  description: 'Masa sayısını ayarla.',
                  color: iconColor,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TableManagementScreen(),
                        ),
                      ),
                ),
                _buildAdminButton(
                  context,
                  icon: Icons.assessment_rounded, // Daha dolgun ikon
                  label: 'Satış Raporları',
                  description: 'Satış verilerini görüntüle.',
                  color: iconColor,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SalesReportScreen(),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // _buildAdminButton metodunu daha fazla detay ve stil ile güncelleyelim
  Widget _buildAdminButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description, // Yeni parametre: açıklama
    required Color color, // Yeni parametre: ikon rengi
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3.0, // Biraz daha az gölge
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ), // Daha yuvarlak kenarlar
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Padding(
          // İçerik için padding
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                // İkonu bir daire içine alalım
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36.0,
                  color: color,
                ), // Boyutu biraz küçülttük
              ),
              const SizedBox(height: 14.0),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  // Temadan font
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600, // Biraz daha kalın
                  color:
                      Theme.of(
                        context,
                      ).textTheme.titleLarge?.color, // Temadan yazı rengi
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                // Açıklama metni
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  // Temadan font
                  fontSize: 12.0,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
