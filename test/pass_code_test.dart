import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/services/attendance_service.dart';
import 'package:volunteer_mobile_app/widgets/pass_code_display.dart';

/// ISS-014. Browsers cannot scan QR codes, so the pass shows a short code the
/// organizer can type, and the manual scan sends it with the chosen drive.
void main() {
  group('pass code formatting', () {
    test('normalises to XXXX-XXXX', () {
      expect(formatPassCode('k7qm2xpa'), 'K7QM-2XPA');
      expect(formatPassCode('K7QM-2XPA'), 'K7QM-2XPA');
      expect(formatPassCode(' k7qm 2xpa '), 'K7QM-2XPA');
      expect(formatPassCode(null), isNull);
      expect(formatPassCode(''), isNull);
    });

    test('normalizePassCode strips separators and upper-cases', () {
      expect(normalizePassCode('k7qm-2xpa'), 'K7QM2XPA');
    });

    test('PassDetails reads passCode from the pass response', () {
      final pass = PassDetails.fromJson({
        'passToken': 'a|b|c|1|sig',
        'passCode': 'K7QM2XPA',
        'eventTitle': 'Beach clean-up',
        'startTime': '2026-11-01T03:30:00.000Z',
        'address': 'Juhu',
        'expiresAt': '2026-11-01T05:30:00.000Z',
      });

      expect(pass.passCode, 'K7QM-2XPA');
      expect(pass.expiresAt!.isUtc, isFalse);
    });
  });

  testWidgets('shows the code large, monospace, with copy and help text', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PassCodeDisplay(code: 'K7QM-2XPA')),
      ),
    );

    final codeText = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(codeText.data, 'K7QM-2XPA');
    expect(codeText.style!.fontFamily, 'monospace');
    expect(codeText.style!.fontSize, greaterThanOrEqualTo(24));
    expect(
      find.text("If the organizer can't scan, read this code to them."),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Copy pass code'));
    await tester.pump();
    expect(copied, 'K7QM-2XPA');
    expect(find.text('Pass code copied'), findsOneWidget);
  });
}
