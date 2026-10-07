/// Whether a list-backed section is still loading, failed to load, genuinely
/// empty, or ready.
///
/// "No results", "we could not reach the server" and "not asked yet" look
/// identical if you only test `list.isEmpty`. That is how the organizer
/// dashboard came to announce "No active events published." to an organizer
/// who had five drives, and how a dropped request on the discover screen
/// reads as "No matching events found".
///
/// An empty state is a factual claim about the account, so it has to wait for
/// evidence — and a failure has to say so, because the remedy is "retry", not
/// "change your filters".
library;

enum ListState { loading, failed, empty, ready }

ListState listStateFor({
  required bool hasLoaded,
  required int count,
  bool failed = false,
}) {
  if (!hasLoaded) return ListState.loading;
  // Failure outranks whatever is left in the cache: showing stale rows as if
  // they were fresh is what the degraded-state work on the admin dashboard
  // set out to stop.
  if (failed) return ListState.failed;
  return count == 0 ? ListState.empty : ListState.ready;
}
