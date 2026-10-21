import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile_app/screens/qr_scanner_screen.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';
import 'package:volunteer_mobile_app/services/attendance_service.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';

class MockAuthService extends AuthService {
  MockAuthService() : super();

  @override
  String? get token => 'mock-token';

  @override
  UserInfo? get currentUser => UserInfo(
    id: 'mock-user-id',
    email: 'test@mock.com',
    fullName: 'Mock User',
    userType: 'ORGANIZER',
    isVerified: true,
  );

  @override
  bool get isAuthenticated => true;
}

class MockAttendanceService extends AttendanceService {
  MockAttendanceService() : super();

  bool verifyScannedPassCalled = false;
  String? lastPassedToken;
  Map<String, dynamic> resultToReturn = {
    'success': true,
    'type': 'CHECK_IN',
    'message': 'Successfully checked in Mock User',
    'time': '2026-07-07T12:00:00Z',
  };

  @override
  Future<Map<String, dynamic>> verifyScannedPass(
    String token,
    String passToken,
  ) async {
    verifyScannedPassCalled = true;
    lastPassedToken = passToken;
    return resultToReturn;
  }
}

class MockEventService extends EventService {
  @override
  bool get hasLoadedMyEvents => true;

  @override
  List<EventModel> get myEvents => [
    EventModel.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'title': 'Beach clean-up',
      'status': 'ACTIVE',
      'startTime': '2026-11-01T03:30:00.000Z',
      'endTime': '2026-11-01T08:30:00.000Z',
    }),
    EventModel.fromJson({
      'id': '22222222-2222-2222-2222-222222222222',
      'title': 'Old drive',
      'status': 'COMPLETED',
      'startTime': '2026-01-01T03:30:00.000Z',
      'endTime': '2026-01-01T08:30:00.000Z',
    }),
  ];

  @override
  Future<void> fetchMyEvents(String token) async {}
}

class MockPassCodeAttendanceService extends MockAttendanceService {
  String? lastEventId;
  String? lastPassCode;

  @override
  Future<Map<String, dynamic>> verifyPassCode(
    String token, {
    required String eventId,
    required String passCode,
  }) async {
    lastEventId = eventId;
    lastPassCode = passCode;
    return resultToReturn;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
  });

  testWidgets(
    'Renders Permission Denied Screen when Camera Permission is Denied',
    (WidgetTester tester) async {
      // Mock permission status as Denied (0)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'checkPermissionStatus') {
                return 0; // Denied
              } else if (methodCall.method == 'requestPermissions') {
                return {
                  1: 0, // Camera (1) is Denied (0)
                };
              }
              return null;
            },
          );

      final mockAuth = MockAuthService();
      final mockAttendance = MockAttendanceService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<AttendanceService>.value(
              value: mockAttendance,
            ),
            ChangeNotifierProvider<EventService>.value(
              value: MockEventService(),
            ),
          ],
          child: const MaterialApp(home: QrScannerScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Camera Access Required'), findsOneWidget);
      expect(
        find.text('Please enable camera access to scan QR passes.'),
        findsOneWidget,
      );
      expect(find.text('Grant Access'), findsOneWidget);
    },
  );

  testWidgets('Renders Scanner View when Camera Permission is Granted', (
    WidgetTester tester,
  ) async {
    // Mock permission status as Granted (1)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'checkPermissionStatus') {
              return 1; // Granted
            } else if (methodCall.method == 'requestPermissions') {
              return {
                1: 1, // Camera (1) is Granted (1)
              };
            }
            return null;
          },
        );

    final mockAuth = MockAuthService();
    final mockAttendance = MockAttendanceService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuth),
          ChangeNotifierProvider<AttendanceService>.value(
            value: mockAttendance,
          ),
          ChangeNotifierProvider<EventService>.value(value: MockEventService()),
        ],
        child: const MaterialApp(home: QrScannerScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Align QR Pass within the frame'), findsOneWidget);
    // Production copy for the manual fallback (MOB-24).
    expect(find.text('Development Verification Panel'), findsNothing);
    expect(find.text('Enter pass code'), findsOneWidget);
    expect(find.text('Check in or out'), findsOneWidget);
  });

  testWidgets(
    'Manual pass code entry sends the chosen drive and code, opens Dialog',
    (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'checkPermissionStatus') {
                return 1; // Granted
              }
              return null;
            },
          );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final mockAuth = MockAuthService();
      final mockAttendance = MockPassCodeAttendanceService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<AttendanceService>.value(
              value: mockAttendance,
            ),
            ChangeNotifierProvider<EventService>.value(
              value: MockEventService(),
            ),
          ],
          child: const MaterialApp(home: QrScannerScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Only live drives are offered; with one, it is preselected.
      expect(find.textContaining('Beach clean-up'), findsOneWidget);
      expect(find.textContaining('Old drive'), findsNothing);

      final codeField = find.byType(TextField);
      expect(codeField, findsOneWidget);

      // Too short: refused client-side, nothing sent.
      await tester.enterText(codeField, 'K7QM');
      await tester.tap(find.text('Check in or out'));
      await tester.pump();
      expect(mockAttendance.lastPassCode, isNull);
      expect(find.textContaining('Enter the 8-character code'), findsOneWidget);

      await tester.enterText(codeField, 'k7qm-2xpa');
      await tester.tap(find.text('Check in or out'));
      await tester.pump();

      expect(
        mockAttendance.lastEventId,
        '11111111-1111-1111-1111-111111111111',
      );
      expect(mockAttendance.lastPassCode, 'K7QM2XPA');

      await tester.pumpAndSettle();

      expect(find.text('Check-In Success'), findsOneWidget);
      expect(find.text('Successfully checked in Mock User'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Check-In Success'), findsNothing);
    },
  );
}
