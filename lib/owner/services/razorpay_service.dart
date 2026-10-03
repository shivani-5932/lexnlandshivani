import 'api_service.dart';
import 'razorpay/razorpay_checkout.dart';

enum PaymentStatus { success, cancelled, failed, alreadyPaid }

class PaymentResult {
  final PaymentStatus status;
  final String? message;
  const PaymentResult(this.status, [this.message]);

  bool get isSuccess => status == PaymentStatus.success;
}

/// Orchestrates the ₹100 registration-fee flow. Platform-agnostic — the
/// actual checkout modal is opened by the conditionally-imported
/// `openRazorpayCheckout` (checkout.js on web, razorpay_flutter on mobile).
class RazorpayService {
  static Future<PaymentResult> payRegistrationFee() async {
    // 1. Create the order on the backend (amount + secret stay server-side).
    Map<String, dynamic> order;
    try {
      order = await ApiService.createPaymentOrder();
    } catch (e) {
      return PaymentResult(
          PaymentStatus.failed, e.toString().replaceAll('Exception: ', ''));
    }

    if (order['alreadyPaid'] == true) {
      return const PaymentResult(PaymentStatus.alreadyPaid);
    }

    final owner = await ApiService.getSavedOwner() ?? {};

    // 2. Open the checkout and wait for the user.
    final result = await openRazorpayCheckout(
      keyId: order['keyId'] as String,
      orderId: order['orderId'] as String,
      amount: (order['amount'] as num).toInt(),
      currency: (order['currency'] as String?) ?? 'INR',
      name: (owner['name'] as String?) ?? '',
      email: (owner['email'] as String?) ?? '',
      phone: (owner['phone']?.toString()) ?? '',
    );

    if (result.cancelled) return const PaymentResult(PaymentStatus.cancelled);
    if (!result.success) {
      return PaymentResult(
          PaymentStatus.failed, result.error ?? 'Payment failed');
    }

    // 3. Verify the signature on the backend; only then is the owner "paid".
    try {
      final verify = await ApiService.verifyPayment(
        orderId: result.orderId ?? '',
        paymentId: result.paymentId ?? '',
        signature: result.signature ?? '',
      );
      if (verify['isPaid'] == true) {
        // Refresh the cached owner so isPaid is current everywhere.
        try {
          final me = await ApiService.getMe();
          final o = me['owner'] as Map<String, dynamic>?;
          if (o != null) await ApiService.saveOwner(o);
        } catch (_) {}
        return const PaymentResult(PaymentStatus.success);
      }
      return const PaymentResult(
          PaymentStatus.failed, 'Payment could not be verified.');
    } catch (e) {
      return PaymentResult(
          PaymentStatus.failed, e.toString().replaceAll('Exception: ', ''));
    }
  }
}
