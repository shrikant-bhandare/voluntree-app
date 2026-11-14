import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/event_service.dart';
import '../utils/share_links.dart';

/// Bottom sheet offering Google Calendar or the drive's .ics file.
Future<void> showAddToCalendarSheet(
  BuildContext context, {
  required EventModel event,
  required String shareUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Google Calendar'),
            onTap: () {
              Navigator.pop(sheetContext);
              launchUrl(
                Uri.parse(
                  googleCalendarUrl(
                    title: event.title,
                    start: event.startTime,
                    end: event.endTime,
                    details: 'Volunteer drive on Voluntree: $shareUrl',
                    location: event.isOnline ? 'Online' : event.address,
                  ),
                ),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_note),
            title: const Text('Other calendar app (.ics file)'),
            onTap: () {
              Navigator.pop(sheetContext);
              launchUrl(
                Uri.parse(calendarFileUrl(shareUrl)),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ),
    ),
  );
}
