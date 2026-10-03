import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class OnboardingPaymentScreen extends StatefulWidget {
  const OnboardingPaymentScreen({super.key});
  @override
  State<OnboardingPaymentScreen> createState() =>
      _OnboardingPaymentScreenState();
}

class _OnboardingPaymentScreenState extends State<OnboardingPaymentScreen> {
  final _business = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _idNumber = TextEditingController();

  bool _loading = true;
  bool _paying = false;
  bool _awaiting = false; // payment opened, waiting for completion
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkPaid();
  }

  Future<void> _checkPaid() async {
    try {
      final res = await ApiService.getMe();
      final owner = res['owner'] as Map<String, dynamic>?;
      if (owner != null && owner['isPaid'] == true) {
        _goHome();
        return;
      }
      if (owner != null) {
        _business.text = owner['businessName'] ?? '';
        _address.text = owner['address'] ?? '';
        _city.text = owner['city'] ?? '';
        _state.text = owner['state'] ?? '';
        _pincode.text = owner['pincode'] ?? '';
        _idNumber.text = owner['idNumber'] ?? '';
      }
    } catch (_) {/* show form */}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (final c in [_business, _address, _city, _state, _pincode, _idNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
  }

  Future<void> _signOut() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success));
  }

  Future<void> _startPayment() async {
    if ([_business, _address, _city, _state, _pincode, _idNumber]
        .any((c) => c.text.trim().isEmpty)) {
      _snack('Please fill in all the details', error: true);
      return;
    }
    setState(() => _paying = true);
    try {
      await ApiService.saveOwnerDetails({
        'businessName': _business.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pincode.text.trim(),
        'idNumber': _idNumber.text.trim(),
      });

      final res = await ApiService.createPaymentLink();
      final url = res['url'] as String?;
      if (url == null || url.isEmpty) {
        _snack('Could not start payment', error: true);
        return;
      }

      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        _snack('Could not open the payment page', error: true);
        return;
      }

      setState(() => _awaiting = true);
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
          const Duration(seconds: 4), (_) => _checkStatus(auto: true));
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _checkStatus({bool auto = false}) async {
    try {
      final res = await ApiService.paymentStatus();
      if (res['isPaid'] == true) {
        _pollTimer?.cancel();
        _snack('Payment successful! Your account is active.');
        await Future.delayed(const Duration(milliseconds: 600));
        _goHome();
      } else if (!auto) {
        _snack(
            'Payment not completed yet. Finish it in the opened page, then tap again.',
            error: true);
      }
    } catch (_) {
      if (!auto) _snack('Could not check payment status', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complete Registration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _signOut,
            child:
                const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _awaiting ? _waitingView() : _formView(),
              ),
            ),
    );
  }

  Widget _formView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('A few more details',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark)),
      const SizedBox(height: 4),
      const Text(
          'Tell us about your business, then pay the one-time registration fee to activate your account.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      const SizedBox(height: 22),
      _field('Business name', _business, Icons.storefront_outlined),
      _field('Address', _address, Icons.location_on_outlined),
      Row(children: [
        Expanded(child: _field('City', _city, Icons.location_city_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _field('State', _state, Icons.map_outlined)),
      ]),
      _field('PIN code', _pincode, Icons.markunread_mailbox_outlined,
          number: true, maxLen: 6),
      _field('Aadhaar / PAN number', _idNumber, Icons.badge_outlined),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.workspace_premium_outlined,
              color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
              child: Text('One-time registration fee',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark))),
          const Text('₹100',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _paying ? null : _startPayment,
          icon: _paying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.lock_outline_rounded, size: 18),
          label: Text(_paying ? 'Opening payment…' : 'Pay ₹100 & Activate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Center(
          child: Text('Secured by Razorpay',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
    ]);
  }

  Widget _waitingView() {
    return Column(children: [
      const SizedBox(height: 30),
      const Icon(Icons.hourglass_top_rounded,
          size: 64, color: AppColors.primary),
      const SizedBox(height: 16),
      const Text('Waiting for payment',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark)),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
            'Finish the payment in the page that opened. This screen will update automatically once it\'s done.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ),
      const SizedBox(height: 24),
      const CircularProgressIndicator(color: AppColors.primary),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _checkStatus(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text("I've completed payment"),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _paying ? null : _startPayment,
        child: const Text('Open payment page again'),
      ),
    ]);
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {bool number = false, int? maxLen}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLength: maxLen,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
          filled: true,
          fillColor: Colors.white,
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
        ),
      ),
    );
  }
}
