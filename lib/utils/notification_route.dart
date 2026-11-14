/// Where tapping a notification takes the person.
enum NotificationTarget { none, myDrives, drive }

class NotificationDestination {
  final NotificationTarget target;
  final String? eventId;

  const NotificationDestination(this.target, [this.eventId]);
}

/// Decides from the notification's `data.type`. Unknown types (sent by a newer
/// server) keep the person on the inbox rather than guessing.
NotificationDestination notificationDestination(Map<String, dynamic> data) {
  final eventId = data['eventId'] is String ? data['eventId'] as String : null;
  switch (data['type']) {
    case 'reminder_confirm':
    case 'reminder_soon':
    case 'application_status':
      return const NotificationDestination(NotificationTarget.myDrives);
    case 'application':
    case 'application_cancelled':
    case 'application_withdrawn':
    case 'recommendation':
    case 'EVENT_STATUS':
      return eventId == null
          ? const NotificationDestination(NotificationTarget.none)
          : NotificationDestination(NotificationTarget.drive, eventId);
    default:
      return const NotificationDestination(NotificationTarget.none);
  }
}
