import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

Future<ShareResult> _systemShare(ShareParams params) =>
    SharePlus.instance.share(params);

/// Opens the system share sheet; when sharing fails or is unavailable (for
/// example a browser without the Web Share API), copies [url] instead and
/// says so. A user dismissing the sheet is not a failure.
Future<void> shareOrCopyLink(
  BuildContext context, {
  required String text,
  required String subject,
  required String url,
  Future<ShareResult> Function(ShareParams params) share = _systemShare,
}) async {
  var needsCopy = false;
  try {
    final result = await share(
      ShareParams(text: text, subject: subject, mailToFallbackEnabled: false),
    );
    needsCopy = result.status == ShareResultStatus.unavailable;
  } catch (_) {
    needsCopy = true;
  }
  if (!needsCopy) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Link copied')));
}
