import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_mobile_app/screens/event_feed_screen.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';
import 'package:volunteer_mobile_app/services/posts_service.dart';

/// F7 (web QA, 24 Oct 2026). The feed started its fetches from
/// didChangeDependencies, so the services' synchronous notifyListeners()
/// fired while the tree was still building. Release builds then left the
/// Posts tab on its spinner after the fetch had finished.

class _Auth extends AuthService {
  @override
  String? get token => 'token';

  @override
  UserInfo? get currentUser => UserInfo(
    id: 'u1',
    email: 'u1@example.org',
    fullName: 'Asha Rao',
    userType: 'VOLUNTEER',
    isVerified: false,
  );

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> fetchMe() async {}
}

void main() {
  testWidgets('feed loads without notifying during build and leaves the '
      'spinner once the fetch completes', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => _Auth()),
          ChangeNotifierProvider(create: (_) => EventService()),
          ChangeNotifierProvider(create: (_) => PostsService()),
        ],
        child: const MaterialApp(home: EventFeedScreen()),
      ),
    );

    // A notifyListeners() during build is reported here in debug mode.
    expect(tester.takeException(), isNull);

    // flutter_test answers every HTTP request with 400, which the service
    // treats as "no posts". The fetch must end in the empty state.
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No moments posted yet!'), findsOneWidget);
  });
}
