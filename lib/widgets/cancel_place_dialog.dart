import 'package:flutter/material.dart';
import '../theme/brand.dart';

/// Asks an approved volunteer to confirm giving up their place.
///
/// Returns the trimmed reason (empty when none was given) when they cancel,
/// or null when they keep their place. The reason is optional so cancelling
/// is never blocked on typing.
Future<String?> showCancelPlaceDialog(
  BuildContext context, {
  required String driveTitle,
  required bool late,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CancelPlaceDialog(driveTitle: driveTitle, late: late),
  );
}

class _CancelPlaceDialog extends StatefulWidget {
  final String driveTitle;
  final bool late;

  const _CancelPlaceDialog({required this.driveTitle, required this.late});

  @override
  State<_CancelPlaceDialog> createState() => _CancelPlaceDialogState();
}

class _CancelPlaceDialogState extends State<_CancelPlaceDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Can't make it?"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your place on "${widget.driveTitle}" will go to the next person '
              'on the waitlist, and the organizer will be told.',
            ),
            if (widget.late) ...[
              const SizedBox(height: 8),
              const Text(
                'It starts in less than 24 hours, so the organizer will see '
                'this as a late cancellation.',
                style: TextStyle(color: Brand.onErrorContainer),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. exam moved to Saturday',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep my place'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.error),
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Cancel my place'),
        ),
      ],
    );
  }
}
