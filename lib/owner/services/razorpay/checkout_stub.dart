import 'checkout_data.dart';

/// Fallback used only if neither web nor mobile is detected.
Future<CheckoutResult> openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amount,
  required String currency,
  required String name,
  required String email,
  required String phone,
}) async {
  return const CheckoutResult.failed('Payments are not supported on this platform.');
}
