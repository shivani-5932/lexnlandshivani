import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'main_shell.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';
import 'payment_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _gLoading = false;
  bool _obscure = true;

  // Login is Google-only for now. Flip this to true to bring back the
  // email/password + register UI (the code below is kept intact).
  bool _showEmailLogin = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // ── Firebase Google Sign In (Web popup) ─────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _gLoading = true);
    try {
      // Use Firebase's built-in Google provider — no clientId needed!
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // signInWithPopup is web-only; on Android/iOS use signInWithProvider
      // (opens the OAuth flow in a Custom Tab / browser).
      final UserCredential userCred = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(googleProvider)
          : await FirebaseAuth.instance.signInWithProvider(googleProvider);

      final User? firebaseUser = userCred.user;
      if (firebaseUser == null) throw Exception('Sign in failed. Try again.');

      // Get Firebase ID token → send to our backend
      final String? idToken = await firebaseUser.getIdToken();
      if (idToken == null)
        throw Exception('Could not get authentication token');

      // Backend creates/finds owner in MongoDB
      await ApiService.googleAuth(idToken);
      _goHome();
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'popup-closed-by-user':
          msg = 'Sign in was cancelled';
          break;
        case 'popup-blocked':
          msg = 'Popup was blocked. Please allow popups for this site.';
          break;
        case 'network-request-failed':
          msg = 'Network error. Check your internet connection.';
          break;
        case 'invalid-credential':
          msg =
              'Invalid credentials. Make sure Firebase is configured correctly.';
          break;
        default:
          msg = e.message ?? 'Google sign-in failed';
      }
      _showError(msg);
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('popup_closed') || msg.contains('cancelled')) {
        msg = 'Sign in was cancelled';
      }
      _showError(msg);
    } finally {
      if (mounted) setState(() => _gLoading = false);
    }
  }

  // ── Email / Password ─────────────────────────────────────
  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        final data = await ApiService.login(email: email, password: password);
        if (data['requiresVerification'] == true) {
          _goToOTP(email, 'verify', devOtp: data['devOtp']?.toString());
        } else {
          _goHome();
        }
      } else {
        final name = _nameCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();
        if (name.isEmpty) {
          _showError('Please enter your name');
          return;
        }
        final data = await ApiService.register(
          name: name,
          email: email,
          phone: phone,
          password: password,
        );
        _goToOTP(email, 'verify', devOtp: data['devOtp']?.toString());
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    // PAYMENT DISABLED — owners register for free and go straight in.
    // final owner = await ApiService.getSavedOwner();
    // final paid = owner?['isPaid'] == true;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => const MainShell()),
        // builder: (_) => paid ? const MainShell() : const PaymentScreen()),
        (r) => false);
  }

  void _goToOTP(String email, String type, {String? devOtp}) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: email, type: type, devOtp: devOtp),
        ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Logo ──
              Row(children: [
                Image.asset('assets/images/logo_lexnland.png', width: 72),
              ]),

              const SizedBox(height: 36),

              Text(_isLogin ? 'Welcome back!' : 'Create Account',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(
                _isLogin
                    ? 'Sign in to manage your properties'
                    : 'Join as a property owner',
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),

              const SizedBox(height: 28),

              // ── Google Button ──
              _GoogleButton(loading: _gLoading, onTap: _signInWithGoogle),

              const SizedBox(height: 20),

              // ── Email / password + Register (DISABLED: Google-only) ──
              if (_showEmailLogin) ...[
              // ── Divider ──
              Row(children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or use email',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ]),

              const SizedBox(height: 20),

              // ── Register only ──
              if (!_isLogin) ...[
                _InputField(
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    ctrl: _nameCtrl,
                    icon: Icons.person_outline_rounded),
                const SizedBox(height: 14),
                _InputField(
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    ctrl: _phoneCtrl,
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 14),
              ],

              // ── Email ──
              _InputField(
                  label: 'Email',
                  hint: 'Enter your email',
                  ctrl: _emailCtrl,
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),

              // ── Password ──
              _PasswordInput(
                  ctrl: _passwordCtrl,
                  obscure: _obscure,
                  onToggle: () => setState(() => _obscure = !_obscure)),

              // ── Forgot Password ──
              if (_isLogin) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen())),
                    child: const Text('Forgot Password?',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Submit Button ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(_isLogin ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),

              // ── Toggle ──
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isLogin = !_isLogin;
                    _emailCtrl.clear();
                    _passwordCtrl.clear();
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : 'Already have an account? ',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        TextSpan(
                          text: _isLogin ? 'Register' : 'Sign In',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ], // end if (_showEmailLogin)

              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ── Google Button ─────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Google G icon
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4)
                    ],
                  ),
                  child: const Center(
                    child: Text('G',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4285F4))),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Continue with Google',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ]),
      ),
    );
  }
}

// ── Input Field ───────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboard;

  const _InputField({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.icon,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.6)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
    ]);
  }
}

// ── Password Input ────────────────────────────────────────────
class _PasswordInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool obscure;
  final VoidCallback onToggle;
  const _PasswordInput(
      {required this.ctrl, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('PASSWORD',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.6)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: 'Enter your password',
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: AppColors.textLight, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight,
                size: 20),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
    ]);
  }
}
