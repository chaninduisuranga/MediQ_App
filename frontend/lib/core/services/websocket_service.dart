import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/constants.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _shouldReconnect = true;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _eventController.stream;

  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  void connect() async {
    if (kIsWeb) {
      // Web WebSocket can be implemented if needed
      return;
    }
    if (_isConnecting || isConnected) return;

    _isConnecting = true;
    _shouldReconnect = true;
    final wsUrl = AppConstants.wsBaseUrl;

    try {
      debugPrint('[WebSocket] Connecting to $wsUrl ...');
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 10));
      _isConnecting = false;
      debugPrint('[WebSocket] Connected successfully!');

      _reconnectTimer?.cancel();

      _socket!.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            debugPrint('[WebSocket] Received Event: ${decoded['event']}');
            _eventController.add(decoded);
          } catch (e) {
            debugPrint('[WebSocket] Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('[WebSocket] Connection error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WebSocket] Connection closed.');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnecting = false;
      debugPrint('[WebSocket] Failed to connect: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _socket = null;
    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        debugPrint('[WebSocket] Attempting to reconnect...');
        connect();
      });
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _socket?.close();
    _socket = null;
    debugPrint('[WebSocket] Disconnected manually.');
  }

  /// Listen specifically for queue & appointment updates
  StreamSubscription<Map<String, dynamic>> listenToEvents(
      void Function(Map<String, dynamic> event) onEvent) {
    if (!isConnected && !_isConnecting) {
      connect();
    }
    return stream.listen(onEvent);
  }
}
