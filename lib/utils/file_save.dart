import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, debugPrint, kIsWeb;

/// Outcome of handing a file to the user.
enum SaveOutcome { saved, cancelled, failed }

/// Gives the user a file they can keep.
///
/// Android/iOS open the system "Save to…" picker so the file lands somewhere
/// the person can find and share it (the old app-private documents directory
/// was invisible in Files); the web build triggers a browser download.
Future<SaveOutcome> saveBytesForUser({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String dialogTitle = 'Save file',
}) async {
  try {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
    );
    // The web implementation returns null after starting the download.
    if (kIsWeb) return SaveOutcome.saved;
    return uri == null ? SaveOutcome.cancelled : SaveOutcome.saved;
  } catch (e) {
    debugPrint('[FILE SAVE] $fileName failed: $e');
    return SaveOutcome.failed;
  }
}
