import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class LeaderboardUser {
  final String userId;
  final String fullName;
  final String email;
  final int reputationScore;
  final String reputationLevel;

  LeaderboardUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.reputationScore,
    required this.reputationLevel,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    return LeaderboardUser(
      userId: json['id'] ?? '',
      fullName: user['fullName'] ?? 'Anonymous Volunteer',
      email: user['email'] ?? '',
      reputationScore: json['reputationScore'] ?? 0,
      reputationLevel: json['reputationLevel'] ?? 'BRONZE',
    );
  }
}

class LeaderboardService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  List<LeaderboardUser> _topVolunteers = [];
  bool _isLoading = false;

  List<LeaderboardUser> get topVolunteers => _topVolunteers;
  bool get isLoading => _isLoading;

  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    _topVolunteers = [];
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/leaderboard'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _topVolunteers = data
            .map((json) => LeaderboardUser.fromJson(json))
            .toList();
      } else {
        _topVolunteers = [];
      }
    } catch (e) {
      debugPrint('FetchLeaderboard Error: $e');
      _topVolunteers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
