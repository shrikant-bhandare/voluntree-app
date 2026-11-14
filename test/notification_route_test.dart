import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/notification_route.dart';

void main() {
  test('reminders and status changes open My Drives', () {
    for (final type in [
      'reminder_confirm',
      'reminder_soon',
      'application_status',
    ]) {
      expect(
        notificationDestination({'type': type, 'eventId': 'e1'}).target,
        NotificationTarget.myDrives,
      );
    }
  });

  test('drive-related notifications open the drive', () {
    final dest = notificationDestination({
      'type': 'application_cancelled',
      'eventId': 'e1',
    });
    expect(dest.target, NotificationTarget.drive);
    expect(dest.eventId, 'e1');
  });

  test('anything unknown or incomplete stays on the inbox', () {
    expect(notificationDestination({}).target, NotificationTarget.none);
    expect(
      notificationDestination({'type': 'recommendation'}).target,
      NotificationTarget.none,
    );
    expect(
      notificationDestination({'type': 'system_broadcast'}).target,
      NotificationTarget.none,
    );
  });
}
