class AdminAppointment {
  const AdminAppointment({
    required this.id,
    required this.date,
    required this.time,
    required this.patientName,
    required this.patientNic,
    required this.patientPhone,
    required this.room,
    required this.roomDisplayName,
    required this.queueNumber,
    required this.status,
    required this.notes,
  });

  final int id;
  final String date;
  final String time;
  final String patientName;
  final String patientNic;
  final String patientPhone;
  final String room;
  final String roomDisplayName;
  final int queueNumber;
  final String status;
  final String notes;

  factory AdminAppointment.fromJson(Map<String, dynamic> json) {
    return AdminAppointment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: json['appointment_date'] as String? ?? '',
      time: json['appointment_time'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      patientNic: json['patient_nic'] as String? ?? '',
      patientPhone: json['patient_phone'] as String? ?? '',
      room: json['room'] as String? ?? '',
      roomDisplayName:
          json['room_display_name'] as String? ?? json['room'] as String? ?? '',
      queueNumber: (json['queue_number'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      notes: json['notes'] as String? ?? '',
    );
  }
}
