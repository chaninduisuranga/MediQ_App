import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class QueueService {
  static String get baseUrl => AuthService.baseUrl;

  /// Get queue list for a specific room sorted by queue number
  static Future<List<Map<String, dynamic>>> getQueueByRoom(String room) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/appointments/queue/$room'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] != null && body['data']['appointments'] != null) {
          return List<Map<String, dynamic>>.from(body['data']['appointments']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Update patient status to CHECKED_IN
  static Future<bool> checkInPatient(int id) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/appointments/$id/checkin'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Call next patient: set currentId status to COMPLETED and nextId status to IN_PROGRESS
  static Future<bool> callNextPatient(int currentId, int nextId) async {
    try {
      if (currentId > 0) {
        await http.put(
          Uri.parse('$baseUrl/appointments/$currentId/complete'),
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (nextId > 0) {
        await http.put(
          Uri.parse('$baseUrl/appointments/$nextId/call'),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Real-time stream listener for appointment status changes by room
  static Stream<List<Map<String, dynamic>>> getQueueStream(String room) async* {
    while (true) {
      final list = await getQueueByRoom(room);
      yield list;
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Get appointment details by ID
  static Future<Map<String, dynamic>?> getAppointmentById(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/appointments/view/$id'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }
}
