import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class QueueService {
  static String get baseUrl => AuthService.baseUrl;

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
      final message = decoded is Map
          ? decoded['error'] ?? decoded['message']
          : null;
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

  /// Returns the queue assigned to the authenticated Staff member.
  static Future<List<Map<String, dynamic>>> getStaffQueue() async {
    final response =
        await _sendStaffRequest('GET', _staffUri('/staff/queue/list'));
    return _normalizeStaffQueue(_staffListFromResponse(response));
  }

  static Future<List<Map<String, dynamic>>> searchStaffQueue(String query) async {
    final uri = _staffUri('/staff/queue/search')
        .replace(queryParameters: {'q': query});
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

  // Local state storage for offline/fallback operation & extra queue actions
  static final List<Map<String, dynamic>> _mockQueue = [
    {
      'id': 101,
      'queue_number': 'G-018',
      'raw_number': 18,
      'patient_name': 'Saman Kumara',
      'patient_nic': '851234567V',
      'patient_phone': '0771234567',
      'room': 'GENERAL_OPD',
      'status': 'COMPLETED',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '09:00 AM',
      'notes': 'Routine checkup',
    },
    {
      'id': 102,
      'queue_number': 'G-019',
      'raw_number': 19,
      'patient_name': 'Nimal Perera',
      'patient_nic': '901234567V',
      'patient_phone': '0719876543',
      'room': 'GENERAL_OPD',
      'status': 'IN_PROGRESS',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '09:15 AM',
      'notes': 'Fever and cold symptoms',
    },
    {
      'id': 103,
      'queue_number': 'G-020',
      'raw_number': 20,
      'patient_name': 'Kasun Silva',
      'patient_nic': '923456789V',
      'patient_phone': '0754443322',
      'room': 'GENERAL_OPD',
      'status': 'CHECKED_IN',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '09:30 AM',
      'notes': 'Headache',
    },
    {
      'id': 104,
      'queue_number': 'G-021',
      'raw_number': 21,
      'patient_name': 'Anu Perera',
      'patient_nic': '685432109V',
      'patient_phone': '0721112233',
      'room': 'GENERAL_OPD',
      'status': 'CHECKED_IN',
      'priority': true,
      'priority_category': 'Elderly',
      'appointment_date': '2026-09-13',
      'appointment_time': '09:45 AM',
      'notes': 'Elderly patient with high BP',
    },
    {
      'id': 105,
      'queue_number': 'G-022',
      'raw_number': 22,
      'patient_name': 'Kamal Fernando',
      'patient_nic': '951112233V',
      'patient_phone': '0783332211',
      'room': 'GENERAL_OPD',
      'status': 'PENDING',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '10:00 AM',
      'notes': 'Stomach ache',
    },
    {
      'id': 201,
      'queue_number': 'D-001',
      'raw_number': 1,
      'patient_name': 'Sunil Jayasinghe',
      'patient_nic': '771234567V',
      'patient_phone': '0772223344',
      'room': 'DRESSING_ROOM',
      'status': 'IN_PROGRESS',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '08:30 AM',
      'notes': 'Surgical wound dressing',
    },
    {
      'id': 202,
      'queue_number': 'D-002',
      'raw_number': 2,
      'patient_name': 'Malkanthi De Silva',
      'patient_nic': '812345678V',
      'patient_phone': '0715556677',
      'room': 'DRESSING_ROOM',
      'status': 'CHECKED_IN',
      'priority': true,
      'priority_category': 'Emergency',
      'appointment_date': '2026-09-13',
      'appointment_time': '08:45 AM',
      'notes': 'Acute burn wound',
    },
    {
      'id': 203,
      'queue_number': 'D-003',
      'raw_number': 3,
      'patient_name': 'Chathura Bandara',
      'patient_nic': '961234567V',
      'patient_phone': '0768889900',
      'room': 'DRESSING_ROOM',
      'status': 'CHECKED_IN',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '09:00 AM',
      'notes': 'Minor abrasion',
    },
    {
      'id': 301,
      'queue_number': 'I-001',
      'raw_number': 1,
      'patient_name': 'Dilini Wickramasinghe',
      'patient_nic': '945554433V',
      'patient_phone': '0776665544',
      'room': 'INJECTION_ROOM',
      'status': 'CHECKED_IN',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '09:15 AM',
      'notes': 'Tetanus toxoid booster',
    },
    {
      'id': 401,
      'queue_number': 'A-001',
      'raw_number': 1,
      'patient_name': 'Ruwan Gunawardena',
      'patient_nic': '883332211V',
      'patient_phone': '0712223344',
      'room': 'ANIMAL_BITE_ROOM',
      'status': 'CHECKED_IN',
      'priority': true,
      'priority_category': 'Emergency',
      'appointment_date': '2026-09-13',
      'appointment_time': '09:30 AM',
      'notes': 'Stray dog bite on leg - ARV Dose 1',
    },
    {
      'id': 501,
      'queue_number': 'B-001',
      'raw_number': 1,
      'patient_name': 'Priyantha Ranasinghe',
      'patient_nic': '741112233V',
      'patient_phone': '0701112233',
      'room': 'BLEEDING_ROOM',
      'status': 'CHECKED_IN',
      'priority': true,
      'priority_category': 'Emergency',
      'appointment_date': '2026-09-13',
      'appointment_time': '09:00 AM',
      'notes': 'Venous blood sampling',
    },
    {
      'id': 601,
      'queue_number': 'P-001',
      'raw_number': 1,
      'patient_name': 'Kavindi Weerasinghe',
      'patient_nic': '987654321V',
      'patient_phone': '0779998877',
      'room': 'PHARMACY',
      'status': 'CHECKED_IN',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '09:45 AM',
      'notes': 'Prescription collection',
    },
  ];

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
      final res = await http.get(Uri.parse('$baseUrl/appointments/queue/$room'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] != null && body['data']['appointments'] != null) {
          final list = List<Map<String, dynamic>>.from(body['data']['appointments']);
          if (list.isNotEmpty) {
            _syncLocalWithRemote(room, list);
            return list;
          }
        }
      }
    } catch (_) {}

    // Fallback to local state filtered by room
    final roomItems = _mockQueue.where((item) => item['room'] == room).toList();
    _sortQueueList(roomItems);
    return roomItems;
  }

  static void _sortQueueList(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      // In progress comes first
      if (a['status'] == 'IN_PROGRESS' && b['status'] != 'IN_PROGRESS') return -1;
      if (b['status'] == 'IN_PROGRESS' && a['status'] != 'IN_PROGRESS') return 1;

      // Priority comes next among checked in / waiting
      final aPriority = (a['priority'] as bool?) ?? false;
      final bPriority = (b['priority'] as bool?) ?? false;
      if (aPriority && !bPriority) return -1;
      if (bPriority && !aPriority) return 1;

      // Then by raw queue number or ID
      final aNum = (a['raw_number'] as int?) ?? (a['id'] as int? ?? 0);
      final bNum = (b['raw_number'] as int?) ?? (b['id'] as int? ?? 0);
      return aNum.compareTo(bNum);
    });
  }

  static void _syncLocalWithRemote(String room, List<Map<String, dynamic>> remoteList) {
    for (var remote in remoteList) {
      final idx = _mockQueue.indexWhere((m) => m['id'] == remote['id']);
      if (idx >= 0) {
        _mockQueue[idx] = {..._mockQueue[idx], ...remote};
      } else {
        _mockQueue.add(remote);
      }
    }
  }

  /// Update patient status to CHECKED_IN and return check-in metadata (token, wait time, patients before)
  static Future<Map<String, dynamic>> checkInPatientWithDetails(int id) async {
    final success = await checkInPatient(id);
    final appt = await getAppointmentById(id);

    final room = appt?['room'] as String? ?? 'GENERAL_OPD';
    final roomQueue = await getQueueByRoom(room);
    final waitingBefore = roomQueue.where((a) => a['status'] == 'CHECKED_IN' && a['id'] != id).length;
    final estimatedTime = (waitingBefore + 1) * 5; // ~5 mins per patient

    return {
      'success': success,
      'appointment': appt,
      'token': appt?['queue_number'] ?? 'G-001',
      'waiting_before': waitingBefore,
      'estimated_wait_minutes': estimatedTime > 0 ? estimatedTime : 10,
    };
  }

  /// Update patient status to CHECKED_IN
  static Future<bool> checkInPatient(int id) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/appointments/$id/checkin'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        _updateLocalStatus(id, 'CHECKED_IN');
        return true;
      }
    } catch (_) {}

    _updateLocalStatus(id, 'CHECKED_IN');
    return true;
  }

  /// Call next patient: set currentId status to COMPLETED and nextId status to IN_PROGRESS
  static Future<bool> callNextPatient(int currentId, int nextId) async {
    bool remoteOk = false;
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
      remoteOk = true;
    } catch (_) {}

    if (currentId > 0) {
      _updateLocalStatus(currentId, 'COMPLETED');
    }

    if (nextId > 0) {
      _updateLocalStatus(nextId, 'IN_PROGRESS');
    }

    return remoteOk || true;
  }

  /// Skip patient with reason and optional notes
  static Future<bool> skipPatient(int id, {required String reason, String? notes}) async {
    _updateLocalStatus(id, 'SKIPPED');
    final idx = _mockQueue.indexWhere((item) => item['id'] == id);
    if (idx >= 0) {
      _mockQueue[idx]['skip_reason'] = reason;
      if (notes != null && notes.isNotEmpty) {
        _mockQueue[idx]['skip_notes'] = notes;
      }
    }
    return true;
  }

  /// Recall a skipped or completed patient back into the active queue
  static Future<bool> recallPatient(int id) async {
    _updateLocalStatus(id, 'CHECKED_IN');
    return true;
  }

  /// Mark or unmark a patient as Priority with a priority category
  static Future<bool> markPriority(int id, {required String category, required bool isPriority}) async {
    final idx = _mockQueue.indexWhere((item) => item['id'] == id);
    if (idx >= 0) {
      _mockQueue[idx]['priority'] = isPriority;
      _mockQueue[idx]['priority_category'] = isPriority ? category : null;
      return true;
    }
    return false;
  }

  /// Gets real queue activity history for the authenticated Staff member.
  static Future<List<Map<String, dynamic>>> getQueueHistory({String? filterTime, String? roomKey}) async {
    final uri = _staffUri('/staff/queue/history').replace(
      queryParameters: {
        'filter_time': filterTime ?? 'Today',
        'room': roomKey ?? 'ALL',
      },
    );
    final response = await _sendStaffRequest('GET', uri);
    return _staffListFromResponse(response, keys: const ['history', 'items']);
  }

  /// Real-time stream listener for appointment status changes by room
  static Stream<List<Map<String, dynamic>>> getQueueStream(String room) async* {
    while (true) {
      final list = await getQueueByRoom(room);
      yield list;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Get appointment details by ID
  static Future<Map<String, dynamic>?> getAppointmentById(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/appointments/view/$id'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null) {
          final prefix = getTokenPrefix(data['room'] ?? 'GENERAL_OPD');
          if (!(data['queue_number'] ?? '').toString().startsWith(prefix)) {
            data['queue_number'] = '$prefix${data['queue_number'] ?? id}';
          }
          return data;
        }
      }
    } catch (_) {}

    final localMatch = _mockQueue.firstWhere((item) => item['id'] == id, orElse: () => <String, dynamic>{});
    if (localMatch.isNotEmpty) {
      return localMatch;
    }

    // Fallback template for testing
    final prefix = getTokenPrefix('GENERAL_OPD');
    return {
      'id': id,
      'queue_number': '$prefix$id',
      'patient_name': 'Patient #$id',
      'patient_nic': '9100000${id % 10}V',
      'patient_phone': '07700000$id',
      'room': 'GENERAL_OPD',
      'status': 'PENDING',
      'priority': false,
      'priority_category': null,
      'appointment_date': '2026-09-13',
      'appointment_time': '10:00 AM',
      'notes': 'OPD Appointment',
    };
  }

  // Internal helpers
  static void _updateLocalStatus(int id, String status) {
    final idx = _mockQueue.indexWhere((item) => item['id'] == id);
    if (idx >= 0) {
      _mockQueue[idx]['status'] = status;
    }
  }

}
