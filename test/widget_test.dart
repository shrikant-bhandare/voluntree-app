import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_mobile_app/main.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';
import 'package:volunteer_mobile_app/services/chat_service.dart';
import 'package:volunteer_mobile_app/services/attendance_service.dart';
import 'package:volunteer_mobile_app/services/leaderboard_service.dart';
import 'package:volunteer_mobile_app/services/notification_service.dart';
import 'package:volunteer_mobile_app/services/report_service.dart';
import 'package:volunteer_mobile_app/services/payments_service.dart';

void main() {
  testWidgets('App starts and displays Login screen', (WidgetTester tester) async {
    // Build our app wrapped with MultiProvider and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => EventService()),
          ChangeNotifierProvider(create: (_) => ChatService()),
          ChangeNotifierProvider(create: (_) => AttendanceService()),
          ChangeNotifierProvider(create: (_) => LeaderboardService()),
          ChangeNotifierProvider(create: (_) => NotificationService()),
          ChangeNotifierProvider(create: (_) => ReportService()),
          ChangeNotifierProvider(create: (_) => PaymentsService()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the login button or fields are shown
    expect(find.text('Secure Login'), findsWidgets);
    expect(find.text('Send OTP Code'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });
}
