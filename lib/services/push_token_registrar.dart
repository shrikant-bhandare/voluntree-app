import 'dart:async';

import 'package:flutter/foundation.dart';

/// Keeps the server's copy of this device's push token current.
///
/// Free of Firebase and HTTP types: main.dart passes in the token getter, the
/// refresh stream and the sender. It sends the token when a person is signed
/// in (a fresh sign-in or a restored session look the same here) and again
/// whenever the device token is refreshed; while signed out it sends nothing.
/// A failure is logged, never thrown, and is retried on the next session
/// change, so a push problem cannot block sign-in or start-up.
class PushTokenRegistrar {
  final Listenable session;
  final bool Function() isSignedIn;
  final String? Function() authToken;
  final Future<String?> Function() getDeviceToken;
  final Stream<String> onDeviceTokenRefresh;
  final Future<void> Function(String authToken, String deviceToken) send;

  /// Invalidates the device token on logout so pushes meant for the person
  /// who signed out stop arriving; the next sign-in fetches a fresh one.
  final Future<void> Function()? deleteDeviceToken;

  /// The sign-in the device token was last registered for.
  String? _registeredFor;
  bool _inFlight = false;
  bool _wasSignedIn = false;
  StreamSubscription<String>? _refreshSub;

  PushTokenRegistrar({
    required this.session,
    required this.isSignedIn,
    required this.authToken,
    required this.getDeviceToken,
    required this.onDeviceTokenRefresh,
    required this.send,
    this.deleteDeviceToken,
  });

  void start() {
    session.addListener(_onSessionChanged);
    _refreshSub = onDeviceTokenRefresh.listen(
      (token) => _register(token),
      onError: (Object e) => debugPrint('[PUSH] Token refresh error: $e'),
    );
    _onSessionChanged();
  }

  void dispose() {
    session.removeListener(_onSessionChanged);
    _refreshSub?.cancel();
  }

  void _onSessionChanged() {
    final auth = isSignedIn() ? authToken() : null;
    if (auth == null) {
      _registeredFor = null;
      if (_wasSignedIn) {
        _wasSignedIn = false;
        _deleteToken();
      }
      return;
    }
    _wasSignedIn = true;
    if (auth == _registeredFor || _inFlight) return;
    _register(null);
  }

  Future<void> _deleteToken() async {
    try {
      await deleteDeviceToken?.call();
    } catch (e) {
      debugPrint('[PUSH] Could not delete the device token: $e');
    }
  }

  /// Registers [knownToken], or asks the device for its token when null.
  Future<void> _register(String? knownToken) async {
    final auth = isSignedIn() ? authToken() : null;
    if (auth == null) return;
    _inFlight = true;
    try {
      final deviceToken = knownToken ?? await getDeviceToken();
      if (deviceToken == null || deviceToken.isEmpty) return;
      await send(auth, deviceToken);
      _registeredFor = auth;
    } catch (e) {
      debugPrint('[PUSH] Could not register the device token: $e');
    } finally {
      _inFlight = false;
    }
  }
}
