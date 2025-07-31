// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../api/websocket_service.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   // Bu değişken, sunucudan gelen son mesajı ekranda göstermek için kullanılacak.
//   String _serverMessage = "Sunucuya bağlanılıyor...";

//   // initState, bu widget ekranda ilk kez oluşturulduğunda SADECE BİR KEZ çalışır.
//   // Bağlantıyı başlatmak için en doğru yerdir.
//   @override
//   void initState() {
//     super.initState();
//     // Widget ağacı tamamen çizildikten sonra bu kodun çalışmasını sağlıyoruz.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _initializeConnection();
//     });
//   }

//   void _initializeConnection() {
//     // Provider aracılığıyla WebSocketService örneğimize ulaşıyoruz.
//     final webSocketService = Provider.of<WebSocketService>(
//       context,
//       listen: false,
//     );

//     // Sunucuya bağlanma komutunu veriyoruz.
//     webSocketService.connect();

//     // Sunucudan gelen mesajları dinlemeye başlıyoruz.
//     webSocketService.messages?.listen((message) {
//       print('Flutter Tarafından Alındı: $message');

//       // Gelen JSON mesajını çözümlüyoruz.
//       final decodedMessage = jsonDecode(message);

//       // UI'ı güncellemek için setState kullanıyoruz.
//       setState(() {
//         _serverMessage = decodedMessage['message'];
//       });
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Provider'ı dinleyerek bağlantı durumundaki değişiklikleri anında UI'a yansıtıyoruz.
//     return Consumer<WebSocketService>(
//       builder: (context, webSocketService, child) {
//         return Scaffold(
//           appBar: AppBar(
//             title: const Text('Bağlantı Durumu'),
//             backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//           ),
//           body: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Bağlantı durumuna göre ikon göster
//                 Icon(
//                   webSocketService.isConnected
//                       ? Icons.check_circle
//                       : Icons.error,
//                   color:
//                       webSocketService.isConnected ? Colors.green : Colors.red,
//                   size: 80,
//                 ),
//                 const SizedBox(height: 20),
//                 // Bağlantı durumunu metin olarak göster
//                 Text(
//                   webSocketService.isConnected ? 'Bağlandı' : 'Bağlantı Yok',
//                   style: Theme.of(context).textTheme.headlineMedium,
//                 ),
//                 const SizedBox(height: 20),
//                 // Sunucudan gelen mesajı göster
//                 Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Text(
//                     'Sunucudan Gelen Mesaj:\n"$_serverMessage"',
//                     textAlign: TextAlign.center,
//                     style: Theme.of(context).textTheme.bodyLarge,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
  
  // burası artık kullanılmayacak sanırım.