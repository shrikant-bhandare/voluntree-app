import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile_app/screens/event_detail_screen.dart';
import 'package:volunteer_mobile_app/screens/public_event_screen.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';
import 'package:volunteer_mobile_app/services/deep_link_service.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';
import 'package:volunteer_mobile_app/utils/deep_link.dart';
import 'package:volunteer_mobile_app/widgets/deep_link_host.dart';

const id = '3f1d9b7e-0000-4000-8000-000000000000';
final appLink = Uri.parse('https://api.example.org/p/e/$id');

void main() {
  group('eventIdFromLink', () {
    test('reads the public share page / App Link', () {
      expect(eventIdFromLink(Uri.parse('https://api.example.org/p/e/$id')), id);
    });

    test('reads the web app link', () {
      expect(eventIdFromLink(Uri.parse('https://app.example/?event=$id')), id);
    });

    test('ignores everything else', () {
      expect(eventIdFromLink(Uri.parse('https://app.example/')), isNull);
      expect(
        eventIdFromLink(Uri.parse('https://api.example.org/p/e/abc')),
        isNull,
      );
      expect(
        eventIdFromLink(Uri.parse('https://app.example/?event=x')),
        isNull,
      );
      expect(
        eventIdFromLink(Uri.parse('https://api.example.org/p/v/$id')),
        isNull,
      );
    });
  });

  group('deepLinkAction', () {
    DeepLinkAction act({
      String? pending = id,
      bool loading = false,
      bool signedIn = false,
      bool guestShown = false,
    }) => deepLinkAction(
      pendingEventId: pending,
      sessionLoading: loading,
      signedIn: signedIn,
      guestViewShown: guestShown,
    );

    test('does nothing without a link', () {
      expect(act(pending: null), DeepLinkAction.none);
    });

    test('waits while the saved session is being restored', () {
      expect(act(loading: true), DeepLinkAction.wait);
    });

    test('opens the drive for a signed-in person', () {
      expect(act(signedIn: true), DeepLinkAction.openDrive);
    });

    test('shows guests the drive once', () {
      expect(act(), DeepLinkAction.openGuestView);
      expect(act(guestShown: true), DeepLinkAction.none);
    });
  });

  group('guestCanSeeDrive', () {
    const link = 'https://api.example.org/p/e/$id';

    test('shows the drives the public page shows', () {
      for (final status in [
        'ACTIVE',
        'FEATURED',
        'FULL',
        'CLOSED',
        'COMPLETED',
      ]) {
        expect(
          guestCanSeeDrive(
            status: status,
            shareUrlProvided: true,
            shareUrl: link,
          ),
          isTrue,
          reason: status,
        );
      }
    });

    test('hides drafts, cancelled, suspended and unknown drives', () {
      for (final status in ['DRAFT', 'CANCELLED', 'SUSPENDED', 'ARCHIVED']) {
        expect(
          guestCanSeeDrive(
            status: status,
            shareUrlProvided: true,
            shareUrl: link,
          ),
          isFalse,
          reason: status,
        );
      }
    });

    test('hides a drive the server will not share', () {
      expect(
        guestCanSeeDrive(
          status: 'ACTIVE',
          shareUrlProvided: true,
          shareUrl: null,
        ),
        isFalse,
      );
    });

    test('goes by status alone on servers that send no share link', () {
      expect(
        guestCanSeeDrive(status: 'ACTIVE', shareUrlProvided: false),
        isTrue,
      );
      expect(
        guestCanSeeDrive(status: 'CANCELLED', shareUrlProvided: false),
        isFalse,
      );
    });
  });

  group('guestCanApply', () {
    final now = DateTime(2026, 11, 15, 12);
    final later = now.add(const Duration(hours: 3));

    test('offers sign-in while a live drive has not ended', () {
      for (final status in ['ACTIVE', 'FEATURED', 'FULL']) {
        expect(
          guestCanApply(status: status, end: later, now: now),
          isTrue,
          reason: status,
        );
      }
    });

    test('offers nothing once the drive has ended', () {
      expect(guestCanApply(status: 'ACTIVE', end: now, now: now), isFalse);
      expect(
        guestCanApply(
          status: 'FULL',
          end: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('offers nothing for a drive that is not taking sign-ups', () {
      for (final status in ['CLOSED', 'COMPLETED', 'CANCELLED', 'DRAFT']) {
        expect(
          guestCanApply(status: status, end: later, now: now),
          isFalse,
          reason: status,
        );
      }
    });
  });

  group('DeepLinkHost', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('a link while signed out shows the guest view', (tester) async {
      final app = await _pumpApp(tester, auth: _FakeAuth());

      app.links.handle(appLink);
      await tester.pumpAndSettle();

      expect(find.byType(PublicEventScreen), findsOneWidget);
      expect(find.text('Lake clean-up'), findsOneWidget);
      expect(find.text('Sign in to apply'), findsOneWidget);
    });

    testWidgets('signing in from the guest view opens the drive, although '
        'the code screen then pops back to the first route', (tester) async {
      final auth = _FakeAuth();
      final app = await _pumpApp(tester, auth: auth);
      app.links.handle(appLink);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in to apply'));
      await tester.pumpAndSettle();
      expect(find.byType(PublicEventScreen), findsNothing);

      // LoginScreen sends the code and pushes OtpScreen.
      app.navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Enter your code')),
        ),
      );
      await tester.pumpAndSettle();

      // verifyOtp saves the session (listeners hear "signed in"), then
      // OtpScreen pops back to the first route in the same turn.
      auth.settle(signedIn: true);
      app.navigator.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Enter your code'), findsNothing);
    });

    testWidgets('opens nothing until the saved session has been read', (
      tester,
    ) async {
      final auth = _FakeAuth(restored: false);
      final pushes = _PushCounter();
      final app = await _pumpApp(tester, auth: auth, observer: pushes);
      final before = pushes.count;

      app.links.handle(appLink);
      await tester.pumpAndSettle();
      expect(pushes.count, before);

      // The saved session turns out to be a signed-in volunteer.
      auth.settle(restored: true, signedIn: true);
      await tester.pumpAndSettle();

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(pushes.count, before + 1);
    });

    testWidgets('a guest who backs out drops the link', (tester) async {
      final auth = _FakeAuth();
      final app = await _pumpApp(tester, auth: auth);
      app.links.handle(appLink);
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      auth.settle(signedIn: true);
      await tester.pumpAndSettle();

      expect(app.links.pendingEventId, isNull);
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.text('Sign-in screen'), findsOneWidget);
    });
  });

  group('PublicEventScreen', () {
    Future<void> showGuestView(WidgetTester tester, EventModel drive) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<EventService>.value(
          value: _FakeEvents(drive),
          child: const MaterialApp(home: PublicEventScreen(eventId: id)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a live drive, its minimum age and "Sign in to apply"', (
      tester,
    ) async {
      await showGuestView(tester, _drive(minAge: 18));

      expect(find.text('Lake clean-up'), findsOneWidget);
      expect(find.text('Ulsoor Lake, Bengaluru'), findsOneWidget);
      expect(find.text('Minimum age: 18+'), findsOneWidget);
      expect(find.text('7 of 10 places left'), findsOneWidget);
      expect(find.text('Sign in to apply'), findsOneWidget);
    });

    testWidgets('says a cancelled drive is not available', (tester) async {
      await showGuestView(tester, _drive(status: 'CANCELLED'));

      expect(find.textContaining('not available'), findsOneWidget);
      expect(find.text('Lake clean-up'), findsNothing);
      expect(find.text('Sign in to apply'), findsNothing);
    });

    testWidgets('says a drive the server will not share is not available', (
      tester,
    ) async {
      await showGuestView(tester, _drive(shareable: false));

      expect(find.textContaining('not available'), findsOneWidget);
      expect(find.text('Lake clean-up'), findsNothing);
      expect(find.text('Sign in to apply'), findsNothing);
    });

    testWidgets('shows an ended drive without "Sign in to apply"', (
      tester,
    ) async {
      await showGuestView(
        tester,
        _drive(status: 'COMPLETED', startsIn: const Duration(days: -2)),
      );

      expect(find.text('Lake clean-up'), findsOneWidget);
      expect(find.text('This drive has ended'), findsOneWidget);
      expect(find.text('Sign in to apply'), findsNothing);
    });
  });
}

/// A drive as `GET /events/:id` returns it: 3 of 10 places taken, starting
/// [startsIn] from now and lasting three hours.
EventModel _drive({
  String status = 'ACTIVE',
  bool shareable = true,
  int minAge = 16,
  Duration startsIn = const Duration(days: 2),
}) {
  final start = DateTime.now().add(startsIn);
  return EventModel(
    id: id,
    title: 'Lake clean-up',
    description: 'Bring gloves and water.',
    category: 'Environment',
    address: 'Ulsoor Lake, Bengaluru',
    isOnline: false,
    startTime: start,
    endTime: start.add(const Duration(hours: 3)),
    volunteersNeeded: 10,
    minAge: minAge,
    isPaid: false,
    status: status,
    organizerName: 'Asha Rao',
    organizerEmail: '',
    organizerId: 'organizer-1',
    approvedCount: 3,
    isOrganizerVerified: false,
    shareUrl: shareable ? 'https://api.example.org/p/e/$id' : null,
    shareUrlProvided: true,
  );
}

/// Signed out, with the saved session already read unless [restored] says
/// otherwise. [settle] stands in for `_loadSession` or `verifyOtp` finishing.
class _FakeAuth extends AuthService {
  _FakeAuth({this.restored = true});

  bool restored;
  bool signedIn = false;

  void settle({bool? restored, bool? signedIn}) {
    if (restored != null) this.restored = restored;
    if (signedIn != null) this.signedIn = signedIn;
    notifyListeners();
  }

  @override
  bool get sessionRestored => restored;

  @override
  bool get isLoading => false;

  @override
  String? get token => signedIn ? 'token' : null;

  @override
  UserInfo? get currentUser => signedIn
      ? UserInfo(
          id: 'volunteer-1',
          email: 'meera@example.org',
          fullName: 'Meera Nair',
          userType: 'VOLUNTEER',
          isVerified: false,
        )
      : null;

  @override
  bool get isAuthenticated => signedIn;

  @override
  Future<void> fetchMe() async {}
}

class _FakeEvents extends EventService {
  _FakeEvents(this.drive);

  final EventModel drive;

  @override
  Future<EventModel?> fetchEventById(String id) async => drive;

  @override
  Future<void> fetchUserApplications(String token) async {}
}

class _PushCounter extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}

/// The app as `main.dart` wires it, with "Sign-in screen" as the first route.
Future<({DeepLinkService links, GlobalKey<NavigatorState> navigator})> _pumpApp(
  WidgetTester tester, {
  required _FakeAuth auth,
  NavigatorObserver? observer,
}) async {
  final links = DeepLinkService();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<EventService>.value(
          value: _FakeEvents(_drive()),
        ),
        ChangeNotifierProvider<DeepLinkService>.value(value: links),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [?observer],
        builder: (context, child) =>
            DeepLinkHost(navigatorKey: navigator, child: child!),
        home: const Scaffold(body: Text('Sign-in screen')),
      ),
    ),
  );
  return (links: links, navigator: navigator);
}
