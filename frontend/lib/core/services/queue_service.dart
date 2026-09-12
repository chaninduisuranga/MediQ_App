import 'package:supabase_flutter/supabase_flutter.dart';

class QueueService {
  static SupabaseClient get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // In case Supabase.instance is accessed without initialization
      throw Exception('Supabase client is not initialized');
    }
  }

  /// Get queue list for a specific room sorted by queue number
  static Future<List<Map<String, dynamic>>> getQueueByRoom(String room) async {
    try {
      final response = await _client
          .from('opd_appointments')
          .select()
          .eq('room', room)
          .neq('status', 'CANCELLED')
          .order('queue_number', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Update patient status to CHECKED_IN
  static Future<bool> checkInPatient(int id) async {
    try {
      await _client
          .from('opd_appointments')
          .update({
            'status': 'CHECKED_IN',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Call next patient: set currentId status to COMPLETED and nextId status to IN_PROGRESS
  static Future<bool> callNextPatient(int currentId, int nextId) async {
    try {
      if (currentId > 0) {
        await _client
            .from('opd_appointments')
            .update({
              'status': 'COMPLETED',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', currentId);
      }
      if (nextId > 0) {
        await _client
            .from('opd_appointments')
            .update({
              'status': 'IN_PROGRESS',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', nextId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Real-time stream listener for appointment status changes by room
  static Stream<List<Map<String, dynamic>>> getQueueStream(String room) {
    try {
      return _client
          .from('opd_appointments')
          .stream(primaryKey: ['id'])
          .eq('room', room)
          .order('queue_number', ascending: true);
    } catch (e) {
      return Stream.value([]);
    }
  }

  /// Get appointment details by ID
  static Future<Map<String, dynamic>?> getAppointmentById(int id) async {
    try {
      final response = await _client
          .from('opd_appointments')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }
}
