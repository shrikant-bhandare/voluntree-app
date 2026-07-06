import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;

class AppConfig {
  // Centralized base URL configuration.
  // Dynamically detects environment (Web vs Emulator vs iOS/Desktop).
  static String get baseUrl {
    if (kIsWeb) {
      return 'https://voluntree-backend-tuin.onrender.com';
    }
    if (io.Platform.isAndroid) {
      // 10.0.2.2 is the special IP mapped to host localhost in Android Emulator
      return 'https://voluntree-backend-tuin.onrender.com';
    }
    return 'https://voluntree-backend-tuin.onrender.com';
  }
}
