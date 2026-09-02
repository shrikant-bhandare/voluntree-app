import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Produces a Firebase ID token the backend can verify.
///
/// The app never tells the server who the user is. It completes a real sign-in
/// with the identity provider, and hands over the resulting signed token; the
/// server decides what that token proves.
class SsoService {
  static bool _initialised = false;

  /// Web and Android need the OAuth client id from the Firebase console,
  /// supplied at build time rather than committed.
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static Future<void> _ensureInitialised() async {
    if (_initialised) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialised = true;
  }

  /// Returns a Firebase ID token, or null if the user cancelled.
  /// Throws [SsoException] when sign-in fails for any other reason.
  static Future<String?> signInWithGoogle() async {
    try {
      await _ensureInitialised();

      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();

      final googleIdToken = account.authentication.idToken;
      if (googleIdToken == null) {
        throw SsoException(
          'Google did not return an identity token. Check the OAuth client configuration.',
        );
      }

      // Exchange the Google credential for a Firebase session, because the
      // backend verifies Firebase ID tokens.
      final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final firebaseToken = await result.user?.getIdToken();
      if (firebaseToken == null) {
        throw SsoException('Could not complete sign-in. Please try again.');
      }
      return firebaseToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw SsoException(e.description ?? 'Google sign-in failed.');
    } on FirebaseAuthException catch (e) {
      throw SsoException(e.message ?? 'Sign-in was rejected by Firebase.');
    }
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
  }
}

class SsoException implements Exception {
  final String message;
  SsoException(this.message);

  @override
  String toString() => message;
}
