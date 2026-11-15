import 'event_time.dart';

/// Public Impact profiles are for adults only (master plan D3).
bool canHavePublicProfile(DateTime? dateOfBirth, {DateTime? now}) =>
    dateOfBirth != null && ageOn(dateOfBirth, now ?? DateTime.now()) >= 18;

/// LinkedIn's "Add to profile" form for one certificate.
String linkedInCertificationUrl({
  required String driveTitle,
  required DateTime issuedOn,
  required String certUrl,
  required String certId,
}) => Uri.https('www.linkedin.com', '/profile/add', {
  'startTask': 'CERTIFICATION_NAME',
  'name': 'Volunteer: $driveTitle',
  'organizationName': 'Voluntree',
  'issueYear': '${issuedOn.year}',
  'issueMonth': '${issuedOn.month}',
  'certUrl': certUrl,
  'certId': certId,
}).toString();

/// Public certificate page as the server reports it, or null when the server
/// predates the page. No fallback: a guessed URL would hand LinkedIn a dead
/// link (D11), so the screen shows "Add to LinkedIn" only when this is non-null.
String? certificatePageUrl({String? serverUrl}) =>
    (serverUrl != null && serverUrl.isNotEmpty) ? serverUrl : null;

String hoursReportFileName(DateTime from, DateTime to) =>
    'voluntree-hours-${formatCalendarDate(from)}-to-${formatCalendarDate(to)}.pdf';

/// The academic year so far (from 1 June), which is what colleges usually ask for.
(DateTime, DateTime) defaultReportRange(DateTime now) {
  final startYear = now.month >= 6 ? now.year : now.year - 1;
  return (DateTime(startYear, 6, 1), DateTime(now.year, now.month, now.day));
}
