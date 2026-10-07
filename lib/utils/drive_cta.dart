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
