import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/push_token_registrar.dart';

/// Without this, no device token ever reached the server, so no push (chat,
/// reminders, tap routing) could arrive.
class _Session extends ChangeNotifier {
  String? authToken;
  bool get signedIn => authToken != null;

  void signIn(String token) {
    authToken = token;
    notifyListeners();
  }

  void signOut() {
    authToken = null;
    notifyListeners();
  }
}

void main() {
  late _Session session;
  late StreamController<String> refresh;
  late List<(String, String)> sent;
  late String? deviceToken;
  late bool senderFails;
  late bool getterFails;
  late PushTokenRegistrar registrar;

  setUp(() {
    session = _Session();
    refresh = StreamController<String>.broadcast();
    sent = [];
    deviceToken = 'device-token-1';
    senderFails = false;
    getterFails = false;
    registrar = PushTokenRegistrar(
      session: session,
      isSignedIn: () => session.signedIn,
      authToken: () => session.authToken,
      getDeviceToken: () async {
        if (getterFails) throw StateError('no token');
        return deviceToken;
      },
      onDeviceTokenRefresh: refresh.stream,
      send: (authToken, deviceToken) async {
        if (senderFails) throw StateError('offline');
        sent.add((authToken, deviceToken));
      },
    )..start();
  });

  tearDown(() async {
    registrar.dispose();
    await refresh.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('sends the device token after sign-in', () async {
    session.signIn('jwt-a');
    await settle();
    expect(sent, [('jwt-a', 'device-token-1')]);
  });

  test('sends it for a session that is already signed in at start', () async {
    registrar.dispose();
    session.authToken = 'jwt-restored';
    sent.clear();
    registrar = PushTokenRegistrar(
      session: session,
      isSignedIn: () => session.signedIn,
      authToken: () => session.authToken,
      getDeviceToken: () async => deviceToken,
      onDeviceTokenRefresh: refresh.stream,
      send: (a, d) async => sent.add((a, d)),
    )..start();
    await settle();
    expect(sent, [('jwt-restored', 'device-token-1')]);
  });

  test('does not resend on unrelated session changes', () async {
    session.signIn('jwt-a');
    await settle();
    session.notifyListeners();
    await settle();
    expect(sent, hasLength(1));
  });

  test('sends a refreshed token while signed in', () async {
    session.signIn('jwt-a');
    await settle();
    refresh.add('device-token-2');
    await settle();
    expect(sent.last, ('jwt-a', 'device-token-2'));
  });

  test('does nothing while signed out', () async {
    refresh.add('device-token-2');
    session.notifyListeners();
    await settle();
    expect(sent, isEmpty);
  });

  test('a new sign-in after logout sends again', () async {
    session.signIn('jwt-a');
    await settle();
    session.signOut();
    session.signIn('jwt-b');
    await settle();
    expect(sent, [('jwt-a', 'device-token-1'), ('jwt-b', 'device-token-1')]);
  });

  test('a null device token sends nothing', () async {
    deviceToken = null;
    session.signIn('jwt-a');
    await settle();
    expect(sent, isEmpty);
  });

  test('a failing sender or token getter is swallowed', () async {
    senderFails = true;
    session.signIn('jwt-a');
    await settle();
    getterFails = true;
    session.signOut();
    session.signIn('jwt-b');
    await settle();
    expect(sent, isEmpty);
  });

  test('a failed send is retried on the next session change', () async {
    senderFails = true;
    session.signIn('jwt-a');
    await settle();
    senderFails = false;
    session.notifyListeners();
    await settle();
    expect(sent, [('jwt-a', 'device-token-1')]);
  });
}
