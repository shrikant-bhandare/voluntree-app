import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/widgets/cancel_place_dialog.dart';

void main() {
  testWidgets('returns the reason when the volunteer cancels', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showCancelPlaceDialog(
                context,
                driveTitle: 'Lake Cleanup',
                late: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('late cancellation'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Exam moved  ');
    await tester.tap(find.text('Cancel my place'));
    await tester.pumpAndSettle();
    expect(result, 'Exam moved');
  });

  testWidgets('returns null when the volunteer keeps their place', (
    tester,
  ) async {
    String? result = 'untouched';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showCancelPlaceDialog(
                context,
                driveTitle: 'Lake Cleanup',
                late: false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('late cancellation'), findsNothing);
    await tester.tap(find.text('Keep my place'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
