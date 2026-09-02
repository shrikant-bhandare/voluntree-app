import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_helpers.dart';

class PassDetails {
  final String passToken;
  final String eventTitle;
  final DateTime startTime;
  final String address;

  /// Signed passes are valid for two hours; the screen refreshes before this.
  final DateTime? expiresAt;

  PassDetails({
    required this.passToken,
    required this.eventTitle,
    required this.startTime,
    required this.address,
    this.expiresAt,
  });

  factory PassDetails.fromJson(Map<String, dynamic> json) {
    return PassDetails(
      passToken: json['passToken'] ?? '',
      eventTitle: json['eventTitle'] ?? '',
      startTime: parseServerDate(json['startTime']),
      address: json['address'] ?? '',
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'])
          : null,
    );
  }
}

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
      checkOut: json['checkOut'] != null
          ? DateTime.tryParse(json['checkOut'].toString())
          : null,
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
  List<CompletedDrive> _history = [];

  bool get isLoading => _isLoading;
  PassDetails? get activePass => _activePass;
  List<CompletedDrive> get history => _history;

  void clear() {
    _activePass = null;
    _history = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchPassDetails(
    String token,
    String applicationId,
  ) async {
    _isLoading = true;
    _activePass = null;
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
      return {'success': false, 'message': 'Network connection failed: $e'};
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
      return {'success': false, 'message': 'Network connection failed: $e'};
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
