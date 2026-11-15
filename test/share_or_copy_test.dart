import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:volunteer_mobile_app/utils/share_or_copy.dart';

void main() {
  const url = 'https://x.test/p/e/e1';
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  Future<void> run(
    WidgetTester tester,
    Future<ShareResult> Function(ShareParams) share, {
    Future<void> Function(ClipboardData)? copy,
    String? fallbackTitle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => shareOrCopyLink(
                context,
                text: 'hi $url',
                subject: 'Drive',
                url: url,
                fallbackTitle: fallbackTitle ?? 'Share this drive',
                share: share,
                copy: copy ?? Clipboard.setData,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('throwing share copies the link and says so', (tester) async {
    await run(tester, (_) async => throw Exception('no share api'));
    expect(clipboard, url);
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('unavailable result copies the link and says so', (tester) async {
    await run(tester, (_) async => ShareResult.unavailable);
    expect(clipboard, url);
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('refused clipboard write shows the link in a dialog', (
    tester,
  ) async {
    await run(
      tester,
      (_) async => ShareResult.unavailable,
      copy: (_) async => throw Exception('clipboard denied'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Share this drive'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, url), findsOneWidget);
    expect(find.text('Link copied'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Share this drive'), findsNothing);
  });

  testWidgets('the dialog title is the one the caller passes', (tester) async {
    await run(
      tester,
      (_) async => ShareResult.unavailable,
      copy: (_) async => throw Exception('clipboard denied'),
      fallbackTitle: 'Share your Impact profile',
    );
    await tester.pumpAndSettle();
    expect(find.text('Share your Impact profile'), findsOneWidget);
    expect(find.text('Share this drive'), findsNothing);
  });

  testWidgets('successful share leaves clipboard and snackbar alone', (
    tester,
  ) async {
    ShareParams? seen;
    await run(tester, (p) async {
      seen = p;
      return const ShareResult('', ShareResultStatus.success);
    });
    expect(clipboard, isNull);
    expect(find.text('Link copied'), findsNothing);
    expect(seen!.mailToFallbackEnabled, isFalse);
  });
}
