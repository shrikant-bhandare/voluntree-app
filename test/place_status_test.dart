import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/place_status.dart';

/// Plan 01: approved volunteers are asked "still coming?" in the last 48 hours,
/// and organizers see who answered.
void main() {
  final now = DateTime(2026, 11, 13, 10);

  Map<String, dynamic> app({
    String status = 'APPROVED',
    DateTime? start,
    String? confirmedAt,
    String eventStatus = 'ACTIVE',
  }) => {
    'status': status,
    'confirmedAt': confirmedAt,
    'event': {
      'status': eventStatus,
      'startTime': (start ?? now.add(const Duration(hours: 20)))
          .toUtc()
          .toIso8601String(),
    },
  };

  group('placePromptFor', () {
    test('asks an approved volunteer within 48 hours of the start', () {
      expect(placePromptFor(app(), now: now), PlacePrompt.askToConfirm);
    });

    test('does not ask more than 48 hours ahead', () {
      final start = now.add(const Duration(hours: 60));
      expect(placePromptFor(app(start: start), now: now), PlacePrompt.none);
    });

    test('shows the answer once confirmed', () {
      expect(
        placePromptFor(app(confirmedAt: '2026-11-13T04:00:00Z'), now: now),
        PlacePrompt.confirmed,
      );
    });

    test('says nothing for other statuses or a drive that has started', () {
      expect(
        placePromptFor(app(status: 'PENDING'), now: now),
        PlacePrompt.none,
      );
      final started = now.subtract(const Duration(minutes: 5));
      expect(placePromptFor(app(start: started), now: now), PlacePrompt.none);
      expect(
        placePromptFor({'status': 'APPROVED'}, now: now),
        PlacePrompt.none,
      );
    });

    test('says nothing for a drive that is not running', () {
      expect(
        placePromptFor(app(eventStatus: 'CANCELLED'), now: now),
        PlacePrompt.none,
      );
    });
  });

  group('placeStartsLabel', () {
    test('says today, tomorrow or the date', () {
      expect(
        placeStartsLabel(DateTime(2026, 11, 13, 18, 5), now: now),
        'today at 18:05',
      );
      expect(
        placeStartsLabel(DateTime(2026, 11, 14, 9, 30), now: now),
        'tomorrow at 09:30',
      );
      expect(
        placeStartsLabel(DateTime(2026, 11, 16, 9, 30), now: now),
        'on 16/11/2026 at 09:30',
      );
    });
  });

  test('isLateCancellation is true under 24 hours before the start', () {
    expect(
      isLateCancellation(now.add(const Duration(hours: 10)), now: now),
      isTrue,
    );
    expect(
      isLateCancellation(now.add(const Duration(hours: 30)), now: now),
      isFalse,
    );
  });

  test('applicationStatusLabel names every status, with a fallback', () {
    expect(applicationStatusLabel('WAITLISTED'), 'Waitlisted');
    expect(applicationStatusLabel('CANCELLED'), 'Cancelled');
    expect(applicationStatusLabel('UNDER_REVIEW'), 'In review');
    expect(applicationStatusLabel('SOMETHING_NEW'), 'Applied');
  });

  test('rosterSummary counts who is coming', () {
    final summary = rosterSummary([
      {'status': 'APPROVED', 'confirmedAt': '2026-11-13T04:00:00Z'},
      {'status': 'APPROVED', 'confirmedAt': null},
      {'status': 'APPROVED'},
      {'status': 'CANCELLED'},
      {'status': 'WAITLISTED'},
      {'status': 'PENDING'},
      'not a map',
    ]);
    expect(summary.approved, 3);
    expect(summary.confirmed, 1);
    expect(summary.notReplied, 2);
    expect(summary.cancelled, 1);
    expect(summary.waitlisted, 1);
  });
}
