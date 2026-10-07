import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile_app/utils/spots_remaining.dart';

/// Drive cards advertised `volunteersNeeded` as "spots left", so a drive
/// needing 25 volunteers with 1 already approved still read "25 spots left".
void main() {
  group('spotsRemaining', () {
    test('subtracts approved volunteers from the requirement', () {
      expect(spotsRemaining(volunteersNeeded: 25, approvedCount: 1), 24);
    });

    test('reports the full count when nobody is approved', () {
      expect(spotsRemaining(volunteersNeeded: 10, approvedCount: 0), 10);
    });

    test('never goes negative when a drive is over-subscribed', () {
      expect(spotsRemaining(volunteersNeeded: 3, approvedCount: 5), 0);
    });
  });

  group('spotsLabel', () {
    test('reads as full when no spots remain', () {
      expect(spotsLabel(volunteersNeeded: 3, approvedCount: 3), 'Drive full');
    });

    test('names the singular spot', () {
      expect(spotsLabel(volunteersNeeded: 3, approvedCount: 2), '1 spot left');
    });

    test('names the remaining spots', () {
      expect(
        spotsLabel(volunteersNeeded: 25, approvedCount: 1),
        '24 spots left',
      );
    });
  });

  group('spotsAreScarce', () {
    test('a nearly empty drive is not scarce', () {
      expect(spotsAreScarce(volunteersNeeded: 25, approvedCount: 1), isFalse);
    });

    test('a drive down to its last few spots is scarce', () {
      expect(spotsAreScarce(volunteersNeeded: 25, approvedCount: 23), isTrue);
    });

    test('a full drive is not flagged as scarce', () {
      expect(spotsAreScarce(volunteersNeeded: 25, approvedCount: 25), isFalse);
    });

    test('a small drive is scarce only near the end', () {
      expect(spotsAreScarce(volunteersNeeded: 4, approvedCount: 0), isFalse);
      expect(spotsAreScarce(volunteersNeeded: 4, approvedCount: 3), isTrue);
    });
  });
}
