import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/screens/event_detail_screen.dart';
import 'package:volunteer_mobile_app/screens/volunteer_events_screen.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';
import 'package:volunteer_mobile_app/services/push_tap_router.dart';

/// A tapped push used to only open the app. The router sends it to the
/// screen the notification points to, once the saved session is known.
void main() {
  late GlobalKey<NavigatorState> navKey;
  late _Pushes pushes;
  late _FakeAuth auth;
  late PushTapRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    navKey = GlobalKey<NavigatorState>();
    pushes = _Pushes();
    auth = _FakeAuth();
    router = PushTapRouter(navigatorKey: navKey, auth: auth);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [pushes],
        home: const Scaffold(body: Text('Home')),
      ),
    );
    pushes.routes.clear();
  }

  Widget screenOf(Route<dynamic> route) =>
      (route as MaterialPageRoute).builder(navKey.currentContext!);

  testWidgets('a reminder tap opens My Drives', (tester) async {
    await pumpApp(tester);
    auth.restore(signedIn: true);

    router.handleTap({'type': 'reminder_confirm', 'eventId': 'e1'});

    expect(pushes.routes, hasLength(1));
    expect(screenOf(pushes.routes.single), isA<VolunteerEventsScreen>());
  });

  testWidgets('a drive notification tap opens that drive', (tester) async {
    await pumpApp(tester);
    auth.restore(signedIn: true);

    router.handleTap({'type': 'application_cancelled', 'eventId': 'e1'});

    final screen = screenOf(pushes.routes.single);
    expect(screen, isA<EventDetailScreen>());
    expect((screen as EventDetailScreen).eventId, 'e1');
  });

  testWidgets('a tap before the session is restored waits, latest wins', (
    tester,
  ) async {
    await pumpApp(tester);

    router.handleTap({'type': 'application_cancelled', 'eventId': 'old'});
    router.handleTap({'type': 'application_cancelled', 'eventId': 'e2'});
    expect(pushes.routes, isEmpty);

    auth.restore(signedIn: true);

    expect(pushes.routes, hasLength(1));
    expect((screenOf(pushes.routes.single) as EventDetailScreen).eventId, 'e2');
  });

  testWidgets('a held tap opens once, not again on later auth changes', (
    tester,
  ) async {
    await pumpApp(tester);
    router.handleTap({'type': 'reminder_confirm', 'eventId': 'e1'});
    auth.restore(signedIn: true);

    auth.ping();

    expect(pushes.routes, hasLength(1));
  });

  testWidgets('a tap while signed out opens nothing', (tester) async {
    await pumpApp(tester);
    auth.restore(signedIn: false);

    router.handleTap({'type': 'reminder_confirm', 'eventId': 'e1'});

    expect(pushes.routes, isEmpty);
  });

  testWidgets('a held tap is dropped when nobody turns out to be signed in', (
    tester,
  ) async {
    await pumpApp(tester);
    router.handleTap({'type': 'reminder_confirm', 'eventId': 'e1'});

    auth.restore(signedIn: false);

    expect(pushes.routes, isEmpty);
  });

  testWidgets('empty or unknown data opens nothing', (tester) async {
    await pumpApp(tester);
    auth.restore(signedIn: true);

    router.handleTap({});
    router.handleTap({'type': 'recommendation'});
    router.handleTap({'type': 'system_broadcast', 'eventId': 'e1'});

    expect(pushes.routes, isEmpty);
  });
}

class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

/// Just the two flags the router reads, with a way to flip them.
class _FakeAuth extends ChangeNotifier implements AuthService {
  bool _restored = false;
  bool _signedIn = false;

  void restore({required bool signedIn}) {
    _restored = true;
    _signedIn = signedIn;
    notifyListeners();
  }

  void ping() => notifyListeners();

  @override
  bool get sessionRestored => _restored;

  @override
  bool get isAuthenticated => _signedIn;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
