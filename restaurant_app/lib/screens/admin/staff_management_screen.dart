import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts
import 'package:provider/provider.dart';
import '../../api/websocket_service.dart';
import '../../models/user_model.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRoleDialog = 'waiter';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStaffList();
    });
  }

  void _fetchStaffList() {
    Provider.of<WebSocketService>(
      context,
      listen: false,
    ).sendMessage(jsonEncode({'type': 'get_staff_list'}));
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'waiter':
        return 'Garson';
      case 'kitchen':
        return 'Mutfak Personeli';
      default:
        return role.toUpperCase();
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'waiter':
        return Icons.room_service_rounded; // Daha dolgun ikonlar
      case 'kitchen':
        return Icons.soup_kitchen_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  void _showAddStaffDialog() {
    final service = Provider.of<WebSocketService>(context, listen: false);
    service.clearStaffManagementMessage();
    _usernameController.clear();
    _passwordController.clear();
    _selectedRoleDialog = 'waiter';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              title: Text(
                'Yeni Personel Ekle',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
              ),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kullanıcı adı boş olamaz';
                          }
                          if (value.length < 3) {
                            return 'Kullanıcı adı en az 3 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre boş olamaz';
                          }
                          if (value.length < 6) {
                            return 'Şifre en az 6 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRoleDialog,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'waiter',
                            child: Text('Garson'),
                          ),
                          DropdownMenuItem(
                            value: 'kitchen',
                            child: Text('Mutfak Personeli'),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          setDialogState(() {
                            _selectedRoleDialog = newValue;
                          });
                        },
                        validator:
                            (value) =>
                                value == null ? 'Lütfen bir rol seçin' : null,
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
                  // Temadan stil alacak
                  child: const Text('Ekle'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      service.sendMessage(
                        jsonEncode({
                          'type': 'add_staff',
                          'payload': {
                            'username': _usernameController.text,
                            'password': _passwordController.text,
                            'role': _selectedRoleDialog,
                          },
                        }),
                      );
                      Navigator.of(dialogContext).pop();
                      // Future.delayed(const Duration(milliseconds: 500), _fetchStaffList); // Bu SnackBar mantığına taşındı
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(UserModel staffMember) {
    final service = Provider.of<WebSocketService>(context, listen: false);
    service.clearStaffManagementMessage();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text(
            'Personel Silme Onayı',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          ),
          content: Text(
            "'${staffMember.username}' adlı kullanıcıyı (${_getRoleDisplayName(staffMember.role)}) silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.",
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ), // Temadan farklı, vurgulu kırmızı
              child: const Text('Sil', style: TextStyle(color: Colors.white)),
              onPressed: () {
                service.sendMessage(
                  jsonEncode({
                    'type': 'delete_staff',
                    'payload': {'user_id': staffMember.id},
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Çalışan Yönetimi',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        // backgroundColor ve foregroundColor temadan gelecek
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Listeyi Yenile',
            onPressed: _fetchStaffList,
          ),
        ],
      ),
      body: Consumer<WebSocketService>(
        builder: (context, service, child) {
          if (service.staffManagementMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && ModalRoute.of(context)!.isCurrent) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(service.staffManagementMessage!),
                    backgroundColor:
                        service.staffActionSuccess
                            ? Colors.green
                            : Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    margin: const EdgeInsets.all(10.0),
                  ),
                );
                service.clearStaffManagementMessage();
                if (service.staffActionSuccess) {
                  _fetchStaffList(); // Başarılı işlem sonrası listeyi yenile
                }
              }
            });
          }

          if (service.staffList.isEmpty && service.isConnected) {
            return Center(child: CircularProgressIndicator(color: accentColor));
          } else if (!service.isConnected && service.staffList.isEmpty) {
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
                      "Sunucuya bağlanılamadı veya personel bulunmuyor.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              8.0,
              8.0,
              8.0,
              80.0,
            ), // FAB için altta boşluk
            itemCount: service.staffList.length,
            separatorBuilder:
                (context, index) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final staffMember = service.staffList[index];
              return Card(
                // Her personel için bir Card
                elevation: 1.5,
                margin: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  leading: CircleAvatar(
                    // Rol ikonu için CircleAvatar
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      _getRoleIcon(staffMember.role),
                      size: 24, // Biraz küçülttük
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    staffMember.username,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    _getRoleDisplayName(staffMember.role),
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.red.shade600,
                    ),
                    tooltip: 'Personeli Sil',
                    onPressed: () => _showDeleteConfirmDialog(staffMember),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        tooltip: 'Yeni Personel Ekle',
        icon: const Icon(Icons.add_comment_outlined), // Farklı bir ikon
        label: Text(
          "Yeni Personel",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
        ),
        // backgroundColor temadan gelecek
      ),
    );
  }
}
