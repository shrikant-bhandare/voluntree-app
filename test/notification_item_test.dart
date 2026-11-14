import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/notification_service.dart';

void main() {
  test('reads the routing data sent with a notification', () {
    final item = NotificationItem.fromJson({
      'id': 'n1',
      'title': 'Still coming?',
      'body': 'It starts tomorrow.',
      'isRead': false,
      'createdAt': '2026-11-13T04:30:00Z',
      'data': {'type': 'reminder_confirm', 'applicationId': 'a1'},
    });

    expect(item.data['type'], 'reminder_confirm');
    expect(item.data['applicationId'], 'a1');
  });

  test('older notifications without data get an empty map', () {
    final item = NotificationItem.fromJson({
      'id': 'n2',
      'title': 'Hello',
      'body': 'Broadcast',
      'createdAt': '2026-11-13T04:30:00Z',
    });

    expect(item.data, isEmpty);
  });
}
