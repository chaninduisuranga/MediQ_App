import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class QueueService {
  static String get baseUrl => AuthService.baseUrl;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthService.token != null)
          'Authorization': 'Bearer ${AuthService.token}',
      };

  static Map<String, String> _staffHeaders({bool hasBody = false}) {
    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      throw StateError('An authenticated Staff session is required.');
    }
    return {
      'Authorization': 'Bearer $token',
      if (hasBody) 'Content-Type': 'application/json',
    };
  }

  static Future<dynamic> _sendStaffRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final headers = _staffHeaders(hasBody: body != null);
    final encodedBody = body == null ? null : jsonEncode(body);
    final http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: encodedBody);
        break;
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      decoded = jsonDecode(response.body);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map ? decoded['error'] ?? decoded['message'] : null;
      throw Exception(
        message?.toString() ??
            'Staff API request failed (${response.statusCode}).',
      );
    }
    if (decoded is Map && decoded['success'] == false) {
      throw Exception(
        (decoded['error'] ?? decoded['message'] ?? 'Staff API request failed.')
            .toString(),
      );
    }
    return decoded;
  }

  static dynamic _staffResponseData(dynamic response) {
    if (response is Map && response.containsKey('data')) {
      return response['data'];
    }
    return response;
  }

  static List<Map<String, dynamic>> _staffListFromResponse(
    dynamic response, {
    List<String> keys = const [
      'queue',
      'queue_list',
      'appointments',
      'patients',
      'doctors',
      'staff_doctors',
      'items',
    ],
  }) {
    dynamic value = _staffResponseData(response);
    if (value is Map) {
      for (final key in keys) {
        if (value[key] is List) {
          value = value[key];
          break;
        }
      }
    }
    if (value is! List) {
      throw const FormatException('Staff API response did not contain a list.');
    }
    return value.map((item) {
      if (item is! Map) {
        throw const FormatException('Staff API list item was not an object.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  static Uri _staffUri(String path) => Uri.parse('$baseUrl$path');

  /// Returns assignment details for the authenticated Staff member.
  static Future<Map<String, dynamic>> getStaffProfile() async {
    final response = await _sendStaffRequest(
      'GET',
      _staffUri('/staff/profile'),
    );
    final data = _staffResponseData(response);
    if (data is! Map) {
      throw const FormatException('Staff profile response was not an object.');
    }
    return Map<String, dynamic>.from(data);
  }

  /// Returns the queue assigned to the authenticated Staff member.
  static Future<List<Map<String, dynamic>>> getStaffQueue() async {
    final response =
        await _sendStaffRequest('GET', _staffUri('/staff/queue/list'));
    return _normalizeStaffQueue(_staffListFromResponse(response));
  }

  static Future<List<Map<String, dynamic>>> searchStaffQueue(
      String query) async {
    final uri =
        _staffUri('/staff/queue/search').replace(queryParameters: {'q': query});
    final response = await _sendStaffRequest('GET', uri);
    return _normalizeStaffQueue(_staffListFromResponse(response));
  }

  static List<Map<String, dynamic>> _normalizeStaffQueue(
    List<Map<String, dynamic>> queue,
  ) {
    return queue.map((patient) {
      final normalized = Map<String, dynamic>.from(patient);
      normalized['priority'] ??= normalized['is_priority'] ?? false;
      return normalized;
    }).toList();
  }

  static Stream<List<Map<String, dynamic>>> getStaffQueueStream() async* {
    while (true) {
      yield await getStaffQueue();
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  static Future<void> checkInStaffPatient(int id) async {
    await _sendStaffRequest(
      'POST',
      _staffUri('/staff/queue/checkin/$id'),
    );
  }

  static Future<void> callStaffPatient(int id) async {
    await _sendStaffRequest('POST', _staffUri('/staff/queue/call/$id'));
  }

  static Future<void> updateStaffPatientStatus(
    int id,
    String status,
  ) async {
    const allowedStatuses = {'COMPLETED', 'SKIPPED', 'NO_SHOW', 'RECALL'};
    if (!allowedStatuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported Staff status');
    }
    await _sendStaffRequest(
      'PATCH',
      _staffUri('/staff/queue/status/$id'),
      body: {'status': status},
    );
  }

  static Future<void> markStaffPatientPriority(
    int id, {
    required bool isPriority,
  }) async {
    await _sendStaffRequest(
      'PATCH',
      _staffUri('/staff/queue/priority/$id'),
      body: {'is_priority': isPriority},
    );
  }

  static Future<List<Map<String, dynamic>>> getStaffDoctors() async {
    final response =
        await _sendStaffRequest('GET', _staffUri('/staff/doctors'));
    return _staffListFromResponse(response);
  }

  static Future<void> allocateStaffPatient(
    int patientId,
    dynamic doctorId,
  ) async {
    await _sendStaffRequest(
      'POST',
      _staffUri('/staff/queue/allocate/$patientId'),
      body: {'doctor_id': doctorId},
    );
  }

  /// Get room prefix letter for tokens
  static String getTokenPrefix(String roomKey) {
    switch (roomKey) {
      case 'GENERAL_OPD':
      case 'OPD_CLINIC_ROOM':
        return 'G-';
      case 'DRESSING_ROOM':
        return 'D-';
      case 'INJECTION_ROOM':
        return 'I-';
      case 'ANIMAL_BITE_ROOM':
        return 'A-';
      case 'BLEEDING_ROOM':
        return 'B-';
      case 'PHARMACY':
        return 'P-';
      default:
        return 'Q-';
    }
  }

  /// Get queue list for a specific room sorted by priority and queue number
  static Future<List<Map<String, dynamic>>> getQueueByRoom(String room) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/queue/$room'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'];
        if (body['success'] == true && data is Map) {
          final appointments = data['appointments'];
          if (appointments is List) {
            final list = List<Map<String, dynamic>>.from(appointments);
            _sortQueueList(list);
            return list;
          }
        }
        debugPrint('QueueService.getQueueByRoom returned an invalid response');
      } else {
        debugPrint(
          'QueueService.getQueueByRoom failed: HTTP ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('QueueService.getQueueByRoom failed: $error');
    }
    return [];
  }

  static bool isQueueEntryActive(Map<String, dynamic> entry) {
    if (entry['active'] == true ||
        entry['is_active'] == true ||
        entry['isActive'] == true) {
      return true;
    }

    const activeStatuses = {
      'ACTIVE',
      'IN_CONSULTATION',
      'IN_PROGRESS',
      'SERVING',
      'CONSULTING',
      'ONGOING',
    };
    return [
      entry['appointment_status'],
      entry['consultation_status'],
      entry['queue_status'],
      entry['status'],
    ].whereType<Object>().any((status) {
      final normalized = status
          .toString()
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[\s-]+'), '_');
      return activeStatuses.contains(normalized);
    });
  }

  static void _sortQueueList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aIsActive = isQueueEntryActive(a);
      final bIsActive = isQueueEntryActive(b);
      if (aIsActive && !bIsActive) {
        return -1;
      }
      if (bIsActive && !aIsActive) {
        return 1;
      }

      final aPriority = (a['priority'] as bool?) ?? false;
      final bPriority = (b['priority'] as bool?) ?? false;
      if (aPriority && !bPriority) return -1;
      if (bPriority && !aPriority) return 1;

      final aNum = (a['raw_number'] as int?) ?? (a['id'] as int? ?? 0);
      final bNum = (b['raw_number'] as int?) ?? (b['id'] as int? ?? 0);
      return aNum.compareTo(bNum);
    });
  }

  /// Update patient status to CHECKED_IN and return check-in metadata.
  static Future<Map<String, dynamic>> checkInPatientWithDetails(int id) async {
    final success = await checkInPatient(id);
    final appointment = success ? await getAppointmentById(id) : null;
    if (appointment == null) {
      return {
        'success': false,
        'appointment': null,
        'token': '',
        'waiting_before': 0,
        'estimated_wait_minutes': 0,
      };
    }

    final room = appointment['room'] as String? ?? 'GENERAL_OPD';
    final roomQueue = await getQueueByRoom(room);
    final waitingBefore = roomQueue
        .where(
            (item) => item['queue_status'] == 'CHECKED_IN' && item['id'] != id)
        .length;
    return {
      'success': true,
      'appointment': appointment,
      'token': appointment['queue_number'] ?? '',
      'waiting_before': waitingBefore,
      'estimated_wait_minutes': (waitingBefore + 1) * 5,
    };
  }

  static Future<bool> checkInPatient(int id) =>
      _putAction('appointments/$id/checkin', 'checkInPatient');

  /// Call next patient: complete the current patient and call the next one.
  static Future<bool> callNextPatient(int currentId, int nextId) async {
    if (currentId > 0 &&
        !await _putAction(
            'appointments/$currentId/complete', 'callNextPatient')) {
      return false;
    }
    if (nextId > 0 &&
        !await _putAction('appointments/$nextId/call', 'callNextPatient')) {
      return false;
    }
    return currentId > 0 || nextId > 0;
  }

  static Future<bool> skipPatient(
    int id, {
    required String reason,
    String? notes,
  }) =>
      _putAction(
        'appointments/$id/skip',
        'skipPatient',
        body: {'reason': reason, if (notes != null) 'notes': notes},
      );

  static Future<bool> recallPatient(int id) =>
      _putAction('appointments/$id/recall', 'recallPatient');

  static Future<bool> markPriority(
    int id, {
    required String category,
    required bool isPriority,
  }) =>
      _putAction(
        'appointments/$id/priority',
        'markPriority',
        body: {'category': category, 'is_priority': isPriority},
      );

  static Future<bool> _putAction(
    String path,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$path'),
        headers: _headers,
        body: body == null ? null : jsonEncode(body),
      );
      if (response.statusCode == 200) return true;
      debugPrint('$action failed: HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('$action failed: $error');
    }
    return false;
  }

  /// Get Queue History filtered by timeframe and optional room key.
  static Future<List<Map<String, dynamic>>> getQueueHistory({
    String? filterTime,
    String? roomKey,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/appointments/queue/history')
          .replace(queryParameters: {
        if (filterTime != null) 'filter_time': filterTime,
        if (roomKey != null) 'room': roomKey,
      });
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'];
        if (body['success'] == true && data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      debugPrint(
        'QueueService.getQueueHistory failed: HTTP ${response.statusCode}',
      );
    } catch (error) {
      debugPrint('QueueService.getQueueHistory failed: $error');
    }
    return [];
  }

  /// Real-time stream listener for appointment status changes by room.
  static Stream<List<Map<String, dynamic>>> getQueueStream(String room) async* {
    while (true) {
      yield await getQueueByRoom(room);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Get appointment details by ID.
  static Future<Map<String, dynamic>?> getAppointmentById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/$id'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'];
        if (body['success'] == true && data is Map<String, dynamic>) {
          return data;
        }
      }
      debugPrint(
        'QueueService.getAppointmentById failed: HTTP ${response.statusCode}',
      );
    } catch (error) {
      debugPrint('QueueService.getAppointmentById failed: $error');
    }
    return null;
  }
}
