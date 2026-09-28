import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/constants.dart';
import '../models/admin_appointment_model.dart';
import '../models/admin_doctor_model.dart';
import '../models/admin_queue_model.dart';
import '../models/admin_staff_model.dart';
import '../models/admin_user_model.dart';
import 'auth_service.dart';

class AdminService {
  static String get baseUrl => AppConstants.apiBaseUrl;

  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final token = AuthService.token;
      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['error'] ??
              data['message'] ??
              'Failed to load dashboard data.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message':
            'Cannot connect to MediQ backend server. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> getUsers({
    String search = '',
    String role = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = Uri(queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (role.isNotEmpty) 'role': role,
        'page': '$page',
        'limit': '$limit',
      }).query;
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users?$query'),
        headers: {
          'Content-Type': 'application/json',
          if (AuthService.token != null)
            'Authorization': 'Bearer ${AuthService.token}',
        },
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'users': (payload['users'] as List<dynamic>? ?? [])
              .map((user) => AdminUser.fromJson(user as Map<String, dynamic>))
              .toList(),
          'page': payload['page'] ?? page,
          'total_pages': payload['total_pages'] ?? 1,
          'total': payload['total'] ?? 0,
        };
      }
      return {'success': false, 'message': _errorMessage(data)};
    } catch (_) {
      return {
        'success': false,
        'message':
            'Cannot connect to MediQ backend server. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    int userId, {
    String? role,
    String? status,
  }) async {
    try {
      final body = <String, String>{};
      if (role != null) body['role'] = role;
      if (status != null) body['status'] = status;
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          if (AuthService.token != null)
            'Authorization': 'Bearer ${AuthService.token}',
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': _errorMessage(data)};
    } catch (_) {
      return {'success': false, 'message': 'Unable to update this user.'};
    }
  }

  static Future<Map<String, dynamic>> getAppointments({
    String search = '',
    String date = '',
    String service = '',
    String status = '',
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final query = Uri(queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (date.isNotEmpty) 'date': date,
        if (service.isNotEmpty) 'service': service,
        if (status.isNotEmpty) 'status': status,
        'page': '$page',
        'limit': '$limit',
      }).query;
      final response = await http.get(
        Uri.parse('$baseUrl/admin/appointments?$query'),
        headers: _authHeaders,
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'appointments': (payload['appointments'] as List<dynamic>? ?? [])
              .map((item) =>
                  AdminAppointment.fromJson(item as Map<String, dynamic>))
              .toList(),
          'total': payload['total'] ?? 0,
        };
      }
      return {'success': false, 'message': _errorMessage(data)};
    } catch (_) {
      return {
        'success': false,
        'message': 'Cannot connect to MediQ backend server.'
      };
    }
  }

  static Future<Map<String, dynamic>> updateAppointment(
    int appointmentId, {
    String? date,
    String? time,
    String? service,
    String? status,
  }) async {
    try {
      final body = <String, String>{};
      if (date != null && date.isNotEmpty) body['appointment_date'] = date;
      if (time != null && time.isNotEmpty) body['appointment_time'] = time;
      if (service != null && service.isNotEmpty) body['room'] = service;
      if (status != null && status.isNotEmpty) body['status'] = status;
      final response = await http.patch(
        Uri.parse('$baseUrl/admin/appointments/$appointmentId'),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': _errorMessage(data)};
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to update this appointment.'
      };
    }
  }

  static Future<Map<String, dynamic>> getDoctors({String search = ''}) async {
    return _getManagedPeople<AdminDoctor>(
      path: '/admin/doctors',
      search: search,
      parser: AdminDoctor.fromJson,
      key: 'doctors',
    );
  }

  static Future<Map<String, dynamic>> createDoctor({
    required int userId,
    required String specialization,
    required String slmcNumber,
    required String clinicName,
    required String room,
    required bool isAvailable,
  }) async {
    return _saveManagedPerson('/admin/doctors', {
      'user_id': userId,
      'specialization': specialization,
      'slmc_number': slmcNumber,
      'clinic_name': clinicName,
      'room': room,
      'is_available': isAvailable,
    });
  }

  static Future<Map<String, dynamic>> updateDoctor(
    int id, {
    required int userId,
    required String specialization,
    required String slmcNumber,
    required String clinicName,
    required String room,
    required bool isAvailable,
    required String status,
  }) async {
    return _saveManagedPerson(
        '/admin/doctors/$id',
        {
          'user_id': userId,
          'specialization': specialization,
          'slmc_number': slmcNumber,
          'clinic_name': clinicName,
          'room': room,
          'is_available': isAvailable,
          'status': status,
        },
        method: 'PATCH');
  }

  static Future<Map<String, dynamic>> getStaff({String search = ''}) async {
    return _getManagedPeople<AdminStaff>(
      path: '/admin/staff',
      search: search,
      parser: AdminStaff.fromJson,
      key: 'staff',
    );
  }

  static Future<Map<String, dynamic>> getQueues({String date = ''}) async {
    try {
      final query =
          date.isEmpty ? '' : '?date=${Uri.encodeQueryComponent(date)}';
      final response = await http.get(
        Uri.parse('$baseUrl/admin/queues$query'),
        headers: _authHeaders,
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'date': payload['date'] as String? ?? date,
          'queues': (payload['queues'] as List<dynamic>? ?? [])
              .map((item) => AdminQueue.fromJson(item as Map<String, dynamic>))
              .toList(),
          'alerts': (payload['alerts'] as List<dynamic>? ?? [])
              .map((item) =>
                  AdminQueueAlert.fromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return {'success': false, 'message': _errorMessage(data)};
    } catch (_) {
      return {
        'success': false,
        'message': 'Cannot connect to MediQ backend server.',
      };
    }
  }

  static Future<Map<String, dynamic>> createStaff({
    required int userId,
    required String function,
    required String assignedRoom,
    required bool isAvailable,
  }) async {
    return _saveManagedPerson('/admin/staff', {
      'user_id': userId,
      'function': function,
      'assigned_room': assignedRoom,
      'is_available': isAvailable,
    });
  }

  static Future<Map<String, dynamic>> updateStaff(
    int id, {
    required int userId,
    required String function,
    required String assignedRoom,
    required bool isAvailable,
    required String status,
  }) async {
    return _saveManagedPerson(
        '/admin/staff/$id',
        {
          'user_id': userId,
          'function': function,
          'assigned_room': assignedRoom,
          'is_available': isAvailable,
          'status': status,
        },
        method: 'PATCH');
  }

  static Future<Map<String, dynamic>> _getManagedPeople<T>({
    required String path,
    required String search,
    required T Function(Map<String, dynamic>) parser,
    required String key,
  }) async {
    try {
      final query = search.trim().isEmpty
          ? ''
          : '?search=${Uri.encodeQueryComponent(search.trim())}';
      final response = await http.get(Uri.parse('$baseUrl$path$query'),
          headers: _authHeaders);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          key: (data['data'] as List<dynamic>? ?? [])
              .map((item) => parser(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return {'success': false, 'message': _errorMessage(data)};
    } catch (_) {
      return {
        'success': false,
        'message': 'Cannot connect to MediQ backend server.'
      };
    }
  }

  static Future<Map<String, dynamic>> _saveManagedPerson(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = method == 'PATCH'
          ? await http.patch(uri, headers: _authHeaders, body: jsonEncode(body))
          : await http.post(uri, headers: _authHeaders, body: jsonEncode(body));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': _errorMessage(data)};
    } catch (_) {
      return {'success': false, 'message': 'Unable to save this profile.'};
    }
  }

  static Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (AuthService.token != null)
          'Authorization': 'Bearer ${AuthService.token}',
      };

  static String _errorMessage(Map<String, dynamic> data) {
    return data['error'] as String? ??
        data['message'] as String? ??
        'The request could not be completed.';
  }
}
