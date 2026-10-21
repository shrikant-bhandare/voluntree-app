import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_helpers.dart';

/// Minimum length the API accepts for a report reason.
const int minReportReasonLength = 10;

class ReportService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  /// Reports a drive. Returns null on success, otherwise the message to show
  /// (the server's validation message when it gave one).
  Future<String?> submitReport({
    required String token,
    required String eventId,
    required String category,
    required String reason,
  }) {
    return _post('$baseUrl/reports/event/$eventId', token, {
      'category': category,
      'reason': reason,
    });
  }

  /// Reports a person, optionally pointing at one chat message
  /// (`POST /reports/user/:userId`).
  Future<String?> reportUser({
    required String token,
    required String userId,
    required String category,
    required String reason,
    String? messageId,
  }) {
    return _post('$baseUrl/reports/user/$userId', token, {
      'category': category,
      'reason': reason,
      'messageId': ?messageId,
    });
  }

  Future<String?> _post(
    String url,
    String token,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return null;
      }
      debugPrint('[REPORT SERVICE] Report refused: ${response.body}');
      return apiMessage(
        tryDecodeJson(response.body),
        'The report could not be sent. Please try again.',
      );
    } catch (e) {
      debugPrint('[REPORT SERVICE] Connection error: $e');
      return friendlyNetworkError(e);
    }
  }
}
