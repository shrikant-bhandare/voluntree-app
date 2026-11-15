import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/student_proof.dart';

void main() {
  final now = DateTime(2026, 11, 14);

  test('public profiles are for adults with a date of birth', () {
    expect(canHavePublicProfile(DateTime(2008, 11, 14), now: now), isTrue);
    expect(canHavePublicProfile(DateTime(2008, 11, 15), now: now), isFalse);
    expect(canHavePublicProfile(null, now: now), isFalse);
  });

  test('LinkedIn link fills the certification form', () {
    final url = Uri.parse(
      linkedInCertificationUrl(
        driveTitle: 'Lake Cleanup',
        issuedOn: DateTime(2026, 10, 4),
        certUrl: 'https://api.example.org/p/c/abc',
        certId: 'abc',
      ),
    );
    expect(url.host, 'www.linkedin.com');
    expect(url.path, '/profile/add');
    expect(url.queryParameters['startTask'], 'CERTIFICATION_NAME');
    expect(url.queryParameters['name'], 'Volunteer: Lake Cleanup');
    expect(url.queryParameters['organizationName'], 'Voluntree');
    expect(url.queryParameters['issueYear'], '2026');
    expect(url.queryParameters['issueMonth'], '10');
    expect(url.queryParameters['certUrl'], 'https://api.example.org/p/c/abc');
    expect(url.queryParameters['certId'], 'abc');
  });

  test('certificate page link is the server link, or null when absent', () {
    expect(
      certificatePageUrl(serverUrl: 'https://voluntree.example/p/c/abc'),
      'https://voluntree.example/p/c/abc',
    );
    expect(certificatePageUrl(serverUrl: ''), isNull);
    expect(certificatePageUrl(), isNull);
  });

  test('report file name and default academic-year range', () {
    expect(
      hoursReportFileName(DateTime(2026, 6, 1), DateTime(2026, 11, 14)),
      'voluntree-hours-2026-06-01-to-2026-11-14.pdf',
    );
    expect(defaultReportRange(now), (
      DateTime(2026, 6, 1),
      DateTime(2026, 11, 14),
    ));
    expect(defaultReportRange(DateTime(2027, 3, 2)), (
      DateTime(2026, 6, 1),
      DateTime(2027, 3, 2),
    ));
  });
}
