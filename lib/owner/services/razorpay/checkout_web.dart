import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'checkout_data.dart';

// Reads a string property off a JS response object, safely.
String _readString(JSObject obj, String key) {
  final v = obj.getProperty(key.toJS);
  return v.dartify()?.toString() ?? '';
}

/// Flutter Web: opens Razorpay checkout via the checkout.js script that is
/// loaded in web/index.html. Uses the modern dart:js_interop API.
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
  void done(CheckoutResult r) {
    if (!completer.isCompleted) completer.complete(r);
  }

  final ctorAny = globalContext.getProperty('Razorpay'.toJS);
  if (ctorAny.isUndefinedOrNull) {
    return Future.value(const CheckoutResult.failed(
        'Payment library failed to load. Check your connection and retry.'));
  }

  // Build the options object.
  final options = JSObject();
  options.setProperty('key'.toJS, keyId.toJS);
  options.setProperty('order_id'.toJS, orderId.toJS);
  options.setProperty('amount'.toJS, amount.toJS);
  options.setProperty('currency'.toJS, currency.toJS);
  options.setProperty('name'.toJS, 'LexNLand'.toJS);
  options.setProperty('description'.toJS, 'Owner Registration Fee'.toJS);

  final prefill = JSObject();
  prefill.setProperty('name'.toJS, name.toJS);
  prefill.setProperty('email'.toJS, email.toJS);
  prefill.setProperty('contact'.toJS, phone.toJS);
  options.setProperty('prefill'.toJS, prefill);

  final theme = JSObject();
  theme.setProperty('color'.toJS, '#B05A38'.toJS);
  options.setProperty('theme'.toJS, theme);

  // Success handler.
  options.setProperty(
    'handler'.toJS,
    ((JSObject resp) {
      done(CheckoutResult.success(
        _readString(resp, 'razorpay_payment_id'),
        _readString(resp, 'razorpay_order_id'),
        _readString(resp, 'razorpay_signature'),
      ));
    }).toJS,
  );

  // Modal dismiss (user closed without paying).
  final modal = JSObject();
  modal.setProperty(
    'ondismiss'.toJS,
    (() => done(const CheckoutResult.cancelled())).toJS,
  );
  options.setProperty('modal'.toJS, modal);

  try {
    final ctor = ctorAny as JSFunction;
    final rzp = ctor.callAsConstructor<JSObject>(options);

    final failHandler = ((JSObject resp) {
      String msg = 'Payment failed. Please try again.';
      final err = resp.getProperty('error'.toJS).dartify();
      if (err is Map && err['description'] != null) {
        msg = err['description'].toString();
      }
      done(CheckoutResult.failed(msg));
    }).toJS;

    rzp.callMethod<JSAny?>('on'.toJS, 'payment.failed'.toJS, failHandler);
    rzp.callMethod<JSAny?>('open'.toJS);
  } catch (e) {
    done(CheckoutResult.failed('Could not open checkout: $e'));
  }

  return completer.future;
}
