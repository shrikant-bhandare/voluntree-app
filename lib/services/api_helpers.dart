/// Shared decoding helpers for the REST services.
///
/// List endpoints return a cursor-pagination envelope
/// `{ "data": [...], "nextCursor": "..." }`. Decoding that as a bare JSON
/// array throws a TypeError, which the services' catch-alls used to swallow —
/// every list screen simply looked empty against a healthy API.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

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
///
/// The API sends UTC (`...Z`). The result is always converted to the device's
/// local zone: screens read `.hour`/`.day` straight off these values, and a
/// UTC DateTime made a 09:00 IST drive read "03:30".
DateTime parseServerDate(dynamic value, {DateTime? fallback}) {
  return parseServerDateOrNull(value) ?? fallback ?? DateTime.now();
}

/// Like [parseServerDate] but returns null for a missing or malformed value.
DateTime? parseServerDateOrNull(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

/// Maps a thrown exception (no connectivity, DNS failure, malformed body) to
/// copy a person can act on. Raw `ClientException with SocketException...`
/// strings must never reach a SnackBar.
String friendlyNetworkError([Object? error]) =>
    'You appear to be offline. Check your connection and try again.';

/// Best-effort decode of an error body; returns null when it is not JSON.
dynamic tryDecodeJson(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

/// Document types the chat picker offers. Each must map to a MIME type the
/// API's attachment filter accepts (PDF, Word, and Office Open XML files);
/// plain text and legacy .xls are rejected there, so they are not offered.
const chatDocumentExtensions = ['pdf', 'doc', 'docx', 'xlsx'];

/// MIME type for an upload: sniffed from the file's leading bytes, falling
/// back to the filename's extension.
String uploadContentType(List<int> bytes, String filename) =>
    lookupMimeType(filename, headerBytes: bytes) ?? 'application/octet-stream';

/// A multipart file part that carries the file's real Content-Type.
///
/// `http.MultipartFile.fromBytes` labels every part
/// `application/octet-stream` unless told otherwise, and the API's upload
/// filters accept only listed image and document types, so an untyped part
/// is rejected with 400 before it is stored (F11).
http.MultipartFile typedMultipartFile(
  String field,
  List<int> bytes,
  String filename,
) => http.MultipartFile.fromBytes(
  field,
  bytes,
  filename: filename,
  contentType: MediaType.parse(uploadContentType(bytes, filename)),
);
