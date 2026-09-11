import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/constants.dart';
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
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = Uri(queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
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

  static String _errorMessage(Map<String, dynamic> data) {
    return data['error'] as String? ??
        data['message'] as String? ??
        'The request could not be completed.';
  }
}
