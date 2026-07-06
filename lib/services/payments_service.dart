import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class PaymentRecord {
  final String id;
  final double amount;
  final String currency;
  final String type;
  final String status;
  final String txRef;
  final String? eventTitle;
  final DateTime createdAt;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    required this.txRef,
    this.eventTitle,
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'INR',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      txRef: json['txRef'] ?? '',
      eventTitle: json['event']?['title'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class PaymentsService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  bool _isLoading = false;
  List<PaymentRecord> _history = [];

  bool get isLoading => _isLoading;
  List<PaymentRecord> get history => _history;

  Future<Map<String, dynamic>> createDonation(String token, double amount, {String? eventId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = <String, dynamic>{'amount': amount};
      if (eventId != null) body['eventId'] = eventId;

      final response = await http.post(
        Uri.parse('$baseUrl/payments/donate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {'success': true, ...data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Donation failed'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> createSubscription(String token, String plan) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/subscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'plan': plan}),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {'success': true, ...data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Subscription failed'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> promoteEvent(String token, String eventId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/promote/$eventId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {'success': true, ...data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Promotion failed'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyTransaction(String token, String txRef, String status) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'txRef': txRef, 'status': status}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        await fetchHistory(token);
        return {'success': true, ...data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Verification failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<void> fetchHistory(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _history = data.map((json) => PaymentRecord.fromJson(json)).toList();
      } else {
        _history = [];
      }
    } catch (e) {
      debugPrint('FetchPaymentHistory Error: $e');
      _history = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
