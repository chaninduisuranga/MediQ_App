class AdminStaff {
  const AdminStaff({
    required this.id,
    required this.userId,
    required this.name,
    required this.function,
    required this.assignedRoom,
    required this.status,
    required this.isAvailable,
  });

  final int id;
  final int userId;
  final String name;
  final String function;
  final String assignedRoom;
  final String status;
  final bool isAvailable;

  factory AdminStaff.fromJson(Map<String, dynamic> json) => AdminStaff(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        function: json['function'] as String? ?? '',
        assignedRoom: json['assigned_room'] as String? ?? '',
        status: json['status'] as String? ?? 'ACTIVE',
        isAvailable: json['is_available'] as bool? ?? true,
      );
}
