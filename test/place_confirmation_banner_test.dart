import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/place_status.dart';
import 'package:volunteer_mobile_app/widgets/place_confirmation_banner.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    PlacePrompt prompt, {
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceConfirmationBanner(
            prompt: prompt,
            startsLabel: 'tomorrow at 09:30',
            onConfirm: onConfirm ?? () {},
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('asks and calls back on Yes and on Can\'t make it', (
    tester,
  ) async {
    var confirmed = 0, cancelled = 0;
    await pump(
      tester,
      PlacePrompt.askToConfirm,
      onConfirm: () => confirmed++,
      onCancel: () => cancelled++,
    );

    expect(
      find.text('Starts tomorrow at 09:30. Still coming?'),
      findsOneWidget,
    );
    await tester.tap(find.text("Yes, I'll be there"));
    await tester.tap(find.text("Can't make it"));
    expect(confirmed, 1);
    expect(cancelled, 1);
  });

  testWidgets('shows the answer once confirmed, without asking again', (
    tester,
  ) async {
    await pump(tester, PlacePrompt.confirmed);

    expect(
      find.text("You're coming — starts tomorrow at 09:30"),
      findsOneWidget,
    );
    expect(find.text("Yes, I'll be there"), findsNothing);
    expect(find.text("Can't make it"), findsOneWidget);
  });

  testWidgets('renders nothing when there is nothing to ask', (tester) async {
    await pump(tester, PlacePrompt.none);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
