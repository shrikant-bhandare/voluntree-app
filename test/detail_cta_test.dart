import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/drive_cta.dart';

/// ISS-007 / ISS-010. Apply is offered only for an open drive that has not
/// ended, to a volunteer with a date of birth who meets the minimum age.
void main() {
  final now = DateTime(2026, 10, 19, 12);
  final future = DateTime(2026, 10, 25, 17);
  final past = DateTime(2026, 10, 18, 17);
  final adult = DateTime(2000, 1, 1);

  DetailCta cta({
    String status = 'ACTIVE',
    DateTime? endTime,
    int minAge = 16,
    DateTime? dateOfBirth,
    bool noDob = false,
    String? applicationStatus,
  }) => detailCtaFor(
    status: status,
    endTime: endTime ?? future,
    minAge: minAge,
    dateOfBirth: noDob ? null : (dateOfBirth ?? adult),
    applicationStatus: applicationStatus,
    now: now,
  );

  group('by drive status', () {
    test('ACTIVE and FEATURED drives offer Apply', () {
      expect(cta(status: 'ACTIVE').kind, DetailCtaKind.apply);
      expect(cta(status: 'FEATURED').kind, DetailCtaKind.apply);
      expect(cta().label, 'Apply Now');
    });

    for (final entry in const {
      'FULL': 'Drive is full',
      'CANCELLED': 'Drive cancelled',
      'COMPLETED': 'Drive has ended',
      'SUSPENDED': 'Not accepting applications',
      'DRAFT': 'Not accepting applications',
    }.entries) {
      test('${entry.key} drives do not offer Apply', () {
        final result = cta(status: entry.key);
        expect(result.kind, DetailCtaKind.none);
        expect(result.enabled, isFalse);
        expect(result.label, entry.value);
      });
    }

    test('an ACTIVE drive that has ended does not offer Apply', () {
      final result = cta(endTime: past);
      expect(result.kind, DetailCtaKind.none);
      expect(result.label, 'Drive has ended');
    });
  });

  group('by date of birth and minAge', () {
    test('missing date of birth sends the volunteer to Edit Profile', () {
      final result = cta(noDob: true);
      expect(result.kind, DetailCtaKind.addDateOfBirth);
      expect(result.label, 'Add your date of birth to apply');
      expect(result.enabled, isTrue);
    });

    test('a volunteer under minAge cannot apply', () {
      final result = cta(minAge: 18, dateOfBirth: DateTime(2010, 1, 1));
      expect(result.kind, DetailCtaKind.none);
      expect(result.label, 'For volunteers aged 18+');
    });

    test('turning minAge today is old enough', () {
      final result = cta(minAge: 18, dateOfBirth: DateTime(2008, 10, 19));
      expect(result.kind, DetailCtaKind.apply);
    });

    test('one day short of minAge is not', () {
      final result = cta(minAge: 18, dateOfBirth: DateTime(2008, 10, 20));
      expect(result.kind, DetailCtaKind.none);
    });

    test('closed status wins over a missing date of birth', () {
      expect(cta(status: 'CANCELLED', noDob: true).kind, DetailCtaKind.none);
    });
  });

  group('with an existing application', () {
    test('approved on a live drive opens the pass', () {
      expect(cta(applicationStatus: 'APPROVED').kind, DetailCtaKind.viewPass);
      expect(
        cta(status: 'FULL', applicationStatus: 'APPROVED').kind,
        DetailCtaKind.viewPass,
      );
    });

    test('approved on a cancelled or ended drive does not', () {
      expect(
        cta(status: 'CANCELLED', applicationStatus: 'APPROVED').label,
        'Drive cancelled',
      );
      expect(
        cta(endTime: past, applicationStatus: 'APPROVED').label,
        'Drive has ended',
      );
    });

    test('pending, declined and waitlisted are informational', () {
      expect(cta(applicationStatus: 'PENDING').label, 'Applied (Pending)');
      expect(cta(applicationStatus: 'REJECTED').label, 'Application Declined');
      expect(cta(applicationStatus: 'WAITLISTED').label, 'Waitlisted');
      expect(cta(applicationStatus: 'PENDING').enabled, isFalse);
    });
  });

  test('driveStatusLabel reports an ended live drive as Ended', () {
    expect(driveStatusLabel('ACTIVE', past, now: now), 'Ended');
    expect(driveStatusLabel('ACTIVE', future, now: now), 'Open');
    expect(driveStatusLabel('CANCELLED', future, now: now), 'Cancelled');
  });
}
