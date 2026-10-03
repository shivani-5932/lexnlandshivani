import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../customer/theme/app_theme.dart';
import '../customer/services/api_service.dart';
import '../customer/utils/onboarding.dart' as cust;
import '../owner/services/api_service.dart';
import '../owner/utils/onboarding.dart' as own;
import 'auth_gate.dart' show kActiveRoleKey;

/// Shown once, right after Google sign-in. The same Firebase idToken is sent
/// to whichever backend matches the chosen role.
class RoleSelectScreen extends StatefulWidget {
  final String idToken;
  final String? autoRole; // 'customer' | 'owner' | null (ask the user)
  const RoleSelectScreen(
      {super.key, required this.idToken, this.autoRole});
  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoRole == 'customer') {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _continueAsCustomer());
    } else if (widget.autoRole == 'owner') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _continueAsOwner());
    }
  }

  Future<void> _continueAsCustomer() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.googleSignIn(widget.idToken); // /customers/google
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kActiveRoleKey, 'customer');
      final me = await Api.getMe();
      if (!mounted) return;
      cust.routeAfterAuth(context, me['customer'] as Map<String, dynamic>?);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsOwner() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.googleAuth(widget.idToken); // /auth/google
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kActiveRoleKey, 'owner');
      final me = await ApiService.getMe();
      if (!mounted) return;
      own.routeAfterAuth(context, me['owner'] as Map<String, dynamic>?);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single-role users are auto-routed — show a loader, not the chooser.
    // If auto-routing fails, _error is set and the chooser appears as a
    // manual fallback.
    if (widget.autoRole != null && _error == null) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.primary)),
      );
    }
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Image.asset('assets/images/role_select.png',
                  height: 190, fit: BoxFit.contain),
              const SizedBox(height: 22),
              const Text('What are you looking for ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: C.textDark)),
              const SizedBox(height: 26),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.errorBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: C.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],
              _ChoiceCard(
                icon: Icons.search_rounded,
                title: "I'm Looking for Property",
                subtitle: 'Find PLOT',
                onTap: _busy ? null : _continueAsCustomer,
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                icon: Icons.add_rounded,
                title: 'I Want to Sell a Plot',
                subtitle: 'List your Plot',
                filled: true,
                onTap: _busy ? null : _continueAsOwner,
              ),
              if (_busy) ...[
                const SizedBox(height: 26),
                const Center(
                    child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: C.primary))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final bool comingSoon;
  final VoidCallback? onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.filled = false,
    this.comingSoon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? C.primary : C.card;
    final titleColor = filled ? Colors.white : C.textDark;
    final subColor = filled ? Colors.white70 : C.textMuted;
    final iconBoxBg =
        filled ? Colors.white.withValues(alpha: 0.20) : C.primaryLight;
    final iconColor = filled ? Colors.white : C.primary;

    return Opacity(
      opacity: comingSoon ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: filled ? C.primary : C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: titleColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(subtitle,
                              style:
                                  TextStyle(fontSize: 13, color: subColor)),
                        ),
                        if (comingSoon) ...[
                          const SizedBox(width: 6),
                          const Text('(Coming Soon)',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: C.primary,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
