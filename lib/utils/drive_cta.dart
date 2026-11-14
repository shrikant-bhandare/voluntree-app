import 'event_time.dart';
import 'place_status.dart';

/// What the call-to-action on a drive card should say for the signed-in
/// volunteer.
///
/// The featured-drive cards used to offer "Join" unconditionally, so a drive
/// the volunteer had already applied to looked untouched until they opened it.
/// Keeping the decision here — rather than inline in the card — means the
/// listing and the detail screen cannot drift apart.
class DriveCta {
  final String label;
  final bool isApplied;

  const DriveCta(this.label, this.isApplied);
}

const DriveCta _join = DriveCta('Join', false);

/// Resolve the CTA for [eventId] against the volunteer's applications.
///
/// [userApplications] is decoded JSON straight off `GET /applications/my`, so
/// it is deliberately tolerant: unexpected rows are skipped rather than thrown
/// on, and an unrecognised status still reports that an application exists.
DriveCta driveCtaFor({
  required String eventId,
  required List<dynamic> userApplications,
}) {
  for (final row in userApplications) {
    if (row is! Map) continue;
    if (row['eventId'] != eventId) continue;

    final status = row['status'];
    // A cancelled place can be applied for again.
    if (status == 'CANCELLED') return _join;
    return DriveCta(applicationStatusLabel(status), true);
  }

  return _join;
}

/// Drive statuses that accept new applications directly. A FULL drive also
/// takes sign-ups, onto its waitlist (see [detailCtaFor]).
const Set<String> openDriveStatuses = {'ACTIVE', 'FEATURED'};

/// Drive statuses during which check-in can happen (and passes are issued).
const Set<String> liveDriveStatuses = {'ACTIVE', 'FEATURED', 'FULL'};

/// Human label for a drive's status, accounting for drives whose end time has
/// passed but which the hourly sweep has not yet marked COMPLETED.
String driveStatusLabel(String status, DateTime endTime, {DateTime? now}) {
  final ended = !endTime.isAfter(now ?? DateTime.now());
  if (ended && liveDriveStatuses.contains(status)) return 'Ended';
  switch (status) {
    case 'ACTIVE':
      return 'Open';
    case 'FEATURED':
      return 'Featured';
    case 'FULL':
      return 'Full';
    case 'COMPLETED':
      return 'Completed';
    case 'CANCELLED':
      return 'Cancelled';
    case 'SUSPENDED':
      return 'Suspended';
    case 'DRAFT':
      return 'Draft';
    case 'CLOSED':
      return 'Closed';
    default:
      return status;
  }
}

/// What the event-detail bottom button does.
enum DetailCtaKind {
  /// Open the apply sheet.
  apply,

  /// Open the QR entry pass.
  viewPass,

  /// The volunteer has no date of birth on file; send them to Edit Profile.
  addDateOfBirth,

  /// Nothing to do (already applied, declined, closed, too young…).
  none,
}

class DetailCta {
  final DetailCtaKind kind;
  final String label;

  const DetailCta(this.kind, this.label);

  bool get enabled => kind != DetailCtaKind.none;
}

/// Resolves the event-detail call to action.
///
/// Apply is offered when the drive is ACTIVE or FEATURED, or FULL (the sign-up
/// joins the waitlist), has not ended, the volunteer has a date of birth on
/// file and meets [minAge]. A volunteer whose place was CANCELLED may apply
/// again. The server enforces each rule too; this keeps the button from
/// promising otherwise.
DetailCta detailCtaFor({
  required String status,
  required DateTime endTime,
  required int minAge,
  required DateTime? dateOfBirth,
  String? applicationStatus,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final ended = !endTime.isAfter(clock);

  // A cancelled place is not an application any more: the volunteer may apply
  // again, so it falls through to the normal rules below.
  if (applicationStatus != null && applicationStatus != 'CANCELLED') {
    switch (applicationStatus) {
      case 'APPROVED':
        if (liveDriveStatuses.contains(status) && !ended) {
          return const DetailCta(DetailCtaKind.viewPass, 'View QR Entry Pass');
        }
        if (status == 'CANCELLED') {
          return const DetailCta(DetailCtaKind.none, 'Drive cancelled');
        }
        return const DetailCta(DetailCtaKind.none, 'Drive has ended');
      case 'REJECTED':
        return const DetailCta(DetailCtaKind.none, 'Application Declined');
      case 'WAITLISTED':
        return const DetailCta(DetailCtaKind.none, 'Waitlisted');
      default:
        return const DetailCta(DetailCtaKind.none, 'Applied (Pending)');
    }
  }

  final reapplying = applicationStatus == 'CANCELLED';
  // A full drive still takes sign-ups onto its waitlist (server rule).
  final waitlistOpen = status == 'FULL' && !ended;

  if ((!openDriveStatuses.contains(status) && !waitlistOpen) || ended) {
    if (status == 'CANCELLED') {
      return const DetailCta(DetailCtaKind.none, 'Drive cancelled');
    }
    if (ended || status == 'COMPLETED') {
      return const DetailCta(DetailCtaKind.none, 'Drive has ended');
    }
    return const DetailCta(DetailCtaKind.none, 'Not accepting applications');
  }

  if (dateOfBirth == null) {
    return const DetailCta(
      DetailCtaKind.addDateOfBirth,
      'Add your date of birth to apply',
    );
  }

  if (ageOn(dateOfBirth, clock) < minAge) {
    return DetailCta(DetailCtaKind.none, 'For volunteers aged $minAge+');
  }

  if (waitlistOpen) {
    return const DetailCta(DetailCtaKind.apply, 'Join the waitlist');
  }
  return DetailCta(
    DetailCtaKind.apply,
    reapplying ? 'Apply again' : 'Apply Now',
  );
}

/// What the volunteer is told after applying. The server decides between
/// pending and waitlist (a FULL drive puts new sign-ups on its waitlist).
String applyResultMessage({
  required String driveTitle,
  String? position,
  String? status,
}) {
  if (status == 'WAITLISTED') {
    return 'You\'re on the waitlist for "$driveTitle". '
        'We\'ll move you in and tell you if a place opens.';
  }
  final asPosition = position == null ? '' : ' as $position';
  return 'Applied to "$driveTitle"$asPosition. '
      'The organizer will review your application.';
}
