import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'auth_service.dart';

/// Service for all Doctor-specific API calls.
/// Follows the same pattern as [QueueService] and [AppointmentService]:
/// tries the backend first; falls back to local mock data on failure.
class DoctorService {
  static String get baseUrl => AuthService.baseUrl;

  // ─────────────────────────────────────────────────────────────────────
  // Mock Data (fallback when backend is unavailable)
  // ─────────────────────────────────────────────────────────────────────

  static final List<Map<String, dynamic>> _mockTodayAppointments = [
    {
      'id': 1001,
      'queue_number': 'G-001',
      'raw_number': 1,
      'patient_name': 'Saman Kumara',
      'patient_id': 'PAT-2201',
      'patient_nic': '851234567V',
      'patient_phone': '0771234567',
      'patient_age': 40,
      'patient_gender': 'Male',
      'appointment_time': '09:00 AM',
      'appointment_date': '2026-09-14',
      'room': 'GENERAL_OPD',
      'appointment_status': 'COMPLETED',
      'queue_status': 'COMPLETED',
      'notes': 'Routine annual checkup',
      'blood_group': 'B+',
      'allergies': 'None',
      'medical_conditions': 'Hypertension',
    },
    {
      'id': 1002,
      'queue_number': 'G-002',
      'raw_number': 2,
      'patient_name': 'Nimal Perera',
      'patient_id': 'PAT-3350',
      'patient_nic': '901234567V',
      'patient_phone': '0719876543',
      'patient_age': 35,
      'patient_gender': 'Male',
      'appointment_time': '09:15 AM',
      'appointment_date': '2026-09-14',
      'room': 'GENERAL_OPD',
      'appointment_status': 'IN_CONSULTATION',
      'queue_status': 'IN_PROGRESS',
      'notes': 'Fever and cold symptoms',
      'blood_group': 'O+',
      'allergies': 'Penicillin',
      'medical_conditions': 'None',
    },
    {
      'id': 1003,
      'queue_number': 'G-003',
      'raw_number': 3,
      'patient_name': 'Kasun Silva',
      'patient_id': 'PAT-4411',
      'patient_nic': '923456789V',
      'patient_phone': '0754443322',
      'patient_age': 28,
      'patient_gender': 'Male',
      'appointment_time': '09:30 AM',
      'appointment_date': '2026-09-14',
      'room': 'GENERAL_OPD',
      'appointment_status': 'WAITING',
      'queue_status': 'CHECKED_IN',
      'notes': 'Persistent headache for 3 days',
      'blood_group': 'A+',
      'allergies': 'None',
      'medical_conditions': 'None',
    },
    {
      'id': 1004,
      'queue_number': 'G-004',
      'raw_number': 4,
      'patient_name': 'Anu Perera',
      'patient_id': 'PAT-5520',
      'patient_nic': '685432109V',
      'patient_phone': '0721112233',
      'patient_age': 63,
      'patient_gender': 'Female',
      'appointment_time': '09:45 AM',
      'appointment_date': '2026-09-14',
      'room': 'GENERAL_OPD',
      'appointment_status': 'WAITING',
      'queue_status': 'CHECKED_IN',
      'notes': 'Elderly patient — high BP follow-up',
      'blood_group': 'AB-',
      'allergies': 'Aspirin',
      'medical_conditions': 'Hypertension, Diabetes',
    },
    {
      'id': 1005,
      'queue_number': 'G-005',
      'raw_number': 5,
      'patient_name': 'Kamal Fernando',
      'patient_id': 'PAT-6630',
      'patient_nic': '951112233V',
      'patient_phone': '0783332211',
      'patient_age': 31,
      'patient_gender': 'Male',
      'appointment_time': '10:00 AM',
      'appointment_date': '2026-09-14',
      'room': 'GENERAL_OPD',
      'appointment_status': 'SCHEDULED',
      'queue_status': 'PENDING',
      'notes': 'Stomach ache and nausea',
      'blood_group': 'O-',
      'allergies': 'None',
      'medical_conditions': 'None',
    },
  ];

  static final List<Map<String, dynamic>> _mockPreviousAppointments = [
    {
      'id': 901,
      'queue_number': 'G-044',
      'patient_name': 'Dilini Wickramasinghe',
      'patient_id': 'PAT-1180',
      'patient_nic': '945554433V',
      'appointment_time': '10:00 AM',
      'appointment_date': '2026-09-13',
      'consultation_status': 'COMPLETED',
      'notes': 'Cold and flu — prescribed paracetamol',
    },
    {
      'id': 902,
      'queue_number': 'G-045',
      'patient_name': 'Ruwan Gunawardena',
      'patient_id': 'PAT-2290',
      'patient_nic': '883332211V',
      'appointment_time': '11:00 AM',
      'appointment_date': '2026-09-13',
      'consultation_status': 'COMPLETED',
      'notes': 'BP monitoring — medication adjusted',
    },
    {
      'id': 903,
      'queue_number': 'G-011',
      'patient_name': 'Priyantha Ranasinghe',
      'patient_id': 'PAT-3310',
      'patient_nic': '741112233V',
      'appointment_time': '09:00 AM',
      'appointment_date': '2026-09-12',
      'consultation_status': 'NO_SHOW',
      'notes': 'Patient did not attend',
    },
  ];

  static final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': 1,
      'type': 'NEW_APPOINTMENT',
      'title': 'New Appointment Booked',
      'message':
          'Patient Kamal Fernando has booked an appointment for today 10:00 AM (Queue G-005).',
      'timestamp': '2026-09-14T08:45:00',
      'is_read': false,
      'icon': 'calendar',
    },
    {
      'id': 2,
      'type': 'APPOINTMENT_CANCELLED',
      'title': 'Appointment Cancelled',
      'message':
          'Patient Sunil Jayasinghe has cancelled their 11:30 AM appointment.',
      'timestamp': '2026-09-14T08:20:00',
      'is_read': false,
      'icon': 'cancel',
    },
    {
      'id': 3,
      'type': 'QUEUE_UPDATE',
      'title': 'Queue Update',
      'message':
          'Patient Anu Perera (G-004) has checked in and is now waiting.',
      'timestamp': '2026-09-14T09:30:00',
      'is_read': true,
      'icon': 'queue',
    },
    {
      'id': 4,
      'type': 'ADMIN_ANNOUNCEMENT',
      'title': 'Admin Announcement',
      'message':
          'OPD session extended by 1 hour today. Please accommodate all waiting patients.',
      'timestamp': '2026-09-14T07:00:00',
      'is_read': true,
      'icon': 'announcement',
    },
  ];

  static final Map<String, dynamic> _mockAvailability = {
    'is_available': true,
    'working_days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    'working_hours_start': '08:00 AM',
    'working_hours_end': '04:00 PM',
    'clinic': 'General OPD — Room 03',
    'session_type': 'Morning Session',
    'max_patients_per_day': 40,
    'current_session_date': '2026-09-14',
  };

  // ─────────────────────────────────────────────────────────────────────
  // Today's Appointments
  // ─────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTodayAppointments() async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/doctor/queue/today'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;
          final queueList = data['queue'] as List? ?? [];
          // Normalize field names to match UI expectations
          return queueList.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            // Map backend status to UI-expected status names
            final rawStatus = (m['status'] as String? ?? 'PENDING').toUpperCase();
            m['appointment_status'] = rawStatus;
            m['queue_status'] = _mapToQueueStatus(rawStatus);
            // queue_number displayed as formatted token
            m['queue_number'] = m['queue_token'] ?? '#${m['queue_number']}';
            m['raw_number'] = m['queue_number'];
            // time fields
            m['appointment_time'] = m['appointment_time'] ?? '--';
            m['appointment_date'] = m['appointment_date'] ?? '';
            return m;
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('DoctorService.getTodayAppointments error: $e');
    }
    return List<Map<String, dynamic>>.from(_mockTodayAppointments);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Previous Appointments
  // ─────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPreviousAppointments({
    String? filterStatus,
    String? filterDate,
  }) async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/doctor/appointments/history'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return List<Map<String, dynamic>>.from(body['data'] as List);
        }
      }
    } catch (e) {
      debugPrint('DoctorService.getPreviousAppointments fallback: $e');
    }
    var list = List<Map<String, dynamic>>.from(_mockPreviousAppointments);
    if (filterStatus != null &&
        filterStatus.isNotEmpty &&
        filterStatus != 'ALL') {
      list =
          list.where((a) => a['consultation_status'] == filterStatus).toList();
    }
    return list;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Update Appointment / Queue Status
  // ─────────────────────────────────────────────────────────────────────

  static Future<bool> updateAppointmentStatus(int id, String status) async {
    try {
      final token = AuthService.token;
      // Map UI status to backend status
      final backendStatus = _mapToBackendStatus(status);
      final response = await http.patch(
        Uri.parse('$baseUrl/doctor/queue/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': backendStatus}),
      );
      if (response.statusCode == 200) return true;
    } catch (e) {
      debugPrint('DoctorService.updateAppointmentStatus error: $e');
    }
    // Update local mock data as fallback
    final idx = _mockTodayAppointments.indexWhere((a) => a['id'] == id);
    if (idx >= 0) {
      _mockTodayAppointments[idx]['appointment_status'] = status;
      _mockTodayAppointments[idx]['queue_status'] = _mapToQueueStatus(status);
    }
    return true;
  }

  static String _mapToBackendStatus(String uiStatus) {
    switch (uiStatus.toUpperCase()) {
      case 'IN_CONSULTATION':
      case 'IN_PROGRESS':
        return 'SERVING';
      case 'COMPLETED':
        return 'COMPLETED';
      case 'NO_SHOW':
        return 'NO_SHOW';
      case 'CANCELLED':
        return 'CANCELLED';
      case 'WAITING':
      case 'CHECKED_IN':
      case 'PENDING':
        return 'PENDING';
      default:
        return uiStatus.toUpperCase();
    }
  }

  static String _mapToQueueStatus(String appointmentStatus) {
    switch (appointmentStatus) {
      case 'IN_CONSULTATION':
        return 'IN_PROGRESS';
      case 'COMPLETED':
        return 'COMPLETED';
      case 'NO_SHOW':
        return 'NO_SHOW';
      case 'CANCELLED':
        return 'CANCELLED';
      default:
        return 'CHECKED_IN';
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Availability
  // ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAvailability() async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/doctor/availability'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      debugPrint('DoctorService.getAvailability fallback: $e');
    }
    return Map<String, dynamic>.from(_mockAvailability);
  }

  static Future<bool> updateAvailability(bool isAvailable) async {
    try {
      final token = AuthService.token;
      final response = await http.put(
        Uri.parse('$baseUrl/doctor/availability'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'is_available': isAvailable}),
      );
      if (response.statusCode == 200) return true;
    } catch (e) {
      debugPrint('DoctorService.updateAvailability fallback: $e');
    }
    _mockAvailability['is_available'] = isAvailable;
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Notifications
  // ─────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/doctor/notifications'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return List<Map<String, dynamic>>.from(body['data'] as List);
        }
      }
    } catch (e) {
      debugPrint('DoctorService.getNotifications fallback: $e');
    }
    return List<Map<String, dynamic>>.from(_mockNotifications);
  }

  static Future<bool> markNotificationRead(int id) async {
    final idx = _mockNotifications.indexWhere((n) => n['id'] == id);
    if (idx >= 0) _mockNotifications[idx]['is_read'] = true;
    try {
      final token = AuthService.token;
      await http.put(
        Uri.parse('$baseUrl/doctor/notifications/$id/read'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Dashboard Stats (derived from today's appointments)
  // ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboardStats() async {
    final appointments = await getTodayAppointments();
    final waiting = appointments
        .where((a) =>
            a['queue_status'] == 'CHECKED_IN' ||
            a['appointment_status'] == 'WAITING')
        .length;
    final inConsultation = appointments
        .where((a) =>
            a['appointment_status'] == 'IN_CONSULTATION' ||
            a['queue_status'] == 'IN_PROGRESS')
        .length;
    final completed = appointments
        .where((a) => a['appointment_status'] == 'COMPLETED')
        .length;

    final currentPatient = appointments.firstWhere(
      (a) =>
          a['appointment_status'] == 'IN_CONSULTATION' ||
          a['queue_status'] == 'IN_PROGRESS',
      orElse: () => <String, dynamic>{},
    );

    final nextPatient = appointments.firstWhere(
      (a) =>
          a['queue_status'] == 'CHECKED_IN' ||
          a['appointment_status'] == 'WAITING',
      orElse: () => <String, dynamic>{},
    );

    final availability = await getAvailability();

    return {
      'total_today': appointments.length,
      'waiting': waiting,
      'in_consultation': inConsultation,
      'completed': completed,
      'current_queue_number': currentPatient.isNotEmpty
          ? currentPatient['queue_number'] ?? '--'
          : '--',
      'current_patient_name': currentPatient.isNotEmpty
          ? currentPatient['patient_name'] ?? '--'
          : '--',
      'next_patient_name':
          nextPatient.isNotEmpty ? nextPatient['patient_name'] ?? '--' : '--',
      'next_queue_number':
          nextPatient.isNotEmpty ? nextPatient['queue_number'] ?? '--' : '--',
      'is_available': availability['is_available'] ?? true,
      'clinic': availability['clinic'] ?? 'General OPD',
    };
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────

  static int getUnreadNotificationCount(
      List<Map<String, dynamic>> notifications) {
    return notifications.where((n) => n['is_read'] == false).length;
  }

  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF10B981); // green
      case 'IN_CONSULTATION':
      case 'IN_PROGRESS':
        return const Color(0xFF0284C7); // sky blue
      case 'WAITING':
      case 'CHECKED_IN':
        return const Color(0xFFF59E0B); // amber
      case 'CALLED':
        return const Color(0xFF8B5CF6); // purple
      case 'SCHEDULED':
      case 'PENDING':
        return const Color(0xFF64748B); // muted
      case 'CANCELLED':
      case 'NO_SHOW':
      case 'SKIPPED':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFF64748B);
    }
  }

  static String getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Completed';
      case 'IN_CONSULTATION':
      case 'IN_PROGRESS':
        return 'In Consultation';
      case 'WAITING':
      case 'CHECKED_IN':
        return 'Waiting';
      case 'CALLED':
        return 'Called';
      case 'SCHEDULED':
      case 'PENDING':
        return 'Scheduled';
      case 'CANCELLED':
        return 'Cancelled';
      case 'NO_SHOW':
        return 'No Show';
      case 'SKIPPED':
        return 'Skipped';
      default:
        return status;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Consultation Details (real DB fetch for Doctor Consultation Screen)
  // ─────────────────────────────────────────────────────────────────────

  /// Fetches the real appointment details (time, date, notes) from
  /// [opd_appointments] and the patient's medical profile (blood_group,
  /// allergies, medical_conditions, address) from [users] for the given
  /// [appointmentId].
  ///
  /// Returns a map with keys:
  ///   'time', 'date', 'notes',
  ///   'blood_group', 'allergies', 'medical_conditions', 'address'
  ///
  /// Any NULL / empty DB value is replaced with 'Not provided'.
  static Future<Map<String, String>> getConsultationDetails(
      int appointmentId) async {
    const notProvided = 'Not provided';

    // Defaults — shown if anything fails
    final defaults = <String, String>{
      'time': notProvided,
      'date': notProvided,
      'notes': notProvided,
      'blood_group': notProvided,
      'allergies': notProvided,
      'medical_conditions': notProvided,
      'address': notProvided,
    };

    if (appointmentId <= 0) return defaults;

    Connection? conn;
    try {
      conn = await Connection.open(
        Endpoint(
          host: 'aws-0-ap-south-1.pooler.supabase.com',
          database: 'postgres',
          username: 'postgres.dvanmlqqgvbltdvwamuk',
          password: '3141531415supabase',
          port: 5432,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.require),
      );

      // ── Step 1: fetch appointment row ──────────────────────────────
      final apptRes = await conn.execute(
        Sql.named(
          'SELECT "time", date, notes, patient_id '
          'FROM opd_appointments '
          'WHERE id = @id '
          'LIMIT 1',
        ),
        parameters: {'id': appointmentId},
      );

      int? patientId;
      String time = notProvided;
      String date = notProvided;
      String notes = notProvided;

      if (apptRes.isNotEmpty) {
        final row = apptRes.first;

        final rawTime = row[0];
        final rawDate = row[1];
        final rawNotes = row[2];
        patientId = row[3] as int?;

        time = (rawTime != null && rawTime.toString().trim().isNotEmpty)
            ? rawTime.toString().trim()
            : notProvided;
        date = (rawDate != null && rawDate.toString().trim().isNotEmpty)
            ? rawDate.toString().trim()
            : notProvided;
        notes = (rawNotes != null && rawNotes.toString().trim().isNotEmpty)
            ? rawNotes.toString().trim()
            : notProvided;
      }

      // ── Step 2: fetch patient row ──────────────────────────────────
      String bloodGroup = notProvided;
      String allergies = notProvided;
      String medicalConditions = notProvided;
      String address = notProvided;

      if (patientId != null) {
        // Try with medical_conditions column first; fall back if it
        // doesn't exist in this DB schema.
        late Result userRes;
        bool hasMedicalConditions = true;
        try {
          userRes = await conn.execute(
            Sql.named(
              'SELECT blood_group, allergies, medical_conditions, address '
              'FROM users '
              'WHERE id = @id '
              'LIMIT 1',
            ),
            parameters: {'id': patientId},
          );
        } catch (_) {
          hasMedicalConditions = false;
          userRes = await conn.execute(
            Sql.named(
              'SELECT blood_group, allergies, address '
              'FROM users '
              'WHERE id = @id '
              'LIMIT 1',
            ),
            parameters: {'id': patientId},
          );
        }

        if (userRes.isNotEmpty) {
          final uRow = userRes.first;
          bloodGroup = _val(uRow[0]);
          allergies = _val(uRow[1]);
          if (hasMedicalConditions) {
            medicalConditions = _val(uRow[2]);
            address = _val(uRow[3]);
          } else {
            address = _val(uRow[2]);
          }
        }
      }

      return {
        'time': time,
        'date': date,
        'notes': notes,
        'blood_group': bloodGroup,
        'allergies': allergies,
        'medical_conditions': medicalConditions,
        'address': address,
      };
    } catch (e) {
      debugPrint('DoctorService.getConsultationDetails error: $e');
      return defaults;
    } finally {
      await conn?.close();
    }
  }

  /// Returns the string value or 'Not provided' for null/empty.
  static String _val(dynamic raw) {
    if (raw == null) return 'Not provided';
    final s = raw.toString().trim();
    return s.isEmpty ? 'Not provided' : s;
  }
}
