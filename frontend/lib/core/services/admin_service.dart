import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/constants.dart';
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
          'message': data['error'] ?? data['message'] ?? 'Failed to load dashboard data.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to MediQ backend server. Please check your connection.',
      };
    }
  }
}
