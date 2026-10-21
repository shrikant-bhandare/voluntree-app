import 'package:flutter/material.dart' show TimeOfDay;

/// Date/time handling for drives.
///
/// The API stores and returns UTC instants. People think in their own zone,
/// so everything shown or edited is local, and everything sent back is UTC.
/// Keeping both directions here means the edit form cannot drift: an
/// unchanged save must send back exactly the instant it received.

/// The local wall-clock pieces the event form edits.
class EventFormTimes {
  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;

  /// Whole days between the local start date and the local end date (0 for a
  /// same-day drive). Preserved so an edit does not collapse a drive that ends
  /// after local midnight onto the start date.
  final int endDayOffset;

  const EventFormTimes({
    required this.date,
    required this.start,
    required this.end,
    this.endDayOffset = 0,
  });

  /// Prefill from a stored drive. Always converts to local first: reading the
  /// hour off a UTC DateTime shifted every saved drive by the UTC offset.
  factory EventFormTimes.fromEvent(DateTime startTime, DateTime endTime) {
    final start = startTime.toLocal();
    final end = endTime.toLocal();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    // Round rather than inDays: a DST change makes the gap 23 or 25 hours.
    final offset = (endDay.difference(startDay).inHours / 24).round();
    return EventFormTimes(
      date: startDay,
      start: TimeOfDay(hour: start.hour, minute: start.minute),
      end: TimeOfDay(hour: end.hour, minute: end.minute),
      endDayOffset: offset < 0 ? 0 : offset,
    );
  }

  /// Local start instant.
  DateTime get startDateTime => combineLocal(date, start);

  /// Local end instant.
  DateTime get endDateTime =>
      combineLocal(date.add(Duration(days: endDayOffset)), end);
}

/// Combines a local calendar date with a local time of day.
DateTime combineLocal(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

/// What the API expects: an explicit UTC ISO-8601 string. A local DateTime
/// serialises without a zone suffix and the server would store wall-clock
/// time as UTC.
String toApiTimestamp(DateTime dateTime) => dateTime.toUtc().toIso8601String();

String _two(int n) => n.toString().padLeft(2, '0');

/// `d/m/yyyy` in the device's zone.
String formatLocalDate(DateTime dateTime) {
  final l = dateTime.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}

/// `HH:mm` in the device's zone.
String formatLocalTime(DateTime dateTime) {
  final l = dateTime.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// `yyyy-mm-dd` in the device's zone (sortable, unambiguous).
String formatLocalIsoDate(DateTime dateTime) {
  final l = dateTime.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)}';
}

/// `yyyy-mm-dd` of a calendar date, with no zone conversion. Used for date of
/// birth, which is a date, not an instant.
String formatCalendarDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// Parses a `YYYY-MM-DD` (or full ISO) date of birth into a calendar date.
/// The server may send `2008-05-01T00:00:00.000Z`; only the date part counts,
/// so it is never shifted by the local zone.
DateTime? parseCalendarDate(dynamic value) {
  if (value is! String || value.length < 10) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Whole years between [dateOfBirth] and [today].
int ageOn(DateTime dateOfBirth, DateTime today) {
  var age = today.year - dateOfBirth.year;
  if (today.month < dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
    age--;
  }
  return age;
}
