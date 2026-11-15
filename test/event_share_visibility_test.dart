import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/share_links.dart';

/// The detail screen first paints from a cached list model, and the
/// organizer's own list includes drafts and cancelled drives. Sharing and
/// "add to calendar" must only show for a drive the public page serves.
void main() {
  const base = 'https://api.example.org';

  test('a publicly visible drive gets its share link', () {
    for (final status in [
      'ACTIVE',
      'FEATURED',
      'FULL',
      'CLOSED',
      'COMPLETED',
    ]) {
      expect(
        shareUrlForStatus(
          status: status,
          eventId: 'e1',
          serverShareUrl: null,
          serverSentShareUrl: false,
          apiBaseUrl: base,
        ),
        isNotNull,
        reason: status,
      );
    }
  });

  test('draft, cancelled and suspended drives get none', () {
    for (final status in ['DRAFT', 'CANCELLED', 'SUSPENDED', 'PENDING']) {
      expect(
        shareUrlForStatus(
          status: status,
          eventId: 'e1',
          serverShareUrl: 'https://x/p/e/e1',
          serverSentShareUrl: true,
          apiBaseUrl: base,
        ),
        isNull,
        reason: status,
      );
    }
  });

  test('a server that withholds the link still wins on a public drive', () {
    expect(
      shareUrlForStatus(
        status: 'ACTIVE',
        eventId: 'e1',
        serverShareUrl: null,
        serverSentShareUrl: true,
        apiBaseUrl: base,
      ),
      isNull,
    );
  });
}
