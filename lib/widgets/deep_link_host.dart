import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/event_detail_screen.dart';
import '../screens/public_event_screen.dart';
import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import '../utils/deep_link.dart';

/// Opens a shared drive once the app knows who is using it: the drive itself
/// for a signed-in person, a guest view for anyone else. A guest who chooses
/// "Sign in to apply" keeps the link, so the drive opens right after login;
/// a guest who backs out drops it.
class DeepLinkHost extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const DeepLinkHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  State<DeepLinkHost> createState() => _DeepLinkHostState();
}

class _DeepLinkHostState extends State<DeepLinkHost> {
  late final DeepLinkService _links;
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _links = Provider.of<DeepLinkService>(context, listen: false);
    _auth = Provider.of<AuthService>(context, listen: false);
    _links.addListener(_onLinkChanged);
    _auth.addListener(_onAuthChanged);
    // The navigator below this widget is built in the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _links.removeListener(_onLinkChanged);
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onLinkChanged() => _check();

  /// An auth change that makes a pending link openable is a sign-in: the
  /// saved session read at start-up, or a guest who just logged in.
  void _onAuthChanged() => _check(afterSignIn: true);

  void _check({bool afterSignIn = false}) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    final action = deepLinkAction(
      pendingEventId: _links.pendingEventId,
      // Until the saved session has been read a signed-in person looks
      // signed out, and on an Android cold start the link can arrive first.
      sessionLoading:
          !_auth.sessionRestored ||
          (_auth.isLoading && _auth.token != null && _auth.currentUser == null),
      signedIn: _auth.isAuthenticated,
      guestViewShown: _links.guestViewShown,
    );
    switch (action) {
      case DeepLinkAction.openDrive:
        final id = _links.take();
        if (id == null) return;
        if (afterSignIn) {
          _openDriveAfterSignIn(id);
        } else {
          navigator.push(_driveRoute(id));
        }
      case DeepLinkAction.openGuestView:
        final id = _links.pendingEventId!;
        _links.markGuestViewShown();
        navigator
            .push<bool>(
              MaterialPageRoute(builder: (_) => PublicEventScreen(eventId: id)),
            )
            .then((wantsToSignIn) {
              // Drop only this link: a newer one may have arrived meanwhile.
              if (wantsToSignIn != true && _links.pendingEventId == id) {
                _links.take();
              }
            });
      case DeepLinkAction.wait:
      case DeepLinkAction.none:
        break;
    }
  }

  /// Listeners hear about a new session before the sign-in screens close:
  /// OtpScreen pops back to the first route right after verifying, which
  /// closed a drive pushed straight away, and the link was already taken.
  /// So the drive opens after this frame, on top of the first route.
  void _openDriveAfterSignIn(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) return;
      navigator.popUntil((route) => route.isFirst);
      navigator.push(_driveRoute(id));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Route<void> _driveRoute(String id) =>
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: id));

  @override
  Widget build(BuildContext context) => widget.child;
}
