import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../utils/deep_link.dart';

/// Holds the drive from a shared link until it can be opened.
///
/// Android delivers App Links through `app_links` (cold start and while
/// running); the web build only has the address it was opened with.
class DeepLinkService extends ChangeNotifier {
  String? _pendingEventId;
  bool _guestViewShown = false;
  StreamSubscription<Uri>? _subscription;

  String? get pendingEventId => _pendingEventId;
  bool get guestViewShown => _guestViewShown;

  void start() {
    if (kIsWeb) {
      handle(Uri.base);
      return;
    }
    _subscription = AppLinks().uriLinkStream.listen(
      handle,
      onError: (Object e) => debugPrint('[DEEP LINK] $e'),
    );
  }

  void handle(Uri uri) {
    final id = eventIdFromLink(uri);
    if (id == null) return;
    _pendingEventId = id;
    _guestViewShown = false;
    notifyListeners();
  }

  /// Takes the pending drive; each link opens once.
  String? take() {
    final id = _pendingEventId;
    _pendingEventId = null;
    _guestViewShown = false;
    return id;
  }

  void markGuestViewShown() {
    _guestViewShown = true;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
