import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/constants.dart';

class ApiClient {
  final http.Client _client = http.Client();

  Future<dynamic> get(String endpoint) async {
    final response = await _client.get(
      Uri.parse('${AppConstants.apiBaseUrl}$endpoint'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load data from $endpoint');
  }
}
