import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service for all Doctor-specific API calls.
/// Doctor data is loaded from the authenticated backend.
class DoctorService {
  static String get baseUrl => AuthService.baseUrl;

  static bool isAppointmentInConsultation(Map<String, dynamic> appointment) {
    const consultationStatuses = {
      'IN_CONSULTATION',
      'IN_PROGRESS',
      'SERVING',
      'CONSULTING',
      'ONGOING',
      'ACTIVE',
    };
    return appointment['active'] == true ||
        appointment['is_active'] == true ||
        appointment['isActive'] == true ||
        _appointmentStatuses(appointment).any(consultationStatuses.contains);
  }

  static bool isAppointmentWaiting(Map<String, dynamic> appointment) {
    if (isAppointmentInConsultation(appointment)) return false;

    const waitingStatuses = {
      'WAITING',
      'CHECKED_IN',
      'PENDING',
      'CONFIRMED',
      'SCHEDULED',
      'CALLED',
    };
    return _appointmentStatuses(appointment).any(waitingStatuses.contains);
  }

  static Iterable<String> _appointmentStatuses(
      Map<String, dynamic> appointment) {
    return [
      appointment['appointment_status'],
      appointment['consultation_status'],
      appointment['queue_status'],
      appointment['status'],
    ].whereType<Object>().map(
          (status) => status
              .toString()
              .trim()
              .toUpperCase()
              .replaceAll(RegExp(r'[\s-]+'), '_'),
        );
  }

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
      debugPrint(
        'DoctorService.getTodayAppointments failed: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DoctorService.getTodayAppointments failed: $e');
    }
    return [];
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
        Uri.parse('$baseUrl/doctor/appointments/history').replace(
          queryParameters: {
            if (filterStatus != null && filterStatus.isNotEmpty)
              'status': filterStatus,
            if (filterDate != null && filterDate.isNotEmpty) 'date': filterDate,
          },
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      debugPrint("API Raw Response: ${response.body}");
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return List<Map<String, dynamic>>.from(body['data'] as List);
        }
      }
      debugPrint(
        'DoctorService.getPreviousAppointments failed: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DoctorService.getPreviousAppointments failed: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────
  // Update Appointment / Queue Status
  // ─────────────────────────────────────────────────────────────────────

  static Future<bool> updateAppointmentStatus(
    int id,
    String status, {
    String? notes,
  }) async {
    try {
      final token = AuthService.token;
      final body = <String, dynamic>{'status': status};
      final trimmedNotes = notes?.trim();
      if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
        body['notes'] = trimmedNotes;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/doctor/appointments/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) return true;
      debugPrint(
        'DoctorService.updateAppointmentStatus failed: '
        'HTTP ${response.statusCode}, response: ${response.body}',
      );
    } catch (e) {
      debugPrint('DoctorService.updateAppointmentStatus failed: $e');
    }
    return false;
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
      debugPrint(
        'DoctorService.getAvailability failed: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DoctorService.getAvailability failed: $e');
    }
    return {};
  }

  static Future<bool> updateAvailability({
    required bool isAvailable,
    List<String>? workingDays,
    String? sessionType,
    String? workingHoursStart,
    String? workingHoursEnd,
    int? maxPatientsPerDay,
    String? clinic,
  }) async {
    try {
      final token = AuthService.token;
      final payload = <String, dynamic>{
        'is_available': isAvailable,
        if (workingDays != null) 'working_days': workingDays,
        if (sessionType != null) 'session_type': sessionType,
        if (workingHoursStart != null) 'working_hours_start': workingHoursStart,
        if (workingHoursEnd != null) 'working_hours_end': workingHoursEnd,
        if (maxPatientsPerDay != null)
          'max_patients_per_day': maxPatientsPerDay,
        if (clinic != null) 'clinic': clinic,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/doctor/availability'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) return true;
      debugPrint(
        'DoctorService.updateAvailability failed: HTTP ${response.statusCode}, body: ${response.body}',
      );
    } catch (e) {
      debugPrint('DoctorService.updateAvailability failed: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Profile & Security
  // ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/doctor/profile'),
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
      debugPrint('DoctorService.getProfile failed: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String email,
    required String phone,
    required String department,
    required String room,
  }) async {
    try {
      final token = AuthService.token;
      final response = await http.put(
        Uri.parse('$baseUrl/doctor/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'phone': phone,
          'department': department,
          'room': room,
        }),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'message': body['error'] ?? 'Failed to update profile'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = AuthService.token;
      final response = await http.post(
        Uri.parse('$baseUrl/doctor/change-password'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'message': 'Password changed successfully'};
      }
      return {
        'success': false,
        'message': body['error'] ?? 'Failed to change password'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientHistory(
      int patientId) async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/doctor/patients/$patientId/history'),
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
      debugPrint('DoctorService.getPatientHistory failed: $e');
    }
    return [];
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
      debugPrint(
        'DoctorService.getNotifications failed: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DoctorService.getNotifications failed: $e');
    }
    return [];
  }

  static Future<bool> markNotificationRead(int id) async {
    try {
      final token = AuthService.token;
      final response = await http.put(
        Uri.parse('$baseUrl/doctor/notifications/$id/read'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return true;
      debugPrint(
        'DoctorService.markNotificationRead failed: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DoctorService.markNotificationRead failed: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Dashboard Stats (derived from today's appointments)
  // ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboardStats() async {
    final appointments = await getTodayAppointments();
    final waiting = appointments.where(isAppointmentWaiting).length;
    final inConsultation =
        appointments.where(isAppointmentInConsultation).length;
    final completed = appointments
        .where((a) => a['appointment_status'] == 'COMPLETED')
        .length;

    final currentPatient = appointments.firstWhere(
      isAppointmentInConsultation,
      orElse: () => <String, dynamic>{},
    );

    final nextPatient = appointments.firstWhere(
      isAppointmentWaiting,
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
      'is_available': availability['is_available'] ?? false,
      'clinic': availability['clinic'] ?? 'Not configured',
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
  // Consultation Details
  // ─────────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> getConsultationDetails(
      int appointmentId) async {
    const notProvided = 'Not provided';
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

    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse(
          '$baseUrl/doctor/appointments/$appointmentId/consultation-details',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'];
        if (body['success'] == true && data is Map) {
          return data
              .map(
                (key, value) => MapEntry(
                  key.toString(),
                  value?.toString() ?? notProvided,
                ),
              )
              .cast<String, String>();
        }
      }
      debugPrint(
        'DoctorService.getConsultationDetails failed: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DoctorService.getConsultationDetails failed: $e');
    }
    return defaults;
  }
}
