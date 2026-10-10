import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'MediQ';
  
  static String get apiBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8085/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8085/api/v1';
    }
    return 'http://127.0.0.1:8085/api/v1';
  }
}
