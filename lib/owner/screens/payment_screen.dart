import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/razorpay_service.dart';
import 'main_shell.dart';

/// One-time ₹100 owner registration fee.
///
/// Shown as a gate right after sign-in for owners who haven't paid
/// (with a "Pay later" option), and also opened from the Profile tab
/// via the "Complete Payment" banner ([fromProfile] = true).
class PaymentScreen extends StatefulWidget {
  /// When true, the screen was opened from Profile — success pops back
  /// with `true`. When false, it's the post-login gate — success and
  /// "Pay later" both continue into the app.
  final bool fromProfile;
  const PaymentScreen({super.key, this.fromProfile = false});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    final result = await RazorpayService.payRegistrationFee();
    if (!mounted) return;
    setState(() => _paying = false);

    switch (result.status) {
      case PaymentStatus.success:
      case PaymentStatus.alreadyPaid:
        _onPaid();
        break;
      case PaymentStatus.cancelled:
        _snack('Payment cancelled. You can pay anytime from your profile.',
            AppColors.textMuted);
        break;
      case PaymentStatus.failed:
        _snack(result.message ?? 'Payment failed. Please try again.',
            AppColors.error);
        break;
    }
  }

  void _onPaid() {
    _snack(
        '✅ Payment successful! Your account is now active.', AppColors.success);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (widget.fromProfile) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
      }
    });
  }

  void _payLater() {
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.fromProfile
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: const BackButton(color: AppColors.textDark),
              title: const Text('Complete Payment',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.textDark)),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Badge
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      size: 48, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),

              const Text('One-Time Registration Fee',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                'Pay a one-time fee to activate your owner account and start listing properties.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Amount card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Amount payable',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    const Text('₹100',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 13,
                            color: AppColors.textMuted.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        const Text('Secured by Razorpay',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Pay button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _paying ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _paying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Pay ₹100',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),

              if (!widget.fromProfile) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _paying ? null : _payLater,
                  child: const Text('Pay later',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
