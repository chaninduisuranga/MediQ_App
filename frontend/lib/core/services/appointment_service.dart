import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AppointmentService {
  static String get baseUrl => AuthService.baseUrl;

  static const List<Map<String, dynamic>> opdRooms = [
    {
      'key': 'GENERAL_OPD',
      'name': 'General OPD',
      'subtitle': 'General Medical OPD Consultation',
      'icon': 'clinic',
      'color': 0xFF0284C7,
    },
    {
      'key': 'DRESSING_ROOM',
      'name': 'Dressing Room',
      'subtitle': 'Wound Care & Bandaging',
      'icon': 'bandage',
      'color': 0xFF0077B6,
    },
    {
      'key': 'INJECTION_ROOM',
      'name': 'Injection Room',
      'subtitle': 'IV & IM Injections',
      'icon': 'syringe',
      'color': 0xFF00A896,
    },
    {
      'key': 'ANIMAL_BITE_ROOM',
      'name': 'Animal Bite Room',
      'subtitle': 'Bite Wounds & ARV Treatment',
      'icon': 'animal',
      'color': 0xFFD97706,
    },
    {
      'key': 'BLEEDING_ROOM',
      'name': 'Bleeding Room',
      'subtitle': 'Hemorrhage & Bleeding Control',
      'icon': 'blood',
      'color': 0xFFE11D48,
    },
    {
      'key': 'PHARMACY',
      'name': 'Pharmacy',
      'subtitle': 'Medication Dispensing & Queue',
      'icon': 'pill',
      'color': 0xFF059669,
    },
    {
      'key': 'OPD_CLINIC_ROOM',
      'name': 'OPD Clinic Room',
      'subtitle': 'Specialized OPD Consultation',
      'icon': 'clinic',
      'color': 0xFF7C3AED,
    },
  ];

  /// Get current queue count for a room on a given date (default today)
  static Future<Map<String, dynamic>> getQueueStatus(String roomKey, {String? date}) async {
    try {
      final query = date != null && date.isNotEmpty ? '?date=$date' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/queue/$roomKey$query'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to get queue'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Book an OPD appointment for a selected date
  static Future<Map<String, dynamic>> bookAppointment({
    required String roomKey,
    String date = '',
    String notes = '',
  }) async {
    try {
      final token = AuthService.token;
      final response = await http.post(
        Uri.parse('$baseUrl/appointments/book'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'room': roomKey,
          'date': date,
          'notes': notes,
        }),
      );
      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        return {'success': true, 'message': data['message'], 'data': data['data']};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to book appointment'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get all appointments for current patient
  static Future<Map<String, dynamic>> getMyAppointments() async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/my'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to get appointments'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Cancel an appointment
  static Future<Map<String, dynamic>> cancelAppointment(int id) async {
    try {
      final token = AuthService.token;
      final response = await http.put(
        Uri.parse('$baseUrl/appointments/$id/cancel'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to cancel'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get room display name from key
  static String getRoomDisplayName(String key) {
    final room = opdRooms.firstWhere(
      (r) => r['key'] == key,
      orElse: () => {'name': key},
    );
    return room['name'] as String;
  }

  /// Get room color from key
  static int getRoomColor(String key) {
    final room = opdRooms.firstWhere(
      (r) => r['key'] == key,
      orElse: () => {'color': 0xFF00A896},
    );
    return room['color'] as int;
  }
}
