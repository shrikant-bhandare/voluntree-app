import 'package:flutter/material.dart';
import '../screens/event_detail_screen.dart';
import '../screens/volunteer_events_screen.dart';
import 'notification_route.dart';

/// The screen a notification opens, or null when it points nowhere (an
/// unknown or incomplete type; see [notificationDestination]).
///
/// The inbox list and the in-app toast both open notifications through here.
/// The toast used to open the inbox whatever the notification said, so a
/// reminder took two taps to reach My Drives.
Widget? notificationScreen(Map<String, dynamic> data) {
  final destination = notificationDestination(data);
  switch (destination.target) {
    case NotificationTarget.myDrives:
      return const VolunteerEventsScreen();
    case NotificationTarget.drive:
      return EventDetailScreen(eventId: destination.eventId!);
    case NotificationTarget.none:
      return null;
  }
}

/// Opens the screen [data] points to. Returns false, without navigating,
/// when it points nowhere, so the caller can choose a fallback.
bool openNotification(BuildContext context, Map<String, dynamic> data) {
  final screen = notificationScreen(data);
  if (screen == null) return false;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  return true;
}
