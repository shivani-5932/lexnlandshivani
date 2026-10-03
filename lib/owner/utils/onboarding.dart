import 'package:flutter/material.dart';
import '../screens/main_shell.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/onboarding_payment_screen.dart';

/// An owner profile counts as complete once the business details are filled.
bool isProfileComplete(Map<String, dynamic>? o) {
  if (o == null) return false;
  String s(String k) => (o[k] ?? '').toString().trim();
  return s('gender').isNotEmpty &&
      s('occupation').isNotEmpty &&
      s('businessName').isNotEmpty &&
      s('address').isNotEmpty &&
      s('city').isNotEmpty &&
      s('state').isNotEmpty &&
      s('pincode').isNotEmpty;
}

/// After sign-in / app launch: complete profiles enter the app; new or
/// incomplete ones are sent to the onboarding profile form first.
/// (A payment step will be inserted between onboarding and the app later.)
void routeAfterAuth(BuildContext context, Map<String, dynamic>? owner) {
  final Widget next;
  if (!isProfileComplete(owner)) {
    // New / incomplete owner → fill business details first.
    next = EditProfileScreen(
        owner: owner ?? <String, dynamic>{}, isOnboarding: true);
  }
  // ── PAYMENT GATE DISABLED — owners register for free ──
  // else if (owner?['isPaid'] != true) {
  //   // Details done but registration fee unpaid → payment gate.
  //   next = const OnboardingPaymentScreen();
  // }
  else {
    next = const MainShell();
  }
  Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => next), (_) => false);
}
