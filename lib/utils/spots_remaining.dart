/// How many volunteer places a drive still has, and how to say it.
///
/// Cards used to print `volunteersNeeded` under the label "spots left", which
/// is the drive's *capacity*, not its remaining places — a drive needing 25
/// volunteers with 1 approved still advertised "25 spots left". Keeping the
/// arithmetic and the wording here means the listing, the detail screen and
/// the organizer view cannot disagree about how full a drive is.
library;

/// Places still open. Never negative: an over-subscribed drive reads as full.
int spotsRemaining({
  required int volunteersNeeded,
  required int approvedCount,
}) {
  final remaining = volunteersNeeded - approvedCount;
  return remaining < 0 ? 0 : remaining;
}

/// Human wording for the remaining places, singular-aware.
String spotsLabel({required int volunteersNeeded, required int approvedCount}) {
  final left = spotsRemaining(
    volunteersNeeded: volunteersNeeded,
    approvedCount: approvedCount,
  );
  if (left == 0) return 'Drive full';
  if (left == 1) return '1 spot left';
  return '$left spots left';
}

/// Whether the remaining places are few enough to be worth flagging in red.
///
/// Red is a scarcity signal. Painting every drive red — including one with 25
/// of 25 places open — spends the signal on nothing and leaves nothing to say
/// when a drive really is nearly full.
bool spotsAreScarce({
  required int volunteersNeeded,
  required int approvedCount,
}) {
  final left = spotsRemaining(
    volunteersNeeded: volunteersNeeded,
    approvedCount: approvedCount,
  );
  if (left == 0) return false; // full is its own state, not urgency
  if (volunteersNeeded <= 0) return false;
  return left <= 3 || left / volunteersNeeded <= 0.2;
}
