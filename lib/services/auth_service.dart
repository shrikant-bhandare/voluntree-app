import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'api_helpers.dart';
import '../utils/event_time.dart';

class UserProfile {
  final String id;
  final String? avatarUrl;
  final List<String> skills;
  final List<String> interests;
  final String experienceLevel;
  final int reputationScore;
  final String reputationLevel;
  final List<String> availability;
  final String? bio;
  final String? location;
  final String? emergencyName;
  final String? emergencyContact;
  final String? educationOrJob;
  final String? socialGithub;
  final String? socialLinkedin;

  UserProfile({
    required this.id,
    this.avatarUrl,
    required this.skills,
    required this.interests,
    required this.experienceLevel,
    required this.reputationScore,
    required this.reputationLevel,
    required this.availability,
    this.bio,
    this.location,
    this.emergencyName,
    this.emergencyContact,
    this.educationOrJob,
    this.socialGithub,
    this.socialLinkedin,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      avatarUrl: AppConfig.formatMediaUrl(json['avatarUrl']),
      skills: List<String>.from(json['skills'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      experienceLevel: json['experienceLevel'] ?? 'BEGINNER',
      reputationScore: json['reputationScore'] ?? 0,
      reputationLevel: json['reputationLevel'] ?? 'BRONZE',
      availability: List<String>.from(json['availability'] ?? []),
      bio: json['bio'],
      location: json['location'],
      emergencyName: json['emergencyName'],
      emergencyContact: json['emergencyContact'],
      educationOrJob: json['educationOrJob'],
      socialGithub: json['socialGithub'],
      socialLinkedin: json['socialLinkedin'],
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

  /// Calendar date of birth (no time zone), or null when not on file yet.
  /// Required by the API before a volunteer can apply to a drive.
  final DateTime? dateOfBirth;

  UserInfo({
    required this.id,
    required this.email,
    this.phoneNumber,
    required this.fullName,
    required this.userType,
    required this.isVerified,
    this.profile,
    this.dateOfBirth,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'],
      fullName: json['fullName'] ?? '',
      userType: json['userType'] ?? 'VOLUNTEER',
      isVerified: json['isVerified'] ?? false,
      dateOfBirth: parseCalendarDate(json['dateOfBirth']),
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'])
          : null,
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
    if (savedToken == null) return;

    // Surface the restore as a loading state so AuthGate shows its splash
    // instead of flashing LoginScreen and then swapping to HomeScreen.
    _isLoading = true;
    _token = savedToken;
    notifyListeners();
    try {
      // Validate token and fetch current profile details. One transient
      // network error must not strand a valid 7-day session on the login
      // screen, so retry once before giving up.
      await fetchMe();
      if (_currentUser == null && _token != null) {
        await Future.delayed(const Duration(seconds: 2));
        await fetchMe();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        _currentUser = UserInfo.fromJson(jsonDecode(response.body));
        notifyListeners();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // The session itself is invalid (expired, banned, deleted).
        await logout();
      } else {
        // 5xx / 429 mean the server is unhealthy, not the session. Keep it.
        debugPrint('FetchMe unexpected status ${response.statusCode}');
      }
    } catch (e) {
      // Keep session local if offline, or handle connection error
      debugPrint('FetchMe Connection Error: $e');
    }
  }

  /// Every account starts as a volunteer. Organizer access is granted by the
  /// NGO verification flow, so the role is not part of this request — the
  /// server would reject it anyway.
  ///
  /// [dateOfBirth] is sent as a calendar date (`YYYY-MM-DD`) and
  /// [acceptTerms] must be true; the API rejects the request otherwise.
  Future<Map<String, dynamic>> register({
    required String email,
    String? phoneNumber,
    required String fullName,
    required DateTime dateOfBirth,
    required bool acceptTerms,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phoneNumber': phoneNumber,
          'fullName': fullName,
          'dateOfBirth': formatCalendarDate(dateOfBirth),
          'acceptTerms': acceptTerms,
        }),
      );

      final data = tryDecodeJson(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data is Map ? data['message'] : null,
        };
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'Registration failed'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': friendlyNetworkError(e)};
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
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phoneNumber': phoneNumber,
        }),
      );

      // The throttler answers 429 with a plain-text body.
      final data = tryDecodeJson(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'otpInDev': data['otpInDev'], // Retained for local developer testing
        };
      } else {
        return {
          'success': false,
          'message': otpRequestErrorMessage(
            response.statusCode,
            apiMessage(data, 'Could not send a code. Please try again.'),
          ),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': friendlyNetworkError(e)};
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
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phoneNumber': phoneNumber,
          'code': code,
        }),
      );

      final data = tryDecodeJson(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        await _saveSession(data['accessToken'], data['user']);
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'OTP verification failed'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': friendlyNetworkError(e)};
    }
  }

  /// Social sign-in.
  ///
  /// Only the provider's ID token is sent. The server verifies its signature
  /// and reads the email and name from the token — the client cannot assert
  /// who it is, which is what made the old email-only version an open door.
  Future<Map<String, dynamic>> ssoLogin({
    required String idToken,
    required String provider,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/sso'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken, 'provider': provider}),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _saveSession(data['accessToken'], data['user']);
        return {'success': true, 'user': data['user']};
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'SSO authentication failed'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': friendlyNetworkError(e)};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    List<String>? skills,
    List<String>? interests,
    String? avatarUrl,
    String? bio,
    String? location,
    String? emergencyName,
    String? emergencyContact,
    String? educationOrJob,
    String? socialGithub,
    String? socialLinkedin,
    String? experienceLevel,
    List<String>? availability,
    DateTime? dateOfBirth,
  }) async {
    if (_token == null) {
      return {'success': false, 'message': 'User is not authenticated.'};
    }
    _isLoading = true;
    notifyListeners();

    try {
      // Only send what the caller provided: a null here erased the stored
      // value on the server (@IsOptional accepts null and Prisma stores it).
      final bodyData = <String, dynamic>{};
      if (bio != null) bodyData['bio'] = bio;
      if (location != null) bodyData['location'] = location;
      if (emergencyName != null) bodyData['emergencyName'] = emergencyName;
      if (emergencyContact != null) {
        bodyData['emergencyContact'] = emergencyContact;
      }
      if (educationOrJob != null) bodyData['educationOrJob'] = educationOrJob;
      if (socialGithub != null) bodyData['socialGithub'] = socialGithub;
      if (socialLinkedin != null) bodyData['socialLinkedin'] = socialLinkedin;
      if (skills != null) bodyData['skills'] = skills;
      if (interests != null) bodyData['interests'] = interests;
      if (avatarUrl != null) bodyData['avatarUrl'] = avatarUrl;
      if (experienceLevel != null) {
        bodyData['experienceLevel'] = experienceLevel;
      }
      if (availability != null) bodyData['availability'] = availability;
      if (dateOfBirth != null) {
        bodyData['dateOfBirth'] = formatCalendarDate(dateOfBirth);
      }

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(bodyData),
      );

      _isLoading = false;
      if (response.statusCode == 200) {
        await fetchMe();
        return {'success': true};
      } else {
        notifyListeners();
        return {
          'success': false,
          'message': apiMessage(
            tryDecodeJson(response.body),
            'Failed to update profile',
          ),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': friendlyNetworkError(e)};
    }
  }

  /// `GET /auth/export` — everything the platform holds about the user, as
  /// pretty-printed JSON bytes. Returns `{success, bytes}` or
  /// `{success: false, message}`.
  Future<Map<String, dynamic>> exportMyData() async {
    if (_token == null) {
      return {'success': false, 'message': 'Please sign in again.'};
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/export'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final decoded = tryDecodeJson(response.body);
        final pretty = decoded == null
            ? response.body
            : const JsonEncoder.withIndent('  ').convert(decoded);
        return {'success': true, 'bytes': utf8.encode(pretty)};
      }
      return {
        'success': false,
        'message': apiMessage(
          tryDecodeJson(response.body),
          'Could not prepare your data. Please try again.',
        ),
      };
    } catch (e) {
      return {'success': false, 'message': friendlyNetworkError(e)};
    }
  }

  /// `DELETE /auth/account`. Returns null on success, otherwise the message
  /// to show — notably the server's refusal while an organizer still hosts
  /// upcoming drives. The caller ends the session on success.
  Future<String?> deleteAccount() async {
    if (_token == null) return 'Please sign in again.';
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/account'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return null;
      }
      return apiMessage(
        tryDecodeJson(response.body),
        'Your account could not be deleted. Please try again.',
      );
    } catch (e) {
      return friendlyNetworkError(e);
    }
  }

  /// Uploads a verification document to the private bucket
  /// (POST /ngos/upload). The returned URL is what the verification request
  /// must reference — the API rejects public-bucket or external links.
  Future<String?> uploadPrivateDocument(
    List<int> bytes,
    String filename,
  ) async {
    if (_token == null) return null;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ngos/upload'),
      );
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['url'] as String?;
      }
      debugPrint('[AUTH SERVICE] Document upload failed: ${response.body}');
    } catch (e) {
      debugPrint('[AUTH SERVICE] Document upload error: $e');
    }
    return null;
  }

  /// GET /ngos/my-verification → `{status: PENDING|APPROVED|REJECTED|null}`.
  Future<Map<String, dynamic>?> fetchMyVerification() async {
    if (_token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ngos/my-verification'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[AUTH SERVICE] fetchMyVerification error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> submitNgoVerification({
    required String ngoName,
    required String contactDetails,
    required String registrationDocs,
    required String identityProof,
  }) async {
    if (_token == null) {
      return {'success': false, 'message': 'User is not authenticated.'};
    }
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ngos/verify-request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'ngoName': ngoName,
          'contactDetails': contactDetails,
          'registrationDocs': registrationDocs,
          'identityProof': identityProof,
        }),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true};
      }
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }
      return {
        'success': false,
        'message': apiMessage(
          data,
          'Submission failed (HTTP ${response.statusCode})',
        ),
      };
    } catch (e) {
      return {'success': false, 'message': friendlyNetworkError(e)};
    }
  }

  Future<String?> uploadProfileImage(List<int> bytes, String filename) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/upload'),
      );
      request.headers['Authorization'] = 'Bearer $_token';

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      } else {
        debugPrint('[AUTH SERVICE] Upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[AUTH SERVICE] Upload connection error: $e');
      return null;
    }
  }
}

/// Copy for a failed `POST /auth/request-otp`. The per-identifier limit
/// (400 "Too many codes…") and the per-IP throttler (429) both mean "wait".
String otpRequestErrorMessage(int statusCode, String serverMessage) {
  if (statusCode == 429 || serverMessage.toLowerCase().contains('too many')) {
    return "You've requested several codes in a short time. Please wait "
        'about 15 minutes, then try again. Check your spam folder for a code '
        'that already arrived.';
  }
  return serverMessage;
}
