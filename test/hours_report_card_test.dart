import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/widgets/hours_report_card.dart';

void main() {
  testWidgets('explains the report and calls back on download', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HoursReportCard(onDownload: () async => taps++)),
      ),
    );

    expect(find.text('Hours report for your college'), findsOneWidget);
    await tester.tap(find.text('Download report'));
    expect(taps, 1);
  });
}
