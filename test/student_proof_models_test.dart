import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/attendance_service.dart';
import 'package:volunteer_mobile_app/services/auth_service.dart';

void main() {
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
      'certificateUrl': '/attendance/certificate/a1',
    });

    expect(drive.certificateCode, 'CERT-7H2K');
    expect(drive.certificateUrl, '/attendance/certificate/a1');
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

  test('downloadHoursReport surfaces the server message on a 400', () async {
    // flutter_test replaces HttpClient with a stub that answers 400 to every
    // request; clear it so this test reaches the real loopback server.
    HttpOverrides.global = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'message': "The end date can't be in the future."}))
        ..close();
    });

    final result = await AttendanceService().downloadHoursReport(
      'token',
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );

    expect(result.bytes, isNull);
    expect(result.error, "The end date can't be in the future.");
  });
}
