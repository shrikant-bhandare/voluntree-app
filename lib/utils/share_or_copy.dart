import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

Future<ShareResult> _systemShare(ShareParams params) =>
    SharePlus.instance.share(params);

Future<void> _systemCopy(ClipboardData data) => Clipboard.setData(data);

/// Opens the system share sheet; when sharing fails or is unavailable (for
/// example a browser without the Web Share API), copies [url] instead and
/// says so. If the browser also refuses the clipboard write, shows [url] in a
/// dialog so the user can still copy it by hand. A user dismissing the sheet
/// is not a failure.
Future<void> shareOrCopyLink(
  BuildContext context, {
  required String text,
  required String subject,
  required String url,
  String fallbackTitle = 'Share this drive',
  Future<ShareResult> Function(ShareParams params) share = _systemShare,
  Future<void> Function(ClipboardData data) copy = _systemCopy,
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
  try {
    await copy(ClipboardData(text: url));
  } catch (_) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(fallbackTitle),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Link copied')));
}
