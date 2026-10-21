import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/api_helpers.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';
import 'package:volunteer_mobile_app/utils/event_time.dart';

/// ISS-011 / MOB-03. The API stores UTC; screens read `.hour` off the parsed
/// value, and the edit form used to prefill from UTC components and then send
/// them back as local time — every save moved the drive by the UTC offset.
void main() {
  group('parseServerDate', () {
    test('returns local time for a UTC timestamp, same instant', () {
      final parsed = parseServerDate('2026-11-01T03:30:00.000Z');

      expect(parsed.isUtc, isFalse);
      expect(
        parsed.toUtc(),
        DateTime.utc(2026, 11, 1, 3, 30),
        reason: 'conversion must not change the instant',
      );
    });

    test('display helpers read the local wall clock', () {
      final parsed = parseServerDate('2026-11-01T03:30:00.000Z');
      final local = DateTime.utc(2026, 11, 1, 3, 30).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');

      expect(
        formatLocalTime(parsed),
        '${two(local.hour)}:${two(local.minute)}',
      );
      expect(
        formatLocalDate(parsed),
        '${local.day}/${local.month}/${local.year}',
      );
    });

    test('EventModel times are local', () {
      final event = EventModel.fromJson({
        'id': 'e1',
        'startTime': '2026-11-01T03:30:00.000Z',
        'endTime': '2026-11-01T11:30:00.000Z',
      });

      expect(event.startTime.isUtc, isFalse);
      expect(event.endTime.isUtc, isFalse);
    });
  });

  group('edit-event round trip', () {
    // Saving an unchanged drive must send back exactly what it received.
    for (final pair in const [
      ['2026-11-01T03:30:00.000Z', '2026-11-01T11:30:00.000Z'],
      // Ends after midnight UTC, and after local midnight in many zones.
      ['2026-11-01T20:00:00.000Z', '2026-11-02T02:15:00.000Z'],
      ['2026-06-15T23:45:00.000Z', '2026-06-16T04:00:00.000Z'],
    ]) {
      test('preserves ${pair[0]} → ${pair[1]}', () {
        final event = EventModel.fromJson({
          'id': 'e1',
          'startTime': pair[0],
          'endTime': pair[1],
        });

        final form = EventFormTimes.fromEvent(event.startTime, event.endTime);
        // What the form sends on save, untouched by the organizer.
        final resent = EventFormTimes(
          date: form.date,
          start: form.start,
          end: form.end,
          endDayOffset: form.endDayOffset,
        );

        expect(toApiTimestamp(resent.startDateTime), pair[0]);
        expect(toApiTimestamp(resent.endDateTime), pair[1]);
      });
    }

    test('prefill uses local components, not UTC ones', () {
      final utc = DateTime.utc(2026, 11, 1, 3, 30);
      final local = utc.toLocal();

      final form = EventFormTimes.fromEvent(
        utc,
        utc.add(const Duration(hours: 2)),
      );

      expect(form.start, TimeOfDay(hour: local.hour, minute: local.minute));
      expect(form.date, DateTime(local.year, local.month, local.day));
    });

    test('a newly picked local time is sent as the matching UTC instant', () {
      final picked = combineLocal(
        DateTime(2026, 12, 5),
        const TimeOfDay(hour: 9, minute: 0),
      );

      expect(
        DateTime.parse(toApiTimestamp(picked)),
        DateTime(2026, 12, 5, 9).toUtc(),
      );
      expect(toApiTimestamp(picked), endsWith('Z'));
    });
  });

  group('calendar dates', () {
    test('date of birth is not shifted by the time zone', () {
      expect(
        parseCalendarDate('2008-05-01T00:00:00.000Z'),
        DateTime(2008, 5, 1),
      );
      expect(parseCalendarDate('2008-05-01'), DateTime(2008, 5, 1));
      expect(formatCalendarDate(DateTime(2008, 5, 1)), '2008-05-01');
      expect(parseCalendarDate(null), isNull);
    });

    test('ageOn counts whole years', () {
      expect(ageOn(DateTime(2010, 10, 20), DateTime(2026, 10, 19)), 15);
      expect(ageOn(DateTime(2010, 10, 19), DateTime(2026, 10, 19)), 16);
    });
  });
}
