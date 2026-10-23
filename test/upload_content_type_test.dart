import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/api_helpers.dart';

/// F11 (web QA, 24 Oct 2026). Uploads went out as application/octet-stream
/// and the API rejected every one of them. These mirror the API's multer
/// filters in backend/src/storage/storage.service.ts.
final _serverImageTypes = RegExp(r'^image/(jpeg|png|webp|gif|heic|heif)$');
final _serverAttachmentTypes = RegExp(
  r'^(image/|video/|audio/|application/pdf$|application/msword$|application/vnd\.openxmlformats-officedocument\.)',
);

const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13];
const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 0x4A, 0x46, 0x49, 0x46];
const _pdf = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37];
const _webm = [0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81];
const _zip = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00];

void main() {
  group('uploadContentType', () {
    test('photos are typed from their bytes, even without an extension', () {
      // Web pickers can hand back names without a usable extension.
      expect(uploadContentType(_png, 'qa-avatar.png'), 'image/png');
      expect(uploadContentType(_jpeg, 'image_picker_5F2A'), 'image/jpeg');
    });

    test('photos pass the API image filter', () {
      for (final type in [
        uploadContentType(_png, 'a.png'),
        uploadContentType(_jpeg, 'b.jpg'),
      ]) {
        expect(_serverImageTypes.hasMatch(type), isTrue, reason: type);
      }
    });

    test('a web voice note recorded as WebM passes the attachment filter', () {
      // The recorder names it .m4a, but browsers record WebM; the bytes win.
      final type = uploadContentType(_webm, 'voice_note_1.m4a');
      expect(type, startsWith('audio/'));
      expect(_serverAttachmentTypes.hasMatch(type), isTrue);
    });

    test('Office files are typed by extension, not sniffed as zip', () {
      expect(
        uploadContentType(_zip, 'report.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(
        uploadContentType(_zip, 'sheet.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    test('unknown content falls back to octet-stream', () {
      expect(uploadContentType([1, 2, 3], 'blob'), 'application/octet-stream');
    });
  });

  test('every document type the chat picker offers is accepted by the API', () {
    for (final ext in chatDocumentExtensions) {
      final bytes = ext == 'pdf' ? _pdf : _zip;
      final type = uploadContentType(bytes, 'file.$ext');
      expect(
        _serverAttachmentTypes.hasMatch(type),
        isTrue,
        reason: '$ext → $type',
      );
    }
  });

  test('typedMultipartFile carries the detected type, not octet-stream', () {
    final part = typedMultipartFile('file', _png, 'qa-avatar.png');
    expect(part.field, 'file');
    expect(part.filename, 'qa-avatar.png');
    expect(part.contentType.mimeType, 'image/png');
    expect(part.length, _png.length);
  });
}
