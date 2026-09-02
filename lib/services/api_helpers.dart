/// Shared decoding helpers for the REST services.
///
/// List endpoints return a cursor-pagination envelope
/// `{ "data": [...], "nextCursor": "..." }`. Decoding that as a bare JSON
/// array throws a TypeError, which the services' catch-alls used to swallow —
/// every list screen simply looked empty against a healthy API.
library;

/// Accepts both the paginated `{data: [...]}` envelope and a bare array, so
/// the client keeps working against either backend generation.
List<dynamic> unwrapList(dynamic decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map<String, dynamic> && decoded['data'] is List) {
    return decoded['data'] as List<dynamic>;
  }
  return const [];
}

/// Cursor for the next page, if the endpoint returned one.
String? nextCursorOf(dynamic decoded) {
  if (decoded is Map<String, dynamic>) {
    final cursor = decoded['nextCursor'];
    if (cursor is String && cursor.isNotEmpty) return cursor;
  }
  return null;
}

/// The API's `message` field is a string, or a list of strings when
/// class-validator rejects a body. Screens pass this straight into Text(...),
/// which throws on a List — normalize it here, once.
String apiMessage(dynamic decoded, String fallback) {
  if (decoded is Map<String, dynamic>) {
    final message = decoded['message'];
    if (message is List) return message.join('\n');
    if (message is String && message.isNotEmpty) return message;
  }
  return fallback;
}

/// Parses a server timestamp defensively. Model fromJson runs inside
/// `.map(...).toList()` under a catch-all, so one malformed or missing date
/// must not silently discard the whole page.
DateTime parseServerDate(dynamic value, {DateTime? fallback}) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}
