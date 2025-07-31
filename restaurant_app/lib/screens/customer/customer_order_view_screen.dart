import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import '../../models/customer_order_models.dart'; // CustomerOrderModel ve CustomerOrderItemModel burada
import 'payment_screen.dart'; // Ödeme ekranına yönlendirme için

class CustomerOrderViewScreen extends StatefulWidget {
  const CustomerOrderViewScreen({super.key});

  @override
  State<CustomerOrderViewScreen> createState() =>
      _CustomerOrderViewScreenState();
}

class _CustomerOrderViewScreenState extends State<CustomerOrderViewScreen> {
  final Set<int> _selectedOrderItemIds = {};
  double _paymentSubtotal = 0.0;

  // Bu fonksiyon initState içinde çağrılmıyor çünkü CustomerOrderViewScreen'e
  // gelmeden önce RoleSelectionScreen'de customer_table_login isteği gönderiliyor
  // ve WebSocketService'teki currentCustomerOrders listesi doluyor.
  // Bu ekran direkt Consumer ile bu dolu listeyi kullanıyor.

  void _toggleOrderItemSelection(
    CustomerOrderItemModel item,
    List<CustomerOrderModel> allOrders,
  ) {
    if (item.paymentStatus == 'paid') return;

    setState(() {
      if (_selectedOrderItemIds.contains(item.orderItemId)) {
        _selectedOrderItemIds.remove(item.orderItemId);
      } else {
        _selectedOrderItemIds.add(item.orderItemId);
      }
      _calculatePaymentSubtotal(allOrders);
    });
  }

  void _calculatePaymentSubtotal(List<CustomerOrderModel> allOrders) {
    double subtotal = 0.0;
    for (var order in allOrders) {
      for (var item in order.items) {
        if (_selectedOrderItemIds.contains(item.orderItemId)) {
          subtotal += item.price * item.quantity;
        }
      }
    }
    setState(() {
      _paymentSubtotal = subtotal;
    });
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'ready':
        return Colors.blue.shade600;
      case 'completed':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    // final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Consumer<WebSocketService>(
          // AppBar başlığını dinamik yapalım
          builder: (context, service, child) {
            return Text(
              service.currentCustomerTable != null
                  ? 'Masa ${service.currentCustomerTable!.tableNumber} - Siparişlerim'
                  : 'Siparişlerim',
              style: GoogleFonts.montserrat(color: Colors.white),
            );
          },
        ),
        // backgroundColor ve foregroundColor temadan gelecek
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          // Yüklenme veya hata durumları
          if (service.currentCustomerTable == null &&
              service.customerLoginError == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (service.customerLoginError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hata: ${service.customerLoginError}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        color: Colors.red.shade700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (service.currentCustomerOrders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bu masaya ait sipariş bulunmuyor.',
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

          // Siparişler yüklendikten sonra alt toplamı hesapla (ilk yüklemede)
          // Bu, _toggleOrderItemSelection dışında bir yerde de çağrılmalı ki
          // ekran ilk açıldığında _paymentSubtotal doğru olsun.
          // Ancak, Consumer her rebuild olduğunda bunu yapmak sonsuz döngüye sokabilir.
          // _calculatePaymentSubtotal(service.currentCustomerOrders); // BURADA ÇAĞIRMA!
          // Doğrusu, seçili ürünler değiştiğinde veya liste ilk geldiğinde hesaplamak.
          // Ya da _paymentSubtotal'ı build içinde anlık hesaplamak. Şimdilik _toggle'da kalması yeterli.

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: service.currentCustomerOrders.length,
                  itemBuilder: (context, orderIndex) {
                    final order = service.currentCustomerOrders[orderIndex];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 4.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sipariş ID: ${order.orderId}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getOrderStatusColor(
                                      order.orderStatus,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    order.orderStatus.toUpperCase(),
                                    style: GoogleFonts.lato(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, thickness: 1),
                            if (order.items.isEmpty)
                              const Text(
                                'Bu siparişte ürün bulunmuyor.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              )
                            else
                              ...order.items.map((item) {
                                bool isPaid = item.paymentStatus == 'paid';
                                bool isSelected = _selectedOrderItemIds
                                    .contains(item.orderItemId);
                                return Material(
                                  // CheckboxListTile'ın ripple efekti için
                                  color: Colors.transparent,
                                  child: CheckboxListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                      horizontal: 0,
                                    ),
                                    activeColor:
                                        Theme.of(context).colorScheme.secondary,
                                    value: isSelected,
                                    enabled: !isPaid, // Ödenmişse pasif yap
                                    onChanged:
                                        isPaid
                                            ? null
                                            : (bool? value) {
                                              _toggleOrderItemSelection(
                                                item,
                                                service.currentCustomerOrders,
                                              );
                                            },
                                    title: Text(
                                      '${item.quantity}x ${item.name}',
                                      style: GoogleFonts.lato(
                                        fontSize: 16,
                                        decoration:
                                            isPaid
                                                ? TextDecoration.lineThrough
                                                : null,
                                        color:
                                            isPaid
                                                ? Colors.grey.shade600
                                                : null,
                                      ),
                                    ),
                                    subtitle:
                                        item.notes.isNotEmpty
                                            ? Text(
                                              '(${item.notes})',
                                              style: GoogleFonts.lato(
                                                fontStyle: FontStyle.italic,
                                                color:
                                                    isPaid
                                                        ? Colors.grey.shade500
                                                        : Colors.blueGrey,
                                              ),
                                            )
                                            : null,
                                    secondary: Column(
                                      // Fiyat ve ödeme durumu
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${(item.price * item.quantity).toStringAsFixed(2)} TL',
                                          style: GoogleFonts.lato(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isPaid
                                                    ? Colors.grey.shade600
                                                    : null,
                                          ),
                                        ),
                                        if (isPaid)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2.0),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 18,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Ödeme Özeti ve Buton
              Container(
                padding: const EdgeInsets.fromLTRB(
                  16.0,
                  16.0,
                  16.0,
                  24.0,
                ), // Alt boşluğu artırdık
                decoration: BoxDecoration(
                  color:
                      Theme.of(
                        context,
                      ).canvasColor, // Arka planla uyumlu veya farklı bir renk
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  // border: Border(top: BorderSide(color: Colors.grey.shade300))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ödenecek Tutar:',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${_paymentSubtotal.toStringAsFixed(2)} TL',
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment_outlined),
                      label: const Text('Seçilenleri Öde'),
                      style: ElevatedButton.styleFrom(
                        // backgroundColor: accentColor, // Temadan gelecek
                        // foregroundColor: Colors.white, // Temadan gelecek
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        textStyle: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed:
                          _selectedOrderItemIds.isEmpty
                              ? null
                              : () {
                                final service = Provider.of<WebSocketService>(
                                  context,
                                  listen: false,
                                );
                                if (service.currentCustomerTable != null) {
                                  List<CustomerOrderItemModel> itemsToPay = [];
                                  for (var order
                                      in service.currentCustomerOrders) {
                                    for (var item in order.items) {
                                      if (_selectedOrderItemIds.contains(
                                        item.orderItemId,
                                      )) {
                                        itemsToPay.add(item);
                                      }
                                    }
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => PaymentScreen(
                                            tableId:
                                                service
                                                    .currentCustomerTable!
                                                    .id,
                                            itemsToPay: itemsToPay,
                                            amountToPay: _paymentSubtotal,
                                          ),
                                    ),
                                  );
                                }
                              },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
