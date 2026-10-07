import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/list_state.dart';

/// The organizer dashboard announced "No active events published." before the
/// first fetch had returned, so an organizer with five drives was told they
/// had none until the request landed.
void main() {
  group('listStateFor', () {
    test('is loading before the first fetch returns', () {
      expect(listStateFor(hasLoaded: false, count: 0), ListState.loading);
    });

    test('stays loading even if a stale cache is momentarily non-empty', () {
      expect(listStateFor(hasLoaded: false, count: 3), ListState.loading);
    });

    test('is empty only once a fetch has actually completed', () {
      expect(listStateFor(hasLoaded: true, count: 0), ListState.empty);
    });

    test('is ready when a completed fetch returned rows', () {
      expect(listStateFor(hasLoaded: true, count: 3), ListState.ready);
    });

    test('reports failure rather than emptiness when the load errored', () {
      expect(
        listStateFor(hasLoaded: true, count: 0, failed: true),
        ListState.failed,
      );
    });

    test('failure outranks a stale non-empty cache', () {
      expect(
        listStateFor(hasLoaded: true, count: 5, failed: true),
        ListState.failed,
      );
    });

    test('a successful empty load is still empty, not failed', () {
      expect(
        listStateFor(hasLoaded: true, count: 0, failed: false),
        ListState.empty,
      );
    });
  });
}
