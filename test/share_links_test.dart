import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';
import 'package:volunteer_mobile_app/utils/share_links.dart';
import 'package:volunteer_mobile_app/utils/spots_remaining.dart';

void main() {
  test('server share link wins, absent field falls back, null is hidden', () {
    expect(
      driveShareUrl(
        eventId: 'abc',
        serverShareUrl: 'https://voluntree.example/p/e/abc',
        serverSentShareUrl: true,
        apiBaseUrl: 'https://api.example.org',
      ),
      'https://voluntree.example/p/e/abc',
    );
    expect(
      driveShareUrl(eventId: 'abc', apiBaseUrl: 'https://api.example.org'),
      'https://api.example.org/p/e/abc',
    );
    expect(
      driveShareUrl(
        eventId: 'abc',
        serverShareUrl: null,
        serverSentShareUrl: true,
        apiBaseUrl: 'https://api.example.org',
      ),
      isNull,
    );
  });

  test('EventModel records whether the server sent shareUrl', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
      'id': 'e1',
      'startTime': '2026-11-14T04:00:00.000Z',
      'endTime': '2026-11-14T07:00:00.000Z',
      ...extra,
    };
    final sent = EventModel.fromJson(json({'shareUrl': 'https://x/p/e/e1'}));
    expect(sent.shareUrl, 'https://x/p/e/e1');
    expect(sent.shareUrlProvided, isTrue);
    final hidden = EventModel.fromJson(json({'shareUrl': null}));
    expect(hidden.shareUrl, isNull);
    expect(hidden.shareUrlProvided, isTrue);
    final old = EventModel.fromJson(json({}));
    expect(old.shareUrlProvided, isFalse);
  });

  test('share text names the drive, host, time and link', () {
    final text = driveShareText(
      title: 'Lake Cleanup',
      organizer: 'Green Earth Trust',
      start: DateTime(2026, 11, 14, 9, 30),
      url: 'https://api.example.org/p/e/abc',
    );
    expect(
      text,
      'Join me at "Lake Cleanup" by Green Earth Trust on 14/11/2026 at 09:30. '
      'https://api.example.org/p/e/abc',
    );
  });

  test('Google Calendar link carries the UTC times and title', () {
    final url = Uri.parse(
      googleCalendarUrl(
        title: 'Lake Cleanup',
        start: DateTime.utc(2026, 11, 14, 4),
        end: DateTime.utc(2026, 11, 14, 7),
        details: 'Bring water',
        location: 'Lake Road',
      ),
    );
    expect(url.host, 'calendar.google.com');
    expect(url.queryParameters['action'], 'TEMPLATE');
    expect(url.queryParameters['text'], 'Lake Cleanup');
    expect(url.queryParameters['dates'], '20261114T040000Z/20261114T070000Z');
  });

  test('calendar file sits next to the share page', () {
    expect(
      calendarFileUrl('https://api.example.org/p/e/abc'),
      'https://api.example.org/p/e/abc/calendar.ics',
    );
  });

  group('placesLabel', () {
    final now = DateTime(2026, 11, 13);
    final later = DateTime(2026, 11, 14);
    String label(String status, int needed, int approved, {DateTime? end}) =>
        placesLabel(
          status: status,
          needed: needed,
          approved: approved,
          end: end ?? later,
          now: now,
        );

    test('ended wins over everything', () {
      expect(label('FULL', 5, 5, end: now), 'This drive has ended');
    });
    test('non-live status is not open', () {
      expect(label('DRAFT', 5, 0), 'This drive is not open');
      expect(label('CANCELLED', 5, 0), 'This drive is not open');
    });
    test('FULL offers the waitlist', () {
      expect(label('FULL', 5, 5), 'Full — you can join the waitlist');
    });
    test('no places left on a live drive reads Full', () {
      expect(label('ACTIVE', 5, 6), 'Full');
    });
    test('open drive counts places left', () {
      expect(label('ACTIVE', 5, 3), '2 of 5 places left');
    });
  });
}
