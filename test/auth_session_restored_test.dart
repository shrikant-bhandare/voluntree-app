import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';

/// Shared links and push taps wait on sessionRestored, so it must flip (and
/// notify) however the saved session turns out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> untilRestored(AuthService auth) async {
    for (var i = 0; i < 600 && !auth.sessionRestored; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('with no saved session it flips and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    expect(auth.sessionRestored, isFalse);
    var notified = 0;
    auth.addListener(() => notified++);

    await untilRestored(auth);

    expect(auth.sessionRestored, isTrue);
    expect(auth.isAuthenticated, isFalse);
    expect(notified, greaterThan(0));
  });

  test(
    'with a saved token it flips after the check, even when the check fails',
    () async {
      SharedPreferences.setMockInitialValues({'access_token': 'saved'});
      final auth = AuthService();
      var restoredAtLastNotify = false;
      var notified = 0;
      auth.addListener(() {
        notified++;
        restoredAtLastNotify = auth.sessionRestored;
      });

      await untilRestored(auth);

      expect(auth.sessionRestored, isTrue);
      expect(auth.isLoading, isFalse);
      expect(notified, greaterThan(1)); // loading state, then restored
      expect(restoredAtLastNotify, isTrue);
    },
  );
}
