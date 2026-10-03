// Picks the right checkout implementation at compile time:
//   • Flutter Web  → checkout_web.dart   (checkout.js)
//   • Android/iOS  → checkout_mobile.dart (razorpay_flutter)
//   • otherwise    → checkout_stub.dart
export 'checkout_data.dart';
export 'checkout_stub.dart'
    if (dart.library.html) 'checkout_web.dart'
    if (dart.library.io) 'checkout_mobile.dart';
