import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/event_service.dart';
import 'package:volunteer_mobile_app/widgets/add_to_calendar_sheet.dart';
import 'package:volunteer_mobile_app/widgets/app_bar_circle_button.dart';

void main() {
  testWidgets('AppBarCircleButton shows icon and tooltip, taps work', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppBarCircleButton(
            icon: Icons.share_outlined,
            tooltip: 'Share this drive',
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byTooltip('Share this drive'), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
  });

  testWidgets('calendar sheet offers Google Calendar and .ics', (tester) async {
    final event = EventModel.fromJson({
      'id': 'e1',
      'title': 'Beach clean',
      'startTime': '2026-12-01T04:00:00.000Z',
      'endTime': '2026-12-01T07:00:00.000Z',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAddToCalendarSheet(
              context,
              event: event,
              shareUrl: 'https://x.test/p/e/e1',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Other calendar app (.ics file)'), findsOneWidget);
  });
}
