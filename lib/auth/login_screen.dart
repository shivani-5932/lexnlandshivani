import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../customer/theme/app_theme.dart';
import 'role_select_screen.dart';
import '../owner/services/api_service.dart';

/// First-run entry: a single "Continue with Google" button. After Firebase
/// auth succeeds we hand the idToken to the role-select screen, which decides
/// whether to register the user as a buyer (customer) or seller (owner).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    late UserCredential cred;

    if (kIsWeb) {
      // WEB
      // Use Firebase's popup flow instead of GoogleSignIn.authenticate(),
      // because authenticate() is not supported by google_sign_in on Web.
      final provider = GoogleAuthProvider();

      cred = await FirebaseAuth.instance.signInWithPopup(provider);
    } else {
      // ANDROID / iOS
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      cred = await FirebaseAuth.instance.signInWithCredential(credential);
    }

    final user = cred.user;

    if (user == null) {
      throw Exception('Google sign-in failed. Try again.');
    }

    final idToken = await user.getIdToken();

    if (idToken == null) {
      throw Exception('Could not get authentication token.');
    }

    // Check which profiles already exist.
    String? autoRole;

    try {
      final status = await ApiService.profileStatus(idToken);

      final hasCustomer = status['hasCustomer'] == true;
      final hasOwner = status['hasOwner'] == true;

      if (hasCustomer && !hasOwner) {
        autoRole = 'customer';
      } else if (hasOwner && !hasCustomer) {
        autoRole = 'owner';
      }
    } catch (_) {
      autoRole = null;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoleSelectScreen(
          idToken: idToken,
          autoRole: autoRole,
        ),
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'popup-closed-by-user' ||
        e.code == 'cancelled-popup-request') {
      // User closed/cancelled Google sign-in.
    } else {
      setState(() {
        _error = e.message ?? 'Google sign-in failed.';
      });
    }
  } catch (e) {
    setState(() {
      _error = e.toString().replaceAll('Exception: ', '');
    });
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/signin_illustration.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              const Text('LexNLand',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Buy or sell verified plots',
                  style: TextStyle(fontSize: 14, color: C.textMuted)),
              const SizedBox(height: 40),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.errorBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: C.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _loading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: C.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: C.primary))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('G',
                                style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18)),
                            SizedBox(width: 12),
                            Text('Continue with Google',
                                style: TextStyle(
                                    color: C.textDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
