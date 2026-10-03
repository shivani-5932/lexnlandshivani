/// Result of opening the Razorpay checkout, shared across web + mobile impls.
class CheckoutResult {
  final bool success;
  final bool cancelled;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;

  const CheckoutResult._({
    required this.success,
    required this.cancelled,
    this.paymentId,
    this.orderId,
    this.signature,
    this.error,
  });

  const CheckoutResult.success(String payment, String order, String sign)
      : this._(
          success: true,
          cancelled: false,
          paymentId: payment,
          orderId: order,
          signature: sign,
        );

  const CheckoutResult.cancelled()
      : this._(success: false, cancelled: true);

  const CheckoutResult.failed(String message)
      : this._(success: false, cancelled: false, error: message);
}
