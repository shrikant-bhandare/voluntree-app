import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sso_service.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final input = _identifierController.text.trim();

    // Check if input is email or phone number
    final isEmail = input.contains('@');
    final email = isEmail ? input : null;
    final phone = !isEmail ? input : null;

    final result = await authService.requestOtp(
      email: email,
      phoneNumber: phone,
    );

    if (mounted) {
      if (result['success']) {
        // otpInDev is only ever present outside production; in a real build
        // the code arrives by email or SMS and nothing is shown here.
        final devOtp = result['otpInDev'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              devOtp != null
                  ? '${result['message']} (dev code: $devOtp)'
                  : result['message'],
            ),
            backgroundColor: const Color(
              0xFF0E6C4A,
            ), // Voluntree Secondary Green
            duration: const Duration(seconds: 6),
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtpScreen(email: email, phoneNumber: phone),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: const Color(0xFFBA1A1A), // Voluntree Error Red
          ),
        );
      }
    }
  }

  /// Real provider sign-in.
  ///
  /// This used to ask the user to type any email address and posted it to the
  /// server, which trusted it — so anyone could sign in as anyone. Now the app
  /// completes an actual Google sign-in and forwards the signed token.
  void _handleSsoLogin(BuildContext context, String provider) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final idToken = await SsoService.signInWithGoogle();
      if (idToken == null) return; // user cancelled

      final res = await authService.ssoLogin(
        idToken: idToken,
        provider: 'google',
      );

      if (!mounted) return;
      if (res['success']) {
        messenger.showSnackBar(
          SnackBar(content: Text('Signed in with $provider.')),
        );
        // No manual navigation: AuthGate swaps to HomeScreen when
        // isAuthenticated flips — pushing here stacked a second HomeScreen.
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Sign-in failed'),
            backgroundColor: const Color(0xFFBA1A1A),
          ),
        );
      }
    } on SsoException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFBA1A1A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = Provider.of<AuthService>(context).isLoading;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or App Icon
                Center(
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Voluntree',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect. Support. Impact.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF717973), // Voluntree Outline Grey
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Login Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(
                        0xFFE8EFF1,
                      ), // Voluntree Surface Container border
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.04,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Secure Login',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _identifierController,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Enter Email or Mobile Number',
                            hintStyle: const TextStyle(
                              color: Color(0xFF717973),
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: theme.colorScheme.secondary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF4FAFD),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE8EFF1),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                                width: 1.5,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter email or phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Send OTP Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      "New to the community? ",
                      style: TextStyle(
                        color: Color(0xFF717973),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Register Now',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Native Google/Apple SSO isn't wired up for web (google_sign_in
                // v7 needs the renderButton flow there), so the web build is
                // OTP-only.
                if (!kIsWeb) ...[
                  // OR SIGN UP WITH Divider
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(
                          color: Color(0xFFD0D7DE),
                          thickness: 1,
                          endIndent: 16,
                        ),
                      ),
                      Text(
                        'OR SIGN UP WITH',
                        style: TextStyle(
                          color: Color(0xFF6A737D),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Color(0xFFD0D7DE),
                          thickness: 1,
                          indent: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Social Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleSsoLogin(context, 'Google'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFD0D7DE),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF24292E),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B192C),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.laptop_mac,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF24292E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // The Apple button was removed: it silently performed a
                      // Google sign-in (no Apple flow exists yet). Restore it
                      // only alongside a real Sign in with Apple integration.
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Terms & Privacy footer
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF57606A),
                      fontSize: 12,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'By joining, you agree to our '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
