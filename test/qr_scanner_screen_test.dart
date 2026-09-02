import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile_app/screens/qr_scanner_screen.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';
import 'package:volunteer_mobile_app/services/attendance_service.dart';

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
        ],
        child: const MaterialApp(home: QrScannerScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Align QR Pass within the frame'), findsOneWidget);
    expect(find.text('Development Verification Panel'), findsOneWidget);
    expect(find.text('Verify Scanned Token'), findsOneWidget);
  });

  testWidgets(
    'Simulating manual token input successfully submits and opens Dialog',
    (WidgetTester tester) async {
      // Mock permission status as Granted (1)
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

      final mockAuth = MockAuthService();
      final mockAttendance = MockAttendanceService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<AttendanceService>.value(
              value: mockAttendance,
            ),
          ],
          child: const MaterialApp(home: QrScannerScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'mock-pass-token-string');
      await tester.tap(find.text('Verify Scanned Token'));
      await tester.pump(); // Starts loading state

      expect(mockAttendance.verifyScannedPassCalled, true);
      expect(mockAttendance.lastPassedToken, 'mock-pass-token-string');

      await tester.pumpAndSettle(); // Finishes async call and renders Dialog

      expect(find.text('Check-In Success'), findsOneWidget);
      expect(find.text('Successfully checked in Mock User'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Tap OK to close dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Check-In Success'), findsNothing);
    },
  );
}
