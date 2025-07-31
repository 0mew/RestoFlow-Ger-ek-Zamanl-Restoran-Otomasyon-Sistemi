import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import '../../models/menu_item_model.dart';
import '../../models/kitchen_order_model.dart';

// Yeni sipariş sepeti için yardımcı sınıf
class NewOrderItem {
  final MenuItemModel menuItem;
  int quantity;
  String notes;
  NewOrderItem({required this.menuItem, this.quantity = 1, this.notes = ''});
}

class TableActionScreen extends StatefulWidget {
  final int tableId;
  final int tableNumber;

  const TableActionScreen({
    super.key,
    required this.tableId,
    required this.tableNumber,
  });

  @override
  State<TableActionScreen> createState() => _TableActionScreenState();
}

class _TableActionScreenState extends State<TableActionScreen> {
  final List<NewOrderItem> _newOrderBasket = [];
  final Set<int> _selectedForPosPayment = {};

  final PageController _pageController = PageController();
  int _currentSection = 0; // 0: Yeni Sipariş, 1: Mevcut Siparişler

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  void _fetchInitialData() {
    if (!mounted) return;
    final service = Provider.of<WebSocketService>(context, listen: false);
    service.currentTableOrders = []; // Ekran açıldığında eski veriyi temizle
    service.sendMessage(jsonEncode({'type': 'get_menu'}));
    service.sendMessage(
      jsonEncode({
        'type': 'get_orders_for_table',
        'payload': {'table_id': widget.tableId},
      }),
    );
  }

  // --- Yeni Sipariş Sepeti Fonksiyonları ---
  void _addItemToBasket(MenuItemModel item) {
    setState(() {
      final index = _newOrderBasket.indexWhere((i) => i.menuItem.id == item.id);
      if (index != -1) {
        _newOrderBasket[index].quantity++;
      } else {
        _newOrderBasket.add(NewOrderItem(menuItem: item));
      }
    });
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar(); // Önceki snackbar'ı gizle
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} sepete eklendi.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeItemFromBasket(int index) {
    setState(() {
      if (_newOrderBasket[index].quantity > 1) {
        _newOrderBasket[index].quantity--;
      } else {
        _newOrderBasket.removeAt(index);
      }
    });
  }

  void _submitNewOrder() {
    if (_newOrderBasket.isEmpty) return;
    final service = Provider.of<WebSocketService>(context, listen: false);
    final payloadItems =
        _newOrderBasket
            .map(
              (orderItem) => {
                'id': orderItem.menuItem.id,
                'quantity': orderItem.quantity,
                'notes': orderItem.notes,
              },
            )
            .toList();
    service.sendMessage(
      jsonEncode({
        'type': 'new_order',
        'payload': {'table_id': widget.tableId, 'items': payloadItems},
      }),
    );
    setState(() => _newOrderBasket.clear());
    // Sunucudan gelen `new_order_for_kitchen` mesajı ve `table_status_update`
    // diğer ekranları güncelleyecektir. Bu ekranın verisini de yenileyelim.
    Future.delayed(const Duration(milliseconds: 300), _fetchInitialData);
  }

  // --- Mevcut Siparişler ve Ödeme Fonksiyonları ---
  void _togglePosPaymentSelection(KitchenOrderItem item) {
    if (item.paymentStatus == 'paid') return;
    setState(() {
      if (_selectedForPosPayment.contains(item.orderItemId)) {
        _selectedForPosPayment.remove(item.orderItemId);
      } else {
        _selectedForPosPayment.add(item.orderItemId);
      }
    });
  }

  void _processPosPayment() {
    if (_selectedForPosPayment.isEmpty) return;
    final service = Provider.of<WebSocketService>(context, listen: false);
    service.sendMessage(
      jsonEncode({
        'type': 'process_payment',
        'payload': {
          'table_id': widget.tableId,
          'paid_order_item_ids': _selectedForPosPayment.toList(),
        },
      }),
    );
    setState(() => _selectedForPosPayment.clear());
    // Sunucu, `_handleProcessPayment` içinde güncel masa listesini geri gönderecek ve Consumer UI'ı yenileyecek.
  }

  // --- Genel Masa Aksiyonları ---
  void _deliverReadyOrders() {
    final service = Provider.of<WebSocketService>(context, listen: false);
    final readyOrderIds =
        service.currentTableOrders
            .where((o) => o.status == 'ready')
            .map((o) => o.orderId)
            .toList();
    if (readyOrderIds.isEmpty) return;

    for (var orderId in readyOrderIds) {
      service.sendMessage(
        jsonEncode({
          'type': 'order_delivered',
          'payload': {'order_id': orderId},
        }),
      );
    }
    // Değişikliğin yansıması için veriyi yenile
    Future.delayed(const Duration(milliseconds: 300), _fetchInitialData);
  }

  void _clearTable() {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Masayı Temizle'),
            content: Text(
              'Masa ${widget.tableNumber} için tüm siparişleri temizleyip masayı boşa almak istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final service = Provider.of<WebSocketService>(
                    context,
                    listen: false,
                  );
                  service.sendMessage(
                    jsonEncode({
                      'type': 'clear_table',
                      'payload': {'table_id': widget.tableId},
                    }),
                  );
                  Navigator.pop(dialogContext); // Diyalogu kapat
                  Navigator.pop(context); // Masa listesine dön
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Evet, Temizle'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Masa ${widget.tableNumber} Yönetimi',
          style: GoogleFonts.montserrat(),
        ),
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          final menuItems = service.menuItems;
          final existingOrders = service.currentTableOrders;
          bool hasReadyOrder = existingOrders.any((o) => o.status == 'ready');

          return Column(
            children: [
              _buildSectionToggle(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged:
                      (index) => setState(() => _currentSection = index),
                  children: [
                    _buildNewOrderPage(menuItems),
                    _buildExistingOrdersPage(existingOrders),
                  ],
                ),
              ),
              _buildActionButtons(hasReadyOrder, existingOrders),
            ],
          );
        },
      ),
    );
  }

  // --- YARDIMCI BUILD METODLARI ---

  Widget _buildSectionToggle() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed:
                  () => _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
              icon: Icon(
                Icons.add_shopping_cart,
                color:
                    _currentSection == 0
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey,
              ),
              label: Text(
                'Yeni Sipariş',
                style: TextStyle(
                  color:
                      _currentSection == 0
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          Expanded(
            child: TextButton.icon(
              onPressed:
                  () => _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
              icon: Icon(
                Icons.receipt_long_outlined,
                color:
                    _currentSection == 1
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey,
              ),
              label: Text(
                'Mevcut Siparişler',
                style: TextStyle(
                  color:
                      _currentSection == 1
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.grey,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewOrderPage(List<MenuItemModel> menuItems) {
    return Column(
      children: [
        if (_newOrderBasket.isNotEmpty) _buildNewOrderBasket(),
        Expanded(child: _buildMenuSection(menuItems)),
      ],
    );
  }

  Widget _buildNewOrderBasket() {
    double basketTotal = 0.0;
    for (var item in _newOrderBasket) {
      basketTotal += item.menuItem.price * item.quantity;
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.amber.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Yeni Sipariş Sepeti (${_newOrderBasket.length} ürün)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${basketTotal.toStringAsFixed(2)} TL',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            itemCount: _newOrderBasket.length,
            itemBuilder: (context, index) {
              final item = _newOrderBasket[index];
              return ListTile(
                dense: true,
                title: Text('${item.quantity}x ${item.menuItem.name}'),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  onPressed: () => _removeItemFromBasket(index),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(List<MenuItemModel> menuItems) {
    if (menuItems.isEmpty)
      return const Center(child: CircularProgressIndicator());

    Map<String, List<MenuItemModel>> groupedMenu = {};
    for (var item in menuItems) {
      groupedMenu.putIfAbsent(item.category, () => []).add(item);
    }
    var sortedCategories = groupedMenu.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: sortedCategories.length,
      itemBuilder: (context, categoryIndex) {
        String category = sortedCategories[categoryIndex];
        List<MenuItemModel> itemsInCategory = groupedMenu[category]!;
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          child: ExpansionTile(
            title: Text(
              category,
              style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            initiallyExpanded: true,
            childrenPadding: const EdgeInsets.all(8.0).copyWith(top: 0),
            children:
                itemsInCategory.map((item) {
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('${item.price.toStringAsFixed(2)} TL'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Theme.of(context).colorScheme.secondary,
                      onPressed: () => _addItemToBasket(item),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildExistingOrdersPage(List<KitchenOrderModel> existingOrders) {
    if (existingOrders.isEmpty)
      return const Center(
        child: Text(
          "Bu masa için mevcut sipariş yok.",
          style: TextStyle(fontSize: 16),
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: existingOrders.length,
      itemBuilder: (context, index) {
        final order = existingOrders[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          child: ExpansionTile(
            title: Text(
              'Sipariş ID: ${order.orderId} - Durum: ${order.status.toUpperCase()}',
            ),
            initiallyExpanded: true,
            children:
                order.items.map((item) {
                  bool isPaid = item.paymentStatus == 'paid';
                  return CheckboxListTile(
                    title: Text(
                      '${item.quantity}x ${item.name}',
                      style: TextStyle(
                        decoration: isPaid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      '${(item.price * item.quantity).toStringAsFixed(2)} TL',
                    ),
                    value: _selectedForPosPayment.contains(item.orderItemId),
                    onChanged:
                        isPaid
                            ? null
                            : (bool? value) => _togglePosPaymentSelection(item),
                    secondary:
                        isPaid
                            ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                            : null,
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    bool hasReadyOrder,
    List<KitchenOrderModel> existingOrders,
  ) {
    double posPaymentSubtotal = 0.0;
    for (var order in existingOrders) {
      for (var item in order.items) {
        if (_selectedForPosPayment.contains(item.orderItemId)) {
          posPaymentSubtotal += item.price * item.quantity;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add_task_outlined),
            label: Text('Sipariş Onayla (${_newOrderBasket.length})'),
            onPressed: _newOrderBasket.isNotEmpty ? _submitNewOrder : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.credit_card_outlined),
            label: Text(
              'POS ile Öde (${posPaymentSubtotal.toStringAsFixed(2)} TL)',
            ),
            onPressed:
                _selectedForPosPayment.isNotEmpty ? _processPosPayment : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delivery_dining_outlined),
            label: const Text('Teslim Edildi'),
            onPressed: hasReadyOrder ? _deliverReadyOrders : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasReadyOrder ? Colors.teal : Colors.grey,
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Masa Boş'),
            onPressed: _clearTable,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
