import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile_app/config.dart';
import 'package:volunteer_mobile_app/screens/home_screen.dart';
import 'package:volunteer_mobile_app/services/attendance_service.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';
import 'package:volunteer_mobile_app/services/category_service.dart';
import 'package:volunteer_mobile_app/services/chat_service.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';
import 'package:volunteer_mobile_app/services/leaderboard_service.dart';
import 'package:volunteer_mobile_app/services/notification_service.dart';
import 'package:volunteer_mobile_app/services/payments_service.dart';
import 'package:volunteer_mobile_app/services/posts_service.dart';
import 'package:volunteer_mobile_app/services/report_service.dart';

/// ISS-013. Payments are not integrated; without
/// `--dart-define=PAYMENTS_ENABLED=true` no entry point may be shown.

class _Auth extends AuthService {
  final String role;
  _Auth(this.role);

  @override
  String? get token => 'token';

  @override
  UserInfo? get currentUser => UserInfo(
    id: 'u1',
    email: 'u1@example.org',
    fullName: 'Asha Rao',
    userType: role,
    isVerified: true,
  );

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> fetchMe() async {}
}

class _Chat extends ChatService {
  @override
  void initSocket(String token) {}

  @override
  Future<void> fetchConversations(String token) async {}

  @override
  void disconnectSocket() {}
}

class _Notifications extends NotificationService {
  @override
  Future<void> fetchNotifications(String token) async {}
}

class _Events extends EventService {
  @override
  bool get hasLoadedMyEvents => true;

  @override
  bool get hasLoadedEvents => true;

  @override
  Future<void> fetchEvents({
    String? category,
    String? search,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {}

  @override
  Future<void> fetchMyEvents(String token) async {}

  @override
  Future<void> fetchUserApplications(String token) async {}

  @override
  Future<void> fetchOrganizerApplications(String token) async {}

  @override
  Future<void> fetchOrganizerAnalytics(String token) async {}
}

class _Attendance extends AttendanceService {
  @override
  Future<void> fetchHistory(String token) async {}
}

class _Categories extends CategoryService {
  @override
  Future<void> ensureLoaded() async {}
}

class _Posts extends PostsService {
  @override
  Future<void> fetchPosts(String token) async {}
}

Future<void> _pumpHome(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: _Auth(role)),
        ChangeNotifierProvider<EventService>.value(value: _Events()),
        ChangeNotifierProvider<ChatService>.value(value: _Chat()),
        ChangeNotifierProvider<AttendanceService>.value(value: _Attendance()),
        ChangeNotifierProvider(create: (_) => LeaderboardService()),
        ChangeNotifierProvider<NotificationService>.value(
          value: _Notifications(),
        ),
        ChangeNotifierProvider(create: (_) => ReportService()),
        ChangeNotifierProvider(create: (_) => PaymentsService()),
        ChangeNotifierProvider<PostsService>.value(value: _Posts()),
        ChangeNotifierProvider<CategoryService>.value(value: _Categories()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('payments are off unless the build enables them', () {
    expect(AppConfig.paymentsEnabled, isFalse);
  });

  testWidgets('volunteer: no Sponsor & Donate entry or Sponsor quick action', (
    tester,
  ) async {
    await _pumpHome(tester, 'VOLUNTEER');

    expect(find.text('Sponsor'), findsNothing);

    await _openDrawer(tester);
    expect(find.text('Sponsor & Donate'), findsNothing);
    // The account entry is still there (ISS-008).
    expect(find.text('Account & privacy'), findsOneWidget);
  });

  testWidgets('organizer: no NGO Subscriptions entry; Edit Profile present', (
    tester,
  ) async {
    await _pumpHome(tester, 'ORGANIZER');

    await _openDrawer(tester);
    expect(find.text('NGO Subscriptions'), findsNothing);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Account & privacy'), findsOneWidget);
  });
}
