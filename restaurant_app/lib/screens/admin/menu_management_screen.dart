import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import '../../models/menu_item_model.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMenuList();
  }

  void _fetchMenuList() {
    Provider.of<WebSocketService>(
      context,
      listen: false,
    ).sendMessage(jsonEncode({'type': 'get_menu'}));
  }

  void _showItemDialog({MenuItemModel? itemToEdit}) {
    final service = Provider.of<WebSocketService>(context, listen: false);
    service.clearMenuManagementMessage();

    bool isEditing = itemToEdit != null;
    if (isEditing) {
      _nameController.text = itemToEdit.name;
      _categoryController.text = itemToEdit.category;
      _priceController.text = itemToEdit.price.toStringAsFixed(2);
    } else {
      _nameController.clear();
      _categoryController.clear();
      _priceController.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text(
            isEditing ? '"${itemToEdit.name}" Düzenle' : 'Yeni Menü Ürünü Ekle',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          ),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ürün Adı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fastfood_outlined),
                    ),
                    validator:
                        (value) =>
                            value!.isEmpty ? 'Ürün adı boş olamaz' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      hintText: 'Örn: Ana Yemekler',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator:
                        (value) =>
                            value!.isEmpty ? 'Kategori boş olamaz' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Fiyat (TL)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Fiyat boş olamaz';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) <= 0) {
                        return 'Geçerli bir fiyat girin';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'İptal',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              // style temadan gelecek
              child: Text(isEditing ? 'Kaydet' : 'Ekle'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final type = isEditing ? 'edit_menu_item' : 'add_menu_item';
                  final payload = {
                    if (isEditing) 'id': itemToEdit.id,
                    'name': _nameController.text,
                    'category': _categoryController.text,
                    'price': double.parse(_priceController.text),
                  };
                  service.sendMessage(
                    jsonEncode({'type': type, 'payload': payload}),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    /* ... aynı ... */
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Menü Yönetimi',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMenuList,
          ),
        ],
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          if (service.menuManagementMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && ModalRoute.of(context)!.isCurrent) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(service.menuManagementMessage!),
                    backgroundColor:
                        service.menuActionSuccess ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating, // Daha modern görünüm
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                service.clearMenuManagementMessage();
                if (service.menuActionSuccess) _fetchMenuList();
              }
            });
          }

          if (service.menuItems.isEmpty && service.isConnected) {
            // Bağlı ama menü boşsa
            return Center(child: CircularProgressIndicator(color: accentColor));
          } else if (!service.isConnected && service.menuItems.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.signal_wifi_off_outlined,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Sunucuya bağlanılamadı veya menü bilgisi yok.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          Map<String, List<MenuItemModel>> groupedMenu = {};
          for (var item in service.menuItems) {
            groupedMenu.putIfAbsent(item.category, () => []).add(item);
          }
          var sortedCategories = groupedMenu.keys.toList()..sort();

          return ListView.builder(
            // ExpansionTile'lar için ListView.builder daha uygun
            padding: const EdgeInsets.fromLTRB(
              8.0,
              8.0,
              8.0,
              80.0,
            ), // FAB için altta boşluk
            itemCount: sortedCategories.length,
            itemBuilder: (context, categoryIndex) {
              String category = sortedCategories[categoryIndex];
              List<MenuItemModel> itemsInCategory = groupedMenu[category]!;
              return Card(
                // Her kategori için bir Card
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: ExpansionTile(
                  key: PageStorageKey<String>(category),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.3), // Açıkken arka plan
                  collapsedBackgroundColor: Theme.of(context).cardColor,
                  iconColor: primaryColor,
                  collapsedIconColor: primaryColor,
                  title: Text(
                    category,
                    style: GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  initiallyExpanded:
                      categoryIndex == 0, // İlk kategori açık gelsin
                  childrenPadding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                  ).copyWith(bottom: 8.0),
                  children:
                      itemsInCategory.map((item) {
                        return Card(
                          // Her ürün için de bir Card
                          elevation: 1.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            leading: Icon(
                              Icons.local_dining_outlined,
                              color: accentColor,
                            ),
                            title: Text(
                              item.name,
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              '${item.price.toStringAsFixed(2)} TL',
                              style: GoogleFonts.lato(color: Colors.black54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_note_outlined,
                                    color: Colors.blueGrey.shade600,
                                  ),
                                  tooltip: 'Düzenle',
                                  onPressed:
                                      () => _showItemDialog(itemToEdit: item),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_sweep_outlined,
                                    color: Colors.red.shade600,
                                  ),
                                  tooltip: 'Sil',
                                  onPressed:
                                      () => _showDeleteMenuItemConfirmDialog(
                                        item,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Daha açıklayıcı FAB
        onPressed:
            () => _showItemDialog(), // itemToEdit null ise ekleme modunda açar
        tooltip: 'Yeni Menü Ürünü Ekle',
        // backgroundColor temadan gelecek
        icon: const Icon(Icons.add_outlined), // Daha stilize ikon
        label: Text(
          "Ekle",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // _showDeleteMenuItemConfirmDialog fonksiyonu bir önceki mesajdakiyle aynı
  // Buraya tekrar ekliyorum, eksiksiz olması için:
  void _showDeleteMenuItemConfirmDialog(MenuItemModel itemToDelete) {
    final service = Provider.of<WebSocketService>(context, listen: false);
    service.clearMenuManagementMessage();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Text('Menü Ürünü Silme Onayı'),
          content: Text(
            "'${itemToDelete.name}' adlı ürünü silmek istediğinizden emin misiniz? Bu işlem geri alınamaz ve ürün siparişlerde kullanılıyorsa silinemeyebilir.",
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'İptal',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil', style: TextStyle(color: Colors.white)),
              onPressed: () {
                service.sendMessage(
                  jsonEncode({
                    'type': 'delete_menu_item',
                    'payload': {'item_id': itemToDelete.id},
                  }),
                );
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
