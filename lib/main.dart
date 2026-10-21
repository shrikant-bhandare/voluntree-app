import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final lightTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    );

    return MaterialApp(
      title: 'Voluntree',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(
          0xFFF4FAFD,
        ), // Soft green-blue tint
        primaryColor: const Color(0xFF012D1D), // Forest Green
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF012D1D),
          primaryContainer: Color(0xFF1B4332),
          secondary: Color(0xFF0E6C4A),
          secondaryContainer: Color(0xFFA0F4C8),
          surface: Color(0xFFFFFFFF),
          surfaceContainer: Color(0xFFE8EFF1),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF161D1F),
          error: Color(0xFFBA1A1A),
        ),
        textTheme: lightTextTheme.copyWith(
          displayLarge: GoogleFonts.plusJakartaSans(
            textStyle: lightTextTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF012D1D),
            ),
          ),
          headlineMedium: GoogleFonts.plusJakartaSans(
            textStyle: lightTextTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF012D1D),
            ),
          ),
          bodyMedium: GoogleFonts.plusJakartaSans(
            textStyle: lightTextTheme.bodyMedium?.copyWith(
              color: const Color(0xFF161D1F),
            ),
          ),
        ),
        useMaterial3: true,
      ),
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
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
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
