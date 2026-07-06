import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

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
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class NotificationService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  io.Socket? _socket;
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  bool _hasUnread = false;

  // Callback hook for when a new real-time notification is received
  void Function(NotificationItem)? onNotificationReceived;

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get hasUnread => _hasUnread;

  // Initialize socket for real-time notification alerts
  void initSocket(String token) {
    if (_socket != null) {
      _socket!.disconnect();
    }

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token})
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[NOTIFICATION SERVICE] Socket connected.');
    });

    // Listen for incoming real-time notifications
    _socket!.on('receiveNotification', (data) {
      debugPrint('[NOTIFICATION SERVICE] Real-time notification received: $data');
      final newNotif = NotificationItem.fromJson(data);
      _notifications.insert(0, newNotif);
      _hasUnread = true;
      notifyListeners();
      
      // Trigger callback if registered
      if (onNotificationReceived != null) {
        onNotificationReceived!(newNotif);
      }
    });

    _socket!.connect();
  }

  void disconnectSocket() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }

  Future<void> fetchNotifications(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _notifications = data.map((json) => NotificationItem.fromJson(json)).toList();
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
        headers: {
          'Authorization': 'Bearer $token',
        },
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
