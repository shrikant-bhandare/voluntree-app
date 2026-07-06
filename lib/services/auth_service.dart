import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class UserProfile {
  final String id;
  final String? avatarUrl;
  final List<String> skills;
  final List<String> interests;
  final String experienceLevel;
  final int reputationScore;
  final String reputationLevel;
  final List<String> availability;

  UserProfile({
    required this.id,
    this.avatarUrl,
    required this.skills,
    required this.interests,
    required this.experienceLevel,
    required this.reputationScore,
    required this.reputationLevel,
    required this.availability,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      avatarUrl: json['avatarUrl'],
      skills: List<String>.from(json['skills'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      experienceLevel: json['experienceLevel'] ?? 'BEGINNER',
      reputationScore: json['reputationScore'] ?? 0,
      reputationLevel: json['reputationLevel'] ?? 'BRONZE',
      availability: List<String>.from(json['availability'] ?? []),
    );
  }
}

class UserInfo {
  final String id;
  final String email;
  final String? phoneNumber;
  final String fullName;
  final String userType;
  final bool isVerified;
  final UserProfile? profile;

  UserInfo({
    required this.id,
    required this.email,
    this.phoneNumber,
    required this.fullName,
    required this.userType,
    required this.isVerified,
    this.profile,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'],
      fullName: json['fullName'] ?? '',
      userType: json['userType'] ?? 'VOLUNTEER',
      isVerified: json['isVerified'] ?? false,
      profile: json['profile'] != null ? UserProfile.fromJson(json['profile']) : null,
    );
  }
}

class AuthService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;
  
  String? _token;
  UserInfo? _currentUser;
  bool _isLoading = false;

  String? get token => _token;
  UserInfo? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _currentUser != null;

  AuthService() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('access_token');
    if (savedToken != null) {
      _token = savedToken;
      // Validate token and fetch current profile details
      await fetchMe();
    }
  }

  Future<void> _saveSession(String token, Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    _token = token;
    _currentUser = UserInfo.fromJson(userJson);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    _token = null;
    _currentUser = null;
    notifyListeners();
  }

  Future<void> fetchMe() async {
    if (_token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        _currentUser = UserInfo.fromJson(jsonDecode(response.body));
        notifyListeners();
      } else {
        await logout();
      }
    } catch (e) {
      // Keep session local if offline, or handle connection error
      debugPrint('FetchMe Connection Error: $e');
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    String? phoneNumber,
    required String fullName,
    required String userType, // VOLUNTEER or ORGANIZER
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
          'fullName': fullName,
          'userType': userType,
        }),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> requestOtp({
    String? email,
    String? phoneNumber,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (email != null && email.isNotEmpty) 'email': email,
          if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
        }),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'otpInDev': data['otpInDev'] // Retained for local developer testing
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to request OTP'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    String? email,
    String? phoneNumber,
    required String code,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (email != null && email.isNotEmpty) 'email': email,
          if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        await _saveSession(data['accessToken'], data['user']);
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'OTP verification failed'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }
}
