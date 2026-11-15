import 'deep_link.dart' show publicDriveStatuses;
import 'event_time.dart';

/// Public link for a drive, or null when the server says it is not shareable.
///
/// The server's link wins so the share domain can change without an app
/// release. Older servers do not send the field at all, so fall back to the
/// API origin; a field sent as null means the drive is hidden.
String? driveShareUrl({
  required String eventId,
  String? serverShareUrl,
  bool serverSentShareUrl = false,
  required String apiBaseUrl,
}) {
  if (serverSentShareUrl) {
    return (serverShareUrl == null || serverShareUrl.isEmpty)
        ? null
        : serverShareUrl;
  }
  return '$apiBaseUrl/p/e/$eventId';
}

/// [driveShareUrl], but null unless the drive's status is one the public page
/// serves. The detail screen can be showing a cached list model (which has no
/// `shareUrl`) of a draft or cancelled drive; those must not offer sharing.
String? shareUrlForStatus({
  required String status,
  required String eventId,
  String? serverShareUrl,
  bool serverSentShareUrl = false,
  required String apiBaseUrl,
}) {
  if (!publicDriveStatuses.contains(status)) return null;
  return driveShareUrl(
    eventId: eventId,
    serverShareUrl: serverShareUrl,
    serverSentShareUrl: serverSentShareUrl,
    apiBaseUrl: apiBaseUrl,
  );
}

String driveShareText({
  required String title,
  required String organizer,
  required DateTime start,
  required String url,
}) =>
    'Join me at "$title" by $organizer on ${formatLocalDate(start)} at '
    '${formatLocalTime(start)}. $url';

String _two(int n) => n.toString().padLeft(2, '0');

String _calendarStamp(DateTime d) {
  final u = d.toUtc();
  return '${u.year}${_two(u.month)}${_two(u.day)}T'
      '${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
}

/// Google Calendar's "add event" template.
String googleCalendarUrl({
  required String title,
  required DateTime start,
  required DateTime end,
  required String details,
  required String location,
}) => Uri.https('calendar.google.com', '/calendar/render', {
  'action': 'TEMPLATE',
  'text': title,
  'dates': '${_calendarStamp(start)}/${_calendarStamp(end)}',
  'details': details,
  'location': location,
}).toString();

/// The .ics file served next to the public page (any calendar app).
String calendarFileUrl(String shareUrl) => '$shareUrl/calendar.ics';
