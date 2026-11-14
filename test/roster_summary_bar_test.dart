import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/place_status.dart';
import 'package:volunteer_mobile_app/widgets/roster_summary_bar.dart';

void main() {
  testWidgets('shows who is coming, who has not replied and who cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RosterSummaryBar(
            summary: RosterSummary(
              approved: 12,
              confirmed: 8,
              notReplied: 4,
              cancelled: 1,
              waitlisted: 3,
            ),
          ),
        ),
      ),
    );

    expect(find.text('8 coming'), findsOneWidget);
    expect(find.text('4 not replied'), findsOneWidget);
    expect(find.text('1 cancelled'), findsOneWidget);
    expect(find.text('3 waiting'), findsOneWidget);
  });
}
