import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;

/// Environment configuration.
///
/// The API host comes from a compile-time define so the same source builds for
/// local, staging and production without editing code:
///
///   flutter run   --dart-define=API_BASE_URL=http://10.0.2.2:3000
///   flutter build --dart-define=API_BASE_URL=https://api.voluntree.org
class AppConfig {
  /// End-to-end encryption is scaffolded but not finished. It stays off until
  /// key exchange and recovery are implemented — a half-wired flag would imply
  /// a guarantee the app does not make.
  static const bool enableE2EE = false;

  /// Payments are not integrated with a gateway yet (the API answers 503).
  /// Every donate/subscribe/promote entry point stays hidden unless a build
  /// passes `--dart-define=PAYMENTS_ENABLED=true`.
  static const bool paymentsEnabled = bool.fromEnvironment(
    'PAYMENTS_ENABLED',
    defaultValue: false,
  );

  /// Hosted legal documents, supplied per build:
  ///   --dart-define=TERMS_URL=https://... --dart-define=PRIVACY_URL=https://...
  /// Empty means "not published yet"; the links then explain that instead of
  /// doing nothing.
  static const String termsUrl = String.fromEnvironment('TERMS_URL');
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Android emulators reach the host machine on 10.0.2.2, never localhost.
  static const String _androidDevFallback = 'http://10.0.2.2:3000';
  static const String _defaultDevFallback = 'http://localhost:3000';

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _stripTrailingSlash(_configuredBaseUrl);
    }

    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL was not provided at build time. Rebuild with '
        '--dart-define=API_BASE_URL=https://your-api-host',
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _androidDevFallback;
    }
    return _defaultDevFallback;
  }

  /// True when the API is a local development server. A dev OTP returned by
  /// the API (`otpInDev`) is only ever displayed in that case.
  static bool get isLocalApi {
    final host = Uri.tryParse(baseUrl)?.host ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host == '[::1]' ||
        host == '::1';
  }

  /// True when talking to the API over plaintext HTTP. Release builds must not.
  static bool get isInsecureTransport => !baseUrl.startsWith('https://');

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Rewrite any media URL so it resolves against the active backend host.
  /// Stored URLs may carry a host from another environment.
  ///
  /// Returns null (never '') for a missing URL: converting null to '' made
  /// every `!= null` guard pass and fed the empty string to Image.network,
  /// which throws "No host specified".
  static String? formatMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();

    const staleHosts = ['localhost:3000', '10.0.2.2:3000', '127.0.0.1:3000'];

    if (staleHosts.any(trimmed.contains)) {
      final path = Uri.parse(trimmed).path;
      return '$baseUrl$path';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '$baseUrl$trimmed';
    }
    return '$baseUrl/$trimmed';
  }
}
