import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter için
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import 'payment_success_screen.dart';
import '../../models/customer_order_models.dart';

class PaymentScreen extends StatefulWidget {
  final int tableId;
  final List<CustomerOrderItemModel> itemsToPay;
  final double amountToPay;

  const PaymentScreen({
    super.key,
    required this.tableId,
    required this.itemsToPay,
    required this.amountToPay,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isProcessingPayment = false; // Yüklenme durumu için

  void _processMockPayment() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isProcessingPayment = true; // Ödeme işlemi başlıyor
      });

      final service = Provider.of<WebSocketService>(context, listen: false);
      final paidOrderItemIds =
          widget.itemsToPay.map((item) => item.orderItemId).toList();

      service.sendMessage(
        jsonEncode({
          'type': 'process_payment',
          'payload': {
            'table_id': widget.tableId,
            'paid_order_item_ids': paidOrderItemIds,
          },
        }),
      );

      // Sunucudan bir cevap beklemek yerine direkt yönlendiriyoruz.
      // Gerçek bir uygulamada, sunucudan ödeme onayı geldikten sonra yönlendirme yapılır.
      // Şimdilik bu iyimser yaklaşım yeterli.
      // Yönlendirme öncesi isLoading'i false yapmaya gerek yok, sayfa değişiyor.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => PaymentSuccessScreen(
                paidItems: widget.itemsToPay,
                totalAmount: widget.amountToPay,
              ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ödeme Bilgileri',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        // backgroundColor ve foregroundColor temadan gelecek
      ),
      body: Center(
        // İçeriği ortalamak için
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            // Formu bir kart içine alalım
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize:
                      MainAxisSize
                          .min, // Column'un içeriğe göre boyutlanması için
                  children: [
                    Text(
                      'Ödenecek Tutar',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${widget.amountToPay.toStringAsFixed(2)} TL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'Kart Numarası',
                        prefixIcon: Icon(
                          Icons.credit_card,
                          color: primaryColor,
                        ),
                        hintText: 'XXXX XXXX XXXX XXXX',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        CardNumberInputFormatter(), // Basit bir formatlayıcı
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Kart numarası boş bırakılamaz.';
                        }
                        if (value.replaceAll(' ', '').length != 16) {
                          return 'Geçerli bir kart numarası girin (16 haneli).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryDateController,
                            decoration: InputDecoration(
                              labelText: 'Son Kul. Tarihi',
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: primaryColor,
                              ),
                              hintText: 'AA/YY',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              ExpiryDateInputFormatter(), // Basit bir formatlayıcı
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Boş bırakılamaz.';
                              }
                              if (!RegExp(
                                r'^(0[1-9]|1[0-2])\/?([0-9]{2})$',
                              ).hasMatch(value)) {
                                return 'AA/YY formatında girin.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: primaryColor,
                              ),
                              hintText: 'XXX',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Boş bırakılamaz.';
                              }
                              if (value.length < 3) {
                                return 'CVV 3 haneli olmalıdır.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _isProcessingPayment
                        ? Center(
                          child: CircularProgressIndicator(color: accentColor),
                        )
                        : ElevatedButton.icon(
                          icon: const Icon(Icons.payment),
                          label: const Text('Ödemeyi Onayla'),
                          onPressed: _processMockPayment,
                          // style temadan gelecek
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Basit kart numarası formatlayıcı (her 4 karakterde bir boşluk)
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write('  '); // Boşluk ekle
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// Basit son kullanma tarihi formatlayıcı (AA/YY)
class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var newText = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      if (i == 1 && newText.length > 2) {
        // İlk iki karakterden sonra '/' ekle
        buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
