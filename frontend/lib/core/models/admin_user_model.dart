class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.nic,
    required this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String nic;
  final String phone;
  final String role;
  final String status;
  final DateTime? createdAt;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? '',
      nic: json['nic'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'PATIENT',
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
