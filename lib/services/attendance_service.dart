import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_helpers.dart';

class PassDetails {
  final String passToken;

  /// Short manual check-in code (`XXXX-XXXX`), valid for the same window as
  /// the QR token. Read aloud when the organizer cannot scan (web build).
  final String? passCode;
  final String eventTitle;
  final DateTime startTime;
  final String address;

  /// Signed passes are valid for two hours; the screen refreshes before this.
  final DateTime? expiresAt;

  PassDetails({
    required this.passToken,
    this.passCode,
    required this.eventTitle,
    required this.startTime,
    required this.address,
    this.expiresAt,
  });

  factory PassDetails.fromJson(Map<String, dynamic> json) {
    return PassDetails(
      passToken: json['passToken'] ?? '',
      passCode: formatPassCode(json['passCode']),
      eventTitle: json['eventTitle'] ?? '',
      startTime: parseServerDate(json['startTime']),
      address: json['address'] ?? '',
      expiresAt: parseServerDateOrNull(json['expiresAt']),
    );
  }
}

/// Normalises a pass code to `XXXX-XXXX` (upper case, hyphen in the middle).
/// Returns null when there is no usable code.
String? formatPassCode(dynamic raw) {
  if (raw is! String) return null;
  final compact = normalizePassCode(raw);
  if (compact.isEmpty) return null;
  if (compact.length != 8) return compact;
  return '${compact.substring(0, 4)}-${compact.substring(4)}';
}

/// Strips spaces/hyphens and upper-cases, as the server accepts either form.
String normalizePassCode(String raw) =>
    raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

class CompletedDrive {
  final String id;
  final String eventId;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double hoursLogged;
  final String eventTitle;
  final String eventCategory;

  CompletedDrive({
    required this.id,
    required this.eventId,
    required this.checkIn,
    this.checkOut,
    required this.hoursLogged,
    required this.eventTitle,
    required this.eventCategory,
  });

  factory CompletedDrive.fromJson(Map<String, dynamic> json) {
    return CompletedDrive(
      id: json['id'] ?? '',
      eventId: json['eventId'] ?? '',
      checkIn: parseServerDate(json['checkIn']),
      checkOut: parseServerDateOrNull(json['checkOut']),
      hoursLogged: (json['hoursLogged'] ?? 0.0).toDouble(),
      eventTitle: json['event']?['title'] ?? '',
      eventCategory: json['event']?['category'] ?? '',
    );
  }
}

class AttendanceService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  bool _isLoading = false;
  PassDetails? _activePass;
  String? _activePassApplicationId;
  List<CompletedDrive> _history = [];

  bool get isLoading => _isLoading;
  PassDetails? get activePass => _activePass;
  List<CompletedDrive> get history => _history;

  void clear() {
    _activePass = null;
    _activePassApplicationId = null;
    _history = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchPassDetails(
    String token,
    String applicationId,
  ) async {
    _isLoading = true;
    // Keep a still-valid pass for the same application while refreshing, so
    // a network blip at the venue does not wipe the code off the screen.
    if (_activePassApplicationId != applicationId) {
      _activePass = null;
    }
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/pass/$applicationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) {
        _activePass = PassDetails.fromJson(data);
        _activePassApplicationId = applicationId;
        notifyListeners();
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'Failed to load pass details'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': friendlyNetworkError(e)};
    }
  }

  Future<Map<String, dynamic>> verifyScannedPass(
    String token,
    String passToken,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'passToken': passToken}),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {
          'success': true,
          'type': data['type'],
          'message': data['message'],
          'time': data['time'],
          'hoursLogged': data['hoursLogged'],
          'pointsAwarded': data['pointsAwarded'],
        };
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'Scanned pass verification failed'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': friendlyNetworkError(e)};
    }
  }

  /// Manual check-in/out: the organizer picks one of their drives and types
  /// the volunteer's 8-character pass code (`POST /attendance/scan`
  /// with `{eventId, passCode}`). Same response shape as a QR scan.
  Future<Map<String, dynamic>> verifyPassCode(
    String token, {
    required String eventId,
    required String passCode,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'eventId': eventId,
          'passCode': formatPassCode(passCode) ?? passCode,
        }),
      );
      final data = tryDecodeJson(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'type': data?['type'],
          'message': data?['message'],
          'time': data?['time'],
          'hoursLogged': data?['hoursLogged'],
          'pointsAwarded': data?['pointsAwarded'],
        };
      }
      return {
        'success': false,
        'message': apiMessage(data, 'That pass code was not accepted.'),
      };
    } catch (e) {
      return {'success': false, 'message': friendlyNetworkError(e)};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchHistory(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = unwrapList(jsonDecode(response.body));
        _history = data.map((json) => CompletedDrive.fromJson(json)).toList();
      } else {
        _history = [];
      }
    } catch (e) {
      debugPrint('FetchHistory Error: $e');
      _history = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> downloadCertificate(
    String token,
    String attendanceId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/certificate/$attendanceId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('DownloadCertificate Error: $e');
      return null;
    }
  }
}
