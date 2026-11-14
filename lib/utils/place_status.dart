import '../services/api_helpers.dart';
import 'drive_cta.dart';
import 'event_time.dart';

/// What the "My drives" card shows for an approved place.
enum PlacePrompt {
  /// Nothing (not approved, the drive is not running, or it has started).
  none,

  /// More than [placePromptWindow] ahead and not answered yet: show the
  /// start and only offer "Can't make it".
  cancelOnly,

  /// The drive starts within [placePromptWindow]: ask "still coming?".
  askToConfirm,

  /// The volunteer already said yes.
  confirmed,
}

/// How far ahead of the start the card begins asking.
const Duration placePromptWindow = Duration(hours: 48);

/// Cancelling inside this window is shown to the organizer as late.
const Duration lateCancellationWindow = Duration(hours: 24);

/// Decides what the "My drives" card shows for [application], a row from
/// `GET /applications/my`:
///
/// * [PlacePrompt.none]: not an approved place, no readable drive or start
///   time, a drive that is not running (the server refuses confirm and
///   cancel then), or a drive that has already started.
/// * [PlacePrompt.confirmed]: the volunteer already said yes, however far
///   ahead the drive is. "Can't make it" stays available.
/// * [PlacePrompt.cancelOnly]: more than [placePromptWindow] before the start
///   and not answered. Too early to ask, but an approved volunteer can give
///   up their place at any time before the start.
/// * [PlacePrompt.askToConfirm]: within [placePromptWindow] of the start and
///   not answered: "Still coming?" with Yes and "Can't make it".
PlacePrompt placePromptFor(Map<String, dynamic> application, {DateTime? now}) {
  if (application['status'] != 'APPROVED') return PlacePrompt.none;
  final event = application['event'];
  if (event is! Map) return PlacePrompt.none;
  // The server refuses confirm/cancel on a drive that is not running.
  if (!liveDriveStatuses.contains(event['status'])) return PlacePrompt.none;
  final start = parseServerDateOrNull(event['startTime']);
  if (start == null) return PlacePrompt.none;

  final clock = now ?? DateTime.now();
  if (!start.isAfter(clock)) return PlacePrompt.none;
  if (application['confirmedAt'] != null) return PlacePrompt.confirmed;
  if (start.difference(clock) > placePromptWindow) {
    return PlacePrompt.cancelOnly;
  }
  return PlacePrompt.askToConfirm;
}

/// "today at 09:30", "tomorrow at 09:30" or "on 16/11/2026 at 09:30",
/// in the device's zone.
String placeStartsLabel(DateTime start, {DateTime? now}) {
  final s = start.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final startDay = DateTime(s.year, s.month, s.day);
  final today = DateTime(n.year, n.month, n.day);
  // Round rather than inDays: a DST change makes a day 23 or 25 hours.
  final days = (startDay.difference(today).inHours / 24).round();
  final time = formatLocalTime(s);
  if (days == 0) return 'today at $time';
  if (days == 1) return 'tomorrow at $time';
  return 'on ${formatLocalDate(s)} at $time';
}

bool isLateCancellation(DateTime startTime, {DateTime? now}) =>
    startTime.difference(now ?? DateTime.now()) < lateCancellationWindow;

/// Short label for an application status in lists. Unknown values from a
/// newer server fall back to "Applied" instead of showing a raw code.
String applicationStatusLabel(String? status) {
  switch (status) {
    case 'PENDING':
      return 'Pending';
    case 'UNDER_REVIEW':
      return 'In review';
    case 'APPROVED':
      return 'Approved';
    case 'REJECTED':
      return 'Declined';
    case 'WAITLISTED':
      return 'Waitlisted';
    case 'CANCELLED':
      return 'Cancelled';
    default:
      return 'Applied';
  }
}

/// The organizer's headcount for one drive.
class RosterSummary {
  final int approved;
  final int confirmed;
  final int notReplied;
  final int cancelled;
  final int waitlisted;

  const RosterSummary({
    required this.approved,
    required this.confirmed,
    required this.notReplied,
    required this.cancelled,
    required this.waitlisted,
  });
}

RosterSummary rosterSummary(List<dynamic> applications) {
  var approved = 0, confirmed = 0, cancelled = 0, waitlisted = 0;
  for (final row in applications) {
    if (row is! Map) continue;
    switch (row['status']) {
      case 'APPROVED':
        approved++;
        if (row['confirmedAt'] != null) confirmed++;
      case 'CANCELLED':
        cancelled++;
      case 'WAITLISTED':
        waitlisted++;
    }
  }
  return RosterSummary(
    approved: approved,
    confirmed: confirmed,
    notReplied: approved - confirmed,
    cancelled: cancelled,
    waitlisted: waitlisted,
  );
}
