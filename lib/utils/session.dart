import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';
import '../services/payments_service.dart';
import '../services/posts_service.dart';
import '../services/sso_service.dart';

/// Ends the session on this device: drops every service cache (so the next
/// account does not see the previous user's data), signs out of Google, and
/// clears the stored token. AuthGate then shows the login screen.
Future<void> endSession(BuildContext context) async {
  Provider.of<ChatService>(context, listen: false)
    ..disconnectSocket()
    ..clear();
  Provider.of<NotificationService>(context, listen: false).clear();
  Provider.of<EventService>(context, listen: false).clear();
  Provider.of<AttendanceService>(context, listen: false).clear();
  Provider.of<PaymentsService>(context, listen: false).clear();
  Provider.of<PostsService>(context, listen: false).clear();
  final auth = Provider.of<AuthService>(context, listen: false);
  // SSO is native-only; on the web build Firebase is never initialised.
  if (!kIsWeb) {
    try {
      await SsoService.signOut();
    } catch (_) {
      // Not signed in with Google, or Firebase is not configured.
    }
  }
  await auth.logout();
}
