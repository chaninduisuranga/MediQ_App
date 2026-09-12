import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class ChatMessageModel {
  final String id;
  final String sender; // 'user' or 'bot'
  final String text;
  final DateTime timestamp;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: json['sender'] ?? 'bot',
      text: json['text'] as String? ?? json['message'] as String? ?? json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }
}

class ChatService {
  Future<String> _getStorageKey() async {
    final user = AuthService.currentUser;
    final nic = user?['nic'] ?? 'guest';
    return 'local_chat_history_$nic';
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (AuthService.token != null) {
      headers['Authorization'] = 'Bearer ${AuthService.token}';
    }
    return headers;
  }

  Future<List<ChatMessageModel>> getHistory() async {
    try {
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/chat/history'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] != null) {
          final List list = body['data'];
          return list.map((item) => ChatMessageModel.fromJson(item)).toList();
        }
      }
    } catch (_) {}

    // Local storage fallback per user
    final key = await _getStorageKey();
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((item) => ChatMessageModel.fromJson(item)).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<ChatMessageModel?> sendMessage(String message) async {
    try {
      final res = await http.post(
        Uri.parse('${AuthService.baseUrl}/chat/message'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['data'] != null && body['data']['bot_message'] != null) {
          return ChatMessageModel.fromJson(body['data']['bot_message']);
        }
      }
    } catch (_) {}

    // Fallback response generator if offline/backend unreachable
    final user = AuthService.currentUser;
    final fullName = user?['full_name'] as String? ?? 'there';
    final name = fullName.split(' ').first;
    final replyText = _generateFallbackResponse(message, name);
    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'bot',
      text: replyText,
      timestamp: DateTime.now(),
    );
  }

  Future<void> saveLocalHistory(List<ChatMessageModel> messages) async {
    final key = await _getStorageKey();
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(key, encoded);
  }

  Future<void> clearHistory() async {
    try {
      await http.delete(
        Uri.parse('${AuthService.baseUrl}/chat/history'),
        headers: _headers,
      );
    } catch (_) {}
    final key = await _getStorageKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  String _generateFallbackResponse(String query, String name) {
    final q = query.toLowerCase();
    if (q.contains('opd') || q.contains('queue') || q.contains('ticket')) {
      return '🏥 MediQ OPD Live Queue Status:\n• Real-time queue updates are available on the home screen.\n• Track your token turn live!';
    } else if (q.contains('book') || q.contains('appointment') || q.contains('doctor')) {
      return '📅 Booking an Appointment:\n1. Tap "Book Appointment" on the home dashboard.\n2. Pick doctor & slot to confirm your token!';
    } else if (q.contains('pill') || q.contains('medicine') || q.contains('remind')) {
      return '💊 Medication & Pill Tracker:\n• Manage your daily prescriptions and set reminders under Pill Tracker.';
    } else if (q.contains('record') || q.contains('lab') || q.contains('report')) {
      return '📁 Medical Records:\n• Access your digital prescriptions and reports in "Medical Records".';
    } else if (q.contains('fever') || q.contains('headache') || q.contains('cold')) {
      return '🌡️ Symptom Checker Guidance:\n• Hydrate and rest for mild symptoms.\n⚠️ Consult an OPD doctor if high fever persists.';
    } else if (q.contains('emergency') || q.contains('ambulance')) {
      return '🚨 Emergency Contacts:\n• Ambulance: 1990 (Suwa Seriya)\n• MediQ Emergency: 011-234-5678';
    } else if (q.contains('hello') || q.contains('hi') || q.contains('hey')) {
      return 'Hello $name! 👋 How can I assist you with your health today?';
    } else {
      return 'Hello $name! I am your MediQ AI Health Assistant. Ask me about booking appointments, live OPD queues, pill tracking, or medical records.';
    }
  }
}
