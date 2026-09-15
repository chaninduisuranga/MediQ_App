import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for iOS/Windows/Web
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8085/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.8.129:8085/api/v1';
    }
    return 'http://127.0.0.1:8085/api/v1';
  }

  static String? _token;
  static Map<String, dynamic>? _currentUser;
  static final ValueNotifier<String?> profilePhotoNotifier =
      ValueNotifier<String?>(null);

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null;

  static Future<void> loadSavedProfilePhoto() async {
    final nic = _currentUser?['nic'];
    if (nic != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('profile_photo_$nic');
      profilePhotoNotifier.value = savedPath;
      if (_currentUser != null && savedPath != null) {
        _currentUser!['profile_image'] = savedPath;
      }
    }
  }

  static Future<void> updateProfilePhoto(String imagePath) async {
    final nic = _currentUser?['nic'];
    if (nic != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_photo_$nic', imagePath);
    }
    if (_currentUser != null) {
      _currentUser!['profile_image'] = imagePath;
    }
    profilePhotoNotifier.value = imagePath;
  }

  static Future<Map<String, dynamic>> login({
    required String nic,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nic': nic.trim().toUpperCase(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _token = data['data']['token'];
        _currentUser = data['data']['user'];
        await loadSavedProfilePhoto();
        return {
          'success': true,
          'message': data['message'] ?? 'Login successful',
          'data': data['data']
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ??
              data['message'] ??
              'Failed to login. Please try again.',
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

  static Future<Map<String, dynamic>> loginWithGoogle({
    required String email,
    required String fullName,
    required String googleId,
    String? photoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'full_name': fullName,
          'google_id': googleId,
          'photo_url': photoUrl ?? '',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _token = data['data']['token'];
        _currentUser = data['data']['user'];
        if (photoUrl != null && photoUrl.isNotEmpty) {
          await updateProfilePhoto(photoUrl);
        } else {
          await loadSavedProfilePhoto();
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Google login successful',
          'data': data['data']
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ??
              data['message'] ??
              'Failed to login with Google.',
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

  static Future<Map<String, dynamic>> signupPatient({
    required String fullName,
    required String nic,
    String email = '',
    required String phone,
    required String password,
    required String gender,
    required String dateOfBirth,
    required String civilStatus,
    required String address,
    required String district,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String bloodGroup,
    required String allergies,
    required String medicalConditions,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'nic': nic.trim().toUpperCase(),
          'email': email,
          'phone': phone,
          'password': password,
          'gender': gender,
          'date_of_birth': dateOfBirth,
          'civil_status': civilStatus,
          'address': address,
          'district': district,
          'emergency_contact_name': emergencyContactName,
          'emergency_contact_phone': emergencyContactPhone,
          'blood_group': bloodGroup,
          'allergies': allergies,
          'medical_conditions': medicalConditions,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        _token = data['data']['token'];
        _currentUser = data['data']['user'];
        await loadSavedProfilePhoto();
        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful',
          'data': data['data']
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ??
              data['message'] ??
              'Registration failed. Please check your information.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to MediQ backend server. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String email = '',
    required String phone,
    required String gender,
    required String dateOfBirth,
    required String civilStatus,
    required String address,
    required String district,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String bloodGroup,
    required String allergies,
    required String medicalConditions,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'gender': gender,
          'date_of_birth': dateOfBirth,
          'civil_status': civilStatus,
          'address': address,
          'district': district,
          'emergency_contact_name': emergencyContactName,
          'emergency_contact_phone': emergencyContactPhone,
          'blood_group': bloodGroup,
          'allergies': allergies,
          'medical_conditions': medicalConditions,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _currentUser = data['data'];
        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'data': data['data']
        };
      } else {
        return {
          'success': false,
          'message':
              data['error'] ?? data['message'] ?? 'Failed to update profile.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to server. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        logout();
        return {
          'success': true,
          'message': data['message'] ?? 'Account deleted successfully'
        };
      } else {
        return {
          'success': false,
          'message':
              data['error'] ?? data['message'] ?? 'Failed to delete account.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to server. Please try again.',
      };
    }
  }

  static void logout() {
    _token = null;
    _currentUser = null;
  }
}
