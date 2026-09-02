import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_helpers.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: parseServerDate(json['createdAt']),
    );
  }
}

/// Inbox state. Real-time delivery arrives on the chat socket
/// (`ChatService.onNotificationReceived` → [pushRealtime]); this service no
/// longer opens a socket of its own, which used to mark the user offline for
/// their chat partners every time the inbox screen opened or closed.
class NotificationService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  bool _hasUnread = false;

  // Callback hook for when a new real-time notification is received
  void Function(NotificationItem)? onNotificationReceived;

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get hasUnread => _hasUnread;

  /// Called with the payload of a `receiveNotification` socket event.
  void pushRealtime(Map<String, dynamic> data) {
    final newNotif = NotificationItem.fromJson(data);
    if (newNotif.id.isNotEmpty &&
        _notifications.any((n) => n.id == newNotif.id)) {
      return;
    }
    _notifications.insert(0, newNotif);
    _hasUnread = true;
    notifyListeners();
    onNotificationReceived?.call(newNotif);
  }

  /// Forget the previous account's inbox on logout.
  void clear() {
    _notifications = [];
    _hasUnread = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchNotifications(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = unwrapList(jsonDecode(response.body));
        _notifications = data
            .map((json) => NotificationItem.fromJson(json))
            .toList();
        _hasUnread = _notifications.any((n) => !n.isRead);
      } else {
        _notifications = [];
      }
    } catch (e) {
      debugPrint('FetchNotifications Error: $e');
      _notifications = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String token, String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Update local list
        _notifications = _notifications.map((n) {
          if (n.id == notificationId) {
            return NotificationItem(
              id: n.id,
              title: n.title,
              body: n.body,
              isRead: true,
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList();
        _hasUnread = _notifications.any((n) => !n.isRead);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('MarkAsRead Error: $e');
    }
  }
}
