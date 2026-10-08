import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class MedicalRecordService {
  static String get baseUrl => AuthService.baseUrl;

  /// Fetches the patient's OPD consultation history (COMPLETED appointments).
  /// Optional [month] in format 'YYYY-MM' filters results to that month.
  static Future<Map<String, dynamic>> getDoctorHistory({String? month}) async {
    try {
      final token = AuthService.token;
      var uriStr = '$baseUrl/appointments/history';
      if (month != null && month.isNotEmpty) {
        uriStr += '?month=$month';
      }
      final response = await http.get(
        Uri.parse(uriStr),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to fetch history'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> getPatientRecords({String? recordType}) async {
    try {
      final token = AuthService.token;
      var uriStr = '$baseUrl/medical-records';
      if (recordType != null && recordType.isNotEmpty) {
        uriStr += '?type=$recordType';
      }

      final response = await http.get(
        Uri.parse(uriStr),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to fetch medical records'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server. Please check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> uploadPrescription({
    required String title,
    required String notes,
    String? doctorName,
    String? clinicName,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      final token = AuthService.token;
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/medical-records/upload'));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['title'] = title;
      request.fields['notes'] = notes;
      if (doctorName != null && doctorName.isNotEmpty) {
        request.fields['doctor_name'] = doctorName;
      }
      if (clinicName != null && clinicName.isNotEmpty) {
        request.fields['clinic_name'] = clinicName;
      }

      if (filePath != null && filePath.isNotEmpty && !kIsWeb) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      } else if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName ?? 'prescription.jpg',
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Prescription uploaded successfully', 'data': data['data']};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to upload prescription'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to upload image. Please try again.'};
    }
  }

  /// Doctor-side: add a diagnosis record for a patient by NIC
  static Future<Map<String, dynamic>> addDoctorRecord({
    required String patientNIC,
    required String title,
    required String doctorName,
    String? clinicName,
    String? diagnosis,
  }) async {
    try {
      final token = AuthService.token;
      final response = await http.post(
        Uri.parse('$baseUrl/medical-records/doctor'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'patient_nic': patientNIC,
          'title': title,
          'doctor_name': doctorName,
          if (clinicName != null) 'clinic_name': clinicName,
          if (diagnosis != null) 'diagnosis': diagnosis,
        }),
      );

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Record created', 'data': data['data']};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to create doctor record'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> deleteRecord(int id) async {
    try {
      final token = AuthService.token;
      final response = await http.delete(
        Uri.parse('$baseUrl/medical-records/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Record deleted'};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to delete record'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }

  /// Resolves an image URL - Cloudinary URLs are full HTTPS, local paths need base URL prefix
  static String resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    // Local storage fallback
    return '${AuthService.baseUrl.replaceAll('/api/v1', '')}$path';
  }
}
