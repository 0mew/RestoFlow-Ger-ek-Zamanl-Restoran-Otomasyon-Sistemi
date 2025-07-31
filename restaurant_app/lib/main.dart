import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts importu
import 'package:provider/provider.dart';
import 'api/websocket_service.dart';
import 'screens/role_selection_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WebSocketService()..connect(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Temel renklerimizi tanımlayalım
    final Color primaryColor = Colors.blueGrey.shade800; // Koyu mavi-gri
    final Color accentColor = Colors.amber.shade700; // Canlı bir amber/turuncu

    return MaterialApp(
      title: 'Restoran Otomasyon',
      debugShowCheckedModeBanner: false, // Debug banner'ını kaldır
      theme: ThemeData(
        // Genel renk şeması
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: accentColor,
          brightness: Brightness.light, // Açık tema
        ),
        // AppBar Teması
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white, // AppBar başlık ve ikon renkleri
          elevation: 4.0,
          titleTextStyle: GoogleFonts.montserrat(
            // AppBar başlık fontu
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white, // <-- İSTEDİĞİN RENK BURAYA!
          ),
        ),
        // Yazı Tipi Teması
        textTheme: GoogleFonts.latoTextTheme(
          // Tüm uygulama için temel font
          Theme.of(context).textTheme,
        ),
        // Buton Temaları
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        // Card Teması
        cardTheme: CardThemeData(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        ),
        // FloatingActionButton Teması
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
        ),
        // Input Alanları Teması (TextField vb.)
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: accentColor, width: 2.0),
          ),
          labelStyle: TextStyle(color: primaryColor),
        ),
        useMaterial3: true,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}
