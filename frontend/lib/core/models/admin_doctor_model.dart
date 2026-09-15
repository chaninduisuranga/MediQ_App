class AdminDoctor {
  const AdminDoctor({
    required this.id,
    required this.userId,
    required this.name,
    required this.specialization,
    required this.slmcNumber,
    required this.clinicName,
    required this.room,
    required this.status,
    required this.isAvailable,
    required this.currentQueue,
  });

  final int id;
  final int userId;
  final String name;
  final String specialization;
  final String slmcNumber;
  final String clinicName;
  final String room;
  final String status;
  final bool isAvailable;
  final int currentQueue;

  factory AdminDoctor.fromJson(Map<String, dynamic> json) => AdminDoctor(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        specialization: json['specialization'] as String? ?? '',
        slmcNumber: json['slmc_number'] as String? ?? '',
        clinicName: json['clinic_name'] as String? ?? '',
        room: json['room'] as String? ?? '',
        status: json['status'] as String? ?? 'ACTIVE',
        isAvailable: json['is_available'] as bool? ?? true,
        currentQueue: (json['current_queue'] as num?)?.toInt() ?? 0,
      );
}
