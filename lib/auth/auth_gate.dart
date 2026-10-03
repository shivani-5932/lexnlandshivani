import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../customer/services/api_service.dart';
import '../customer/utils/onboarding.dart' as cust;
import '../owner/services/api_service.dart';
import '../owner/utils/onboarding.dart' as own;
import 'login_screen.dart';

/// Key that remembers which side the user last entered the app as.
const kActiveRoleKey = 'active_role';

/// Decides where to send the user on launch:
///  - returning customer  -> customer panel (or onboarding if incomplete)
///  - returning owner      -> owner details / payment / panel
///  - everyone else        -> the shared Google login
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString(kActiveRoleKey);

    final custToken = await Api.getToken();
    final ownerToken = await ApiService.getToken();
    role ??= custToken != null
        ? 'customer'
        : (ownerToken != null ? 'owner' : null);

    // ── Owner session ──
    if (role == 'owner' && ownerToken != null) {
      final cached = await ApiService.getSavedOwner();
      // Established owner (complete profile cached) → straight in, even if the
      // backend is cold/unreachable. Refresh quietly in the background.
      if (cached != null && own.isProfileComplete(cached)) {
        if (!mounted) return;
        own.routeAfterAuth(context, cached);
        _refreshOwner();
        return;
      }
      // Cache is incomplete/missing — fetch the authoritative status before
      // deciding, giving a cold Render backend time to wake so we don't
      // wrongly send an established owner back through onboarding.
      Map<String, dynamic>? owner = cached;
      try {
        final me =
            await ApiService.getMe().timeout(const Duration(seconds: 20));
        final fresh = me['owner'] as Map<String, dynamic>?;
        if (fresh != null) {
          owner = fresh;
          await ApiService.saveOwner(fresh);
        }
      } catch (e) {
        // Suspended → sign out. Network / Render cold-start / timeout →
        // keep the cached session so the user is NOT thrown back to login.
        if (_isSuspended(e)) {
          await ApiService.logout();
          if (mounted) _goLogin();
          return;
        }
      }
      if (!mounted) return;
      if (owner != null) {
        own.routeAfterAuth(context, owner);
      } else {
        _goLogin();
      }
      return;
    }

    // ── Customer session ──
    if (role == 'customer' && custToken != null) {
      Map<String, dynamic>? user = await Api.getUser();
      try {
        final me = await Api.getMe().timeout(const Duration(seconds: 8));
        final fresh = me['customer'] as Map<String, dynamic>?;
        if (fresh != null) user = fresh; // getMe already caches it
      } catch (e) {
        if (_isSuspended(e)) {
          await Api.logout();
          if (mounted) _goLogin();
          return;
        }
      }
      if (!mounted) return;
      if (user != null) {
        cust.routeAfterAuth(context, user);
      } else {
        _goLogin();
      }
      return;
    }

    // ── No session → login ──
    if (!mounted) return;
    _goLogin();
  }

  bool _isSuspended(Object e) =>
      e.toString().toLowerCase().contains('suspend');

  // Fire-and-forget: refresh the owner profile + cache without blocking the
  // launch (used when we've already routed an established owner straight in).
  void _refreshOwner() {
    ApiService.getMe().then((me) {
      final fresh = me['owner'] as Map<String, dynamic>?;
      if (fresh != null) ApiService.saveOwner(fresh);
    }).catchError((_) {});
  }

  void _goLogin() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo_lexnland.png', width: 120),
            const SizedBox(height: 24),
            SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: c)),
          ],
        ),
      ),
    );
  }
}
