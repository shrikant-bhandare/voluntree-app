import 'package:flutter/material.dart';

import '../utils/open_notification.dart';
import 'auth_service.dart';

/// Opens the screen a tapped push notification points to.
///
/// Free of Firebase types: main.dart feeds it the `data` map of a cold-start
/// message or of a tap while the app runs in the background. A tap that lands
/// before the saved session has been read is held (the latest wins) and
/// handled once it has; without a signed-in person, or with data that points
/// nowhere, nothing happens.
class PushTapRouter {
  final GlobalKey<NavigatorState> navigatorKey;
  final AuthService auth;

  Map<String, dynamic>? _pending;
  bool _waiting = false;

  PushTapRouter({required this.navigatorKey, required this.auth});

  void handleTap(Map<String, dynamic> data) {
    if (!auth.sessionRestored) {
      _pending = data;
      if (!_waiting) {
        _waiting = true;
        auth.addListener(_onAuthChanged);
      }
      return;
    }
    _open(data);
  }

  void _onAuthChanged() {
    if (!auth.sessionRestored) return;
    auth.removeListener(_onAuthChanged);
    _waiting = false;
    final data = _pending;
    _pending = null;
    if (data != null) _open(data);
  }

  void _open(Map<String, dynamic> data, {bool retried = false}) {
    if (!auth.isAuthenticated) return;
    final screen = notificationScreen(data);
    if (screen == null) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      // A cold start can restore the session before the first frame builds
      // the navigator; try once more after it.
      if (!retried) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _open(data, retried: true),
        );
        WidgetsBinding.instance.ensureVisualUpdate();
      }
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }
}
