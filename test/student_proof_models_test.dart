import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile_app/services/attendance_service.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('UserProfile reads the student-proof fields', () {
    final profile = UserProfile.fromJson({
      'id': 'p1',
      'skills': <String>[],
      'interests': <String>[],
      'availability': <String>[],
      'institution': 'Riverside College',
      'studentId': 'R-1024',
      'publicProfile': true,
      'publicSlug': 'ada-lovelace',
    });

    expect(profile.institution, 'Riverside College');
    expect(profile.studentId, 'R-1024');
    expect(profile.publicProfile, isTrue);
    expect(profile.publicSlug, 'ada-lovelace');
  });

  test('UserProfile defaults the student-proof fields when absent', () {
    final profile = UserProfile.fromJson({
      'id': 'p1',
      'skills': <String>[],
      'interests': <String>[],
      'availability': <String>[],
      'publicProfile': 'yes',
    });

    expect(profile.institution, isNull);
    expect(profile.studentId, isNull);
    expect(profile.publicProfile, isFalse);
    expect(profile.publicSlug, isNull);
  });

  test('UserInfo reads publicProfileUrl, or null when absent', () {
    final withUrl = UserInfo.fromJson({
      'id': 'u1',
      'email': 'a@example.org',
      'fullName': 'Ada',
      'publicProfileUrl': 'https://api.example.org/p/ada-lovelace',
    });
    final withoutUrl = UserInfo.fromJson({
      'id': 'u1',
      'email': 'a@example.org',
      'fullName': 'Ada',
      'publicProfileUrl': null,
    });

    expect(withUrl.publicProfileUrl, 'https://api.example.org/p/ada-lovelace');
    expect(withoutUrl.publicProfileUrl, isNull);
    expect(UserInfo.fromJson({'id': 'u1'}).publicProfileUrl, isNull);
  });

  test('CompletedDrive reads certificate code and url', () {
    final drive = CompletedDrive.fromJson({
      'id': 'a1',
      'eventId': 'e1',
      'checkIn': '2026-10-04T09:00:00.000Z',
      'hoursLogged': 3.5,
      'certificateCode': 'CERT-7H2K',
      'certificateUrl': 'https://api.example.org/p/c/CERT-7H2K',
    });

    expect(drive.certificateCode, 'CERT-7H2K');
    expect(drive.certificateUrl, 'https://api.example.org/p/c/CERT-7H2K');
  });

  test('CompletedDrive has no certificate when the fields are absent', () {
    final drive = CompletedDrive.fromJson({
      'id': 'a1',
      'eventId': 'e1',
      'checkIn': '2026-10-04T09:00:00.000Z',
      'hoursLogged': 0,
    });

    expect(drive.certificateCode, isNull);
    expect(drive.certificateUrl, isNull);
  });

  group('downloadHoursReport', () {
    test('requests the report with the dates and bearer token', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes([0x25, 0x50, 0x44, 0x46], 200);
      });

      final result = await http.runWithClient(
        () => AttendanceService().downloadHoursReport(
          'token-123',
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ),
        () => client,
      );

      expect(sent.url.path, '/attendance/report');
      expect(sent.url.queryParameters['from'], '2026-10-01');
      expect(sent.url.queryParameters['to'], '2026-10-31');
      expect(sent.headers['Authorization'], 'Bearer token-123');
      expect(result.error, isNull);
      expect(result.bytes, [0x25, 0x50, 0x44, 0x46]);
    });

    test('surfaces the server message on a 400', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'message': "The end date can't be in the future."}),
          400,
        ),
      );

      final result = await http.runWithClient(
        () => AttendanceService().downloadHoursReport(
          'token',
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ),
        () => client,
      );

      expect(result.bytes, isNull);
      expect(result.error, "The end date can't be in the future.");
    });

    test('returns a friendly message when the network fails', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      );

      final result = await http.runWithClient(
        () => AttendanceService().downloadHoursReport(
          'token',
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ),
        () => client,
      );

      expect(result.bytes, isNull);
      expect(
        result.error,
        'You appear to be offline. Check your connection and try again.',
      );
    });
  });

  test(
    'updateProfile sends the student-proof fields only when provided',
    () async {
      SharedPreferences.setMockInitialValues({'access_token': 'token-abc'});
      final puts = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.url.path == '/auth/me') {
          return http.Response(
            jsonEncode({
              'id': 'u1',
              'email': 'a@example.org',
              'fullName': 'Ada',
            }),
            200,
          );
        }
        if (request.url.path == '/auth/profile') {
          puts.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'message': 'ok'}), 200);
        }
        return http.Response('not found', 404);
      });

      await http.runWithClient(() async {
        final auth = AuthService();
        while (!auth.sessionRestored) {
          await Future<void>.delayed(Duration.zero);
        }
        await auth.updateProfile(bio: 'Hello');
        await auth.updateProfile(
          institution: 'Riverside College',
          studentId: 'R-1024',
          publicProfile: true,
        );
      }, () => client);

      expect(puts, hasLength(2));
      expect(puts[0], {'bio': 'Hello'});
      expect(puts[1], {
        'institution': 'Riverside College',
        'studentId': 'R-1024',
        'publicProfile': true,
      });
    },
  );
}
