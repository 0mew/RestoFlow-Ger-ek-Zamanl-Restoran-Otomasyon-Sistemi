import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts importu
import '../../models/customer_order_models.dart'; // Modelimizi import ettik
import '../role_selection_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final List<CustomerOrderItemModel> paidItems;
  final double totalAmount;

  const PaymentSuccessScreen({
    super.key,
    required this.paidItems,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final Color successColor = Colors.green.shade700; // Temadan da alınabilir

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        // Ekran çentikleri vb. için güvenli alan
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 30.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Butonun genişlemesi için
              children: [
                Icon(
                  Icons.check_circle_outline_rounded, // Daha dolgun bir ikon
                  color: successColor,
                  size: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ödeme Başarılı!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: successColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${totalAmount.toStringAsFixed(2)} TL tutarındaki ödemeniz onaylandı.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 17,
                    color: Colors.black87, // Biraz daha koyu
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Ödenen Ürünler:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                if (paidItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Ödenen ürün detayı bulunmuyor.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                else
                  Expanded(
                    // Eğer ürün listesi çok uzun olursa diye Expanded ve ListView
                    // Ancak genellikle birkaç ürün olacağı için çok uzun olmayacaktır.
                    // Çok fazla ürün varsa, bu Expanded'a bir maxHeight verilebilir.
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 200,
                      ), // Liste için maksimum yükseklik
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: paidItems.length,
                        itemBuilder: (context, index) {
                          final item = paidItems[index];
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Text(
                              '${item.quantity}x',
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: GoogleFonts.lato(fontSize: 15),
                            ),
                            trailing: Text(
                              '${(item.price * item.quantity).toStringAsFixed(2)} TL',
                              style: GoogleFonts.lato(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                        separatorBuilder:
                            (context, index) => const Divider(
                              indent: 16,
                              endIndent: 16,
                              height: 1,
                            ),
                      ),
                    ),
                  ),
                const SizedBox(height: 30), // Boşluk artırıldı
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const RoleSelectionScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  // Stil temadan gelecek, ama istersek override edebiliriz:
                  // style: ElevatedButton.styleFrom(
                  //   padding: const EdgeInsets.symmetric(vertical: 15),
                  //   textStyle: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500),
                  // ),
                  child: const Text('Ana Ekrana Dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
