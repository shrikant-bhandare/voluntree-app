import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/brand.dart';
import 'widgets/voluntree_logo.dart';
import 'widgets/responsive.dart';
import 'services/auth_service.dart';
import 'services/event_service.dart';
import 'services/chat_service.dart';
import 'services/attendance_service.dart';
import 'services/leaderboard_service.dart';
import 'services/notification_service.dart';
import 'services/report_service.dart';
import 'services/payments_service.dart';
import 'services/posts_service.dart';
import 'services/category_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Force the semantics tree on. Off unless a build passes
/// `--dart-define=ENABLE_SEMANTICS=true`, so production is unaffected.
///
/// On the web Flutter only builds the semantics tree after the user activates
/// the "Enable accessibility" affordance, which needs a real user gesture.
/// That leaves automated UI checks with nothing to address on a canvas-rendered
/// page. Turning it on for test builds also makes the app auditable with
/// ordinary accessibility tooling.
const bool _forceSemantics = bool.fromEnvironment('ENABLE_SEMANTICS');

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  if (_forceSemantics) {
    binding.ensureSemantics();
  }

  // Firebase web needs its own generated options + a messaging service
  // worker; neither is configured, so the web build relies on the in-app
  // socket notifications instead of FCM push.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final fcmToken = await messaging.getToken();
      debugPrint('[MAIN] Device FCM Token: $fcmToken');
    } catch (e) {
      debugPrint('[MAIN] Firebase initialization offline/skipped: $e');
    }
  }

  runApp(
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
        ChangeNotifierProvider(create: (_) => PostsService()),
        ChangeNotifierProvider(create: (_) => CategoryService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voluntree',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // If still loading session token validation, show loading screen
    if (authService.isLoading &&
        authService.token != null &&
        authService.currentUser == null) {
      // Restoring a saved session: the brand, not a bare spinner.
      return const Scaffold(
        backgroundColor: Brand.mist,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VoluntreeBadge(size: 88),
              SizedBox(height: 24),
              VoluntreeWordmark(fontSize: 30),
              SizedBox(height: 32),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authService.isAuthenticated) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
