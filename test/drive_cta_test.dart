import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/drive_cta.dart';

/// The featured-drive cards offered "Join" for every drive, including ones the
/// volunteer had already applied to — tapping through only revealed the real
/// pending state on the detail screen.
void main() {
  group('driveCtaFor', () {
    test('offers Join when the volunteer has no application', () {
      final cta = driveCtaFor(eventId: 'event-1', userApplications: const []);

      expect(cta.label, 'Join');
      expect(cta.isApplied, isFalse);
    });

    test('offers Join when the applications belong to other drives', () {
      final cta = driveCtaFor(
        eventId: 'event-1',
        userApplications: const [
          {'eventId': 'event-2', 'status': 'APPROVED'},
        ],
      );

      expect(cta.label, 'Join');
      expect(cta.isApplied, isFalse);
    });

    test('reports a pending application instead of offering Join', () {
      final cta = driveCtaFor(
        eventId: 'event-1',
        userApplications: const [
          {'eventId': 'event-1', 'status': 'PENDING'},
        ],
      );

      expect(cta.label, 'Pending');
      expect(cta.isApplied, isTrue);
    });

    test('reports an approved application', () {
      final cta = driveCtaFor(
        eventId: 'event-1',
        userApplications: const [
          {'eventId': 'event-1', 'status': 'APPROVED'},
        ],
      );

      expect(cta.label, 'Approved');
      expect(cta.isApplied, isTrue);
    });

    test('reports a declined application', () {
      final cta = driveCtaFor(
        eventId: 'event-1',
        userApplications: const [
          {'eventId': 'event-1', 'status': 'REJECTED'},
        ],
      );

      expect(cta.label, 'Declined');
      expect(cta.isApplied, isTrue);
    });

    test('reports a waitlisted application', () {
      final cta = driveCtaFor(
        eventId: 'event-1',
        userApplications: const [
          {'eventId': 'event-1', 'status': 'WAITLISTED'},
        ],
      );

      expect(cta.label, 'Waitlisted');
      expect(cta.isApplied, isTrue);
    });

    test('survives malformed rows rather than throwing', () {
      final cta = driveCtaFor(
        eventId: 'event-1',
        userApplications: const [
          null,
          'nonsense',
          {'no-event-id': true},
          {'eventId': 'event-1', 'status': 'PENDING'},
        ],
      );

      expect(cta.label, 'Pending');
      expect(cta.isApplied, isTrue);
    });

    test('falls back to a neutral label for an unknown status', () {
      final cta = driveCtaFor(
        eventId: 'event-1',
        userApplications: const [
          {'eventId': 'event-1', 'status': 'SOMETHING_NEW'},
        ],
      );

      expect(cta.label, 'Applied');
      expect(cta.isApplied, isTrue);
    });
  });
}
