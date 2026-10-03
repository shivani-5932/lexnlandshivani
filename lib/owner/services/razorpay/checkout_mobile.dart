import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'checkout_data.dart';

/// Native Android/iOS checkout via the razorpay_flutter plugin.
Future<CheckoutResult> openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amount,
  required String currency,
  required String name,
  required String email,
  required String phone,
}) {
  final completer = Completer<CheckoutResult>();
  final razorpay = Razorpay();

  void finish(CheckoutResult r) {
    if (!completer.isCompleted) completer.complete(r);
    razorpay.clear(); // removes listeners + releases resources
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    finish(CheckoutResult.success(
      r.paymentId ?? '',
      r.orderId ?? orderId,
      r.signature ?? '',
    ));
  });

  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (r.code == Razorpay.PAYMENT_CANCELLED) {
      finish(const CheckoutResult.cancelled());
    } else {
      finish(CheckoutResult.failed(r.message ?? 'Payment failed. Please try again.'));
    }
  });

  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
    // External wallet selected — treated as not-yet-completed; let the
    // user retry. (No paid state is set without a verified signature.)
    finish(const CheckoutResult.cancelled());
  });

  try {
    razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': amount,
      'currency': currency,
      'name': 'LexNLand',
      'description': 'Owner Registration Fee',
      'prefill': {'name': name, 'email': email, 'contact': phone},
      'theme': {'color': '#B05A38'},
    });
  } catch (e) {
    finish(CheckoutResult.failed('Could not open checkout: $e'));
  }

  return completer.future;
}
