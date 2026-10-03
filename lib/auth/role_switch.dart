import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../customer/services/api_service.dart';
import '../customer/utils/onboarding.dart' as cust;
import '../owner/services/api_service.dart';
import '../owner/utils/onboarding.dart' as own;
import 'auth_gate.dart' show kActiveRoleKey;

/// Switch the signed-in user between buying (customer) and selling (owner).
/// The same Firebase session is reused — no second Google prompt. Routing goes
/// through each side's existing gate, so a new seller is automatically sent to
/// details -> payment, while a returning one lands straight in their panel.
Future<void> switchToOwner(BuildContext context) =>
    _switch(context, toOwner: true);

Future<void> switchToCustomer(BuildContext context) =>
    _switch(context, toOwner: false);

Future<void> _switch(BuildContext context, {required bool toOwner}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(toOwner ? 'Switch to selling?' : 'Switch to buying?'),
      content: Text(toOwner
          ? "You'll continue as an owner. First-time sellers need to add "
              "business details and pay the one-time registration fee."
          : "You'll continue as a buyer — browse plots and chat with owners."),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B6B6B)),
            child: const Text('Cancel')),
        const SizedBox(width: 6),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAA3D67),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: const Text('Continue')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = user == null ? null : await user.getIdToken(true);
    if (idToken == null) {
      throw Exception('Session expired. Please sign in again.');
    }

    final prefs = await SharedPreferences.getInstance();

    if (toOwner) {
      await ApiService.googleAuth(idToken); // /auth/google
      await prefs.setString(kActiveRoleKey, 'owner');
      final me = await ApiService.getMe();
      if (!context.mounted) return;
      Navigator.pop(context); // remove loading spinner
      own.routeAfterAuth(context, me['owner'] as Map<String, dynamic>?);
    } else {
      await Api.googleSignIn(idToken); // /customers/google
      await prefs.setString(kActiveRoleKey, 'customer');
      final me = await Api.getMe();
      if (!context.mounted) return;
      Navigator.pop(context);
      cust.routeAfterAuth(context, me['customer'] as Map<String, dynamic>?);
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // remove loading spinner
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }
}
