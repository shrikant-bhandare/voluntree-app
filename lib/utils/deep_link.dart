import 'drive_cta.dart' show liveDriveStatuses;

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The drive a link points at, or null when it is not one of ours.
///
/// Two shapes: the public share page `https://<host>/p/e/<id>` (also the
/// Android App Link) and the web app's `https://<app>/?event=<id>`.
String? eventIdFromLink(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length == 3 &&
      segments[0] == 'p' &&
      segments[1] == 'e' &&
      _uuid.hasMatch(segments[2])) {
    return segments[2];
  }
  final query = uri.queryParameters['event'];
  if (query != null && _uuid.hasMatch(query)) return query;
  return null;
}

/// What to do with a pending shared link right now.
enum DeepLinkAction { none, wait, openDrive, openGuestView }

DeepLinkAction deepLinkAction({
  required String? pendingEventId,
  required bool sessionLoading,
  required bool signedIn,
  required bool guestViewShown,
}) {
  if (pendingEventId == null) return DeepLinkAction.none;
  if (sessionLoading) return DeepLinkAction.wait;
  if (signedIn) return DeepLinkAction.openDrive;
  return guestViewShown ? DeepLinkAction.none : DeepLinkAction.openGuestView;
}

/// Drive statuses the public share page shows (the server's
/// `PUBLIC_EVENT_STATUSES`).
const Set<String> publicDriveStatuses = {
  ...liveDriveStatuses,
  'CLOSED',
  'COMPLETED',
};

/// Whether a guest who followed a shared link may see this drive.
///
/// `GET /events/:id` answers for drafts, cancelled and suspended drives too,
/// so an old link to a drive cancelled since would otherwise still advertise
/// places. The server also sends `shareUrl: null` for a drive it will not
/// share (for example one whose organizer is banned); older servers send no
/// `shareUrl` at all, and then the status decides alone.
bool guestCanSeeDrive({
  required String status,
  required bool shareUrlProvided,
  String? shareUrl,
}) {
  if (!publicDriveStatuses.contains(status)) return false;
  return !(shareUrlProvided && shareUrl == null);
}

/// Whether the guest view offers "Sign in to apply": only while the drive
/// still takes sign-ups (a FULL drive takes them onto its waitlist).
bool guestCanApply({
  required String status,
  required DateTime end,
  DateTime? now,
}) => liveDriveStatuses.contains(status) && end.isAfter(now ?? DateTime.now());
