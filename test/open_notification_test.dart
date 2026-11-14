import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/screens/event_detail_screen.dart';
import 'package:volunteer_mobile_app/screens/volunteer_events_screen.dart';
import 'package:volunteer_mobile_app/utils/open_notification.dart';

/// The in-app toast opened the inbox for every notification, so a reminder
/// took two taps to reach My Drives. The toast and the inbox list now open
/// the same screen through one helper.
void main() {
  group('notificationScreen', () {
    test('reminders and status changes open My Drives', () {
      for (final type in [
        'reminder_confirm',
        'reminder_soon',
        'application_status',
      ]) {
        expect(
          notificationScreen({'type': type, 'eventId': 'e1'}),
          isA<VolunteerEventsScreen>(),
        );
      }
    });

    test('drive notifications open that drive', () {
      final screen = notificationScreen({
        'type': 'application_cancelled',
        'eventId': 'e1',
      });

      expect(screen, isA<EventDetailScreen>());
      expect((screen! as EventDetailScreen).eventId, 'e1');
    });

    test('unknown or incomplete notifications open nothing', () {
      expect(notificationScreen({}), isNull);
      expect(notificationScreen({'type': 'recommendation'}), isNull);
      expect(notificationScreen({'type': 'system_broadcast'}), isNull);
    });
  });

  testWidgets('openNotification stays put and says so for unknown types', (
    tester,
  ) async {
    final pushes = _PushCounter();
    bool? opened;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [pushes],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => opened = openNotification(context, {
              'type': 'system_broadcast',
            }),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final before = pushes.count;

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(opened, isFalse);
    expect(pushes.count, before);
  });
}

class _PushCounter extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}
