class UserModel {
  final int id;
  final String username;
  final String role; // 'waiter', 'kitchen', 'admin'

  UserModel({required this.id, required this.username, required this.role});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:
          json['id'] ??
          0, // Sunucudan id gelmezse varsayılan (0 sorunlu olabilir, ID gelmeli)
      username: json['username'] ?? 'Bilinmeyen Kullanıcı',
      role: json['role'] ?? 'rol_yok',
    );
  }
}
