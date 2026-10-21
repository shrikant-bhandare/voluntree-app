import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

/// Opens a hosted policy document, or says plainly that it is not published
/// yet. A link that does nothing on tap reads as broken.
Future<void> openPolicyLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  if (url.trim().isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Policy link coming soon')),
    );
    return;
  }
  final ok = await launchUrl(
    Uri.parse(url.trim()),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the link.')),
    );
  }
}

/// Tappable "Terms of Service" / "Privacy Policy" spans for a [Text.rich].
/// The caller owns the recognizers' lifetime via [PolicyLinkRecognizers].
class PolicyLinkRecognizers {
  final TapGestureRecognizer terms;
  final TapGestureRecognizer privacy;

  PolicyLinkRecognizers(BuildContext Function() contextOf)
    : terms = TapGestureRecognizer()
        ..onTap = (() => openPolicyLink(contextOf(), AppConfig.termsUrl)),
      privacy = TapGestureRecognizer()
        ..onTap = (() => openPolicyLink(contextOf(), AppConfig.privacyUrl));

  void dispose() {
    terms.dispose();
    privacy.dispose();
  }
}
