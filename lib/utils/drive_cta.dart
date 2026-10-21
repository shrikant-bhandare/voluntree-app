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

    switch (row['status']) {
      case 'PENDING':
        return const DriveCta('Pending', true);
      case 'UNDER_REVIEW':
        return const DriveCta('In review', true);
      case 'APPROVED':
        return const DriveCta('Approved', true);
      case 'REJECTED':
        return const DriveCta('Declined', true);
      case 'WAITLISTED':
        return const DriveCta('Waitlisted', true);
      default:
        return const DriveCta('Applied', true);
    }
  }

  return _join;
}

/// Drive statuses that accept new applications.
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
/// Apply is offered only when the drive is ACTIVE or FEATURED, has not ended,
/// the volunteer has a date of birth on file and meets [minAge]. The server
/// enforces each rule too; this keeps the button from promising otherwise.
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

  if (applicationStatus != null) {
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

  if (!openDriveStatuses.contains(status) || ended) {
    if (status == 'CANCELLED') {
      return const DetailCta(DetailCtaKind.none, 'Drive cancelled');
    }
    if (ended || status == 'COMPLETED') {
      return const DetailCta(DetailCtaKind.none, 'Drive has ended');
    }
    if (status == 'FULL') {
      return const DetailCta(DetailCtaKind.none, 'Drive is full');
    }
    return const DetailCta(DetailCtaKind.none, 'Not accepting applications');
  }

  if (dateOfBirth == null) {
    return const DetailCta(
      DetailCtaKind.addDateOfBirth,
      'Add your date of birth to apply',
    );
  }

  var age = clock.year - dateOfBirth.year;
  if (clock.month < dateOfBirth.month ||
      (clock.month == dateOfBirth.month && clock.day < dateOfBirth.day)) {
    age--;
  }
  if (age < minAge) {
    return DetailCta(DetailCtaKind.none, 'For volunteers aged $minAge+');
  }

  return const DetailCta(DetailCtaKind.apply, 'Apply Now');
}
