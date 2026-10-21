import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile_app/screens/register_screen.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';

/// ISS-007. Registration must carry a date of birth and explicit consent.
class _RecordingAuthService extends AuthService {
  int registerCalls = 0;

  @override
  Future<Map<String, dynamic>> register({
    required String email,
    String? phoneNumber,
    required String fullName,
    required DateTime dateOfBirth,
    required bool acceptTerms,
  }) async {
    registerCalls++;
    return {'success': false, 'message': 'stub'};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('register sends dateOfBirth as YYYY-MM-DD and acceptTerms', () async {
    late Map<String, dynamic> sentBody;
    late Uri sentUri;
    final client = MockClient((request) async {
      sentUri = request.url;
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'message': 'ok'}), 201);
    });

    final result = await http.runWithClient(() async {
      final auth = AuthService();
      return auth.register(
        email: 'asha@example.org',
        fullName: 'Asha Rao',
        dateOfBirth: DateTime(2008, 5, 1),
        acceptTerms: true,
      );
    }, () => client);

    expect(result['success'], isTrue);
    expect(sentUri.path, '/auth/register');
    expect(sentBody['dateOfBirth'], '2008-05-01');
    expect(sentBody['acceptTerms'], isTrue);
    expect(sentBody['email'], 'asha@example.org');
    expect(sentBody.containsKey('userType'), isFalse);
  });

  test('register surfaces the server age refusal', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'statusCode': 400,
          'message': 'You must be at least 16 years old to join Voluntree.',
          'error': 'Bad Request',
        }),
        400,
      ),
    );

    final result = await http.runWithClient(
      () => AuthService().register(
        email: 'kid@example.org',
        fullName: 'Kid',
        dateOfBirth: DateTime(2015, 1, 1),
        acceptTerms: true,
      ),
      () => client,
    );

    expect(result['success'], isFalse);
    expect(
      result['message'],
      'You must be at least 16 years old to join Voluntree.',
    );
  });

  testWidgets('Register screen requires a date of birth and consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = _RecordingAuthService();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Asha Rao');
    await tester.enterText(fields.at(1), 'asha@example.org');

    await tester.tap(find.text('Sign Up Now'));
    await tester.pump();

    expect(auth.registerCalls, 0);
    expect(find.text('Please add your date of birth.'), findsOneWidget);
    expect(
      find.text(
        'Please accept the Terms of Service and Privacy Policy to continue.',
      ),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
