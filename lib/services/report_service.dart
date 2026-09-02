import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ReportService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  Future<bool> submitReport({
    required String token,
    required String eventId,
    required String category,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports/event/$eventId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'category': category, 'reason': reason}),
      );

      if (response.statusCode == 201) {
        debugPrint('[REPORT SERVICE] Report submitted successfully.');
        return true;
      }
      debugPrint('[REPORT SERVICE] Failed to submit report: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[REPORT SERVICE] Connection error: $e');
      return false;
    }
  }
}
