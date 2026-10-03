import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'contact_us_screen.dart';
import 'info_pages.dart';
import '../../auth/role_switch.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.getMe();
      final c = res['customer'] as Map<String, dynamic>?;
      if (c != null) {
        if (mounted) setState(() => _user = c);
        return;
      }
    } catch (_) {}
    final u = await Api.getUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _edit() async {
    if (_user == null) return;
    final changed = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)));
    if (changed == true) _load();
  }

  Future<void> _openDetails() async {
    if (_user == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _PersonalDetailsScreen(user: _user!)));
    _load();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out?'),
        content:
            const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: C.error),
              child: const Text('Log Out')),
        ],
      ),
    );
    if (ok != true) return;
    await Api.logout();
    if (mounted)
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: _user == null
          ? null
          : AppBar(
              backgroundColor: C.bg,
              elevation: 0,
              centerTitle: true,
              title: const Text('Profile',
                  style: TextStyle(
                      color: C.textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: _user == null
              ? _GuestView()
              : Column(children: [
                  const SizedBox(height: 8),
                  _CustomerAvatar(user: _user!, onTap: _edit),
                  const SizedBox(height: 12),
                  Text(_user!['name'] ?? 'User',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: C.textDark)),
                  const SizedBox(height: 2),
                  Text(_user!['email'] ?? '',
                      style:
                          const TextStyle(fontSize: 13, color: C.textMuted)),
                  TextButton(
                    onPressed: _edit,
                    child: const Text('Edit',
                        style: TextStyle(
                            color: C.primary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  _ProfileMenu(
                    onPersonalDetails: _openDetails,
                    onRoleSwitch: () => switchToOwner(context),
                    onContact: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ContactUsScreen(user: _user))),
                  ),
                  const SizedBox(height: 18),
                  const _RateExperience(),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: C.error),
                      label: const Text('Log Out',
                          style: TextStyle(
                              color: C.error, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 40),
        Container(
          width: 90,
          height: 90,
          decoration:
              const BoxDecoration(color: C.primaryLight, shape: BoxShape.circle),
          child: Center(
              child: Image.asset('assets/images/logo_lexnland.png',
                  width: 46, height: 46)),
        ),
        const SizedBox(height: 20),
        const Text('You\'re browsing as a guest',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: C.textDark)),
        const SizedBox(height: 8),
        const Text('Sign in to save plots and chat with owners',
            style: TextStyle(color: C.textMuted)),
        const SizedBox(height: 28),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Sign In / Register'),
            )),
      ]);
}

// ── Circular avatar with camera badge ───────────────────────────
class _CustomerAvatar extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _CustomerAvatar({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] as String? ?? 'U');
    final initial = (name.isEmpty ? '?' : name[0]).toUpperCase();
    final photo = (user['profilePhoto'] ?? '').toString();
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
              color: C.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: C.primary, width: 2)),
          clipBehavior: Clip.antiAlias,
          child: photo.isNotEmpty
              ? Image.network(photo,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ini(initial))
              : _ini(initial),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: C.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 15),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _ini(String initial) => Center(
        child: Text(initial,
            style: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, color: C.primary)),
      );
}

// ── Profile menu ────────────────────────────────────────────────
class _ProfileMenu extends StatelessWidget {
  final VoidCallback onPersonalDetails;
  final VoidCallback onRoleSwitch;
  final VoidCallback onContact;
  const _ProfileMenu({
    required this.onPersonalDetails,
    required this.onRoleSwitch,
    required this.onContact,
  });

  Widget _tile(IconData icon, String title, VoidCallback onTap, bool divider) =>
      Column(children: [
        ListTile(
          leading: Icon(icon, color: C.primary, size: 21),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: C.textDark)),
          trailing:
              const Icon(Icons.chevron_right_rounded, color: C.textLight),
          onTap: onTap,
        ),
        if (divider) const Divider(height: 1, color: C.border),
      ]);

  @override
  Widget build(BuildContext context) {
    void go(Widget s) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => s));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Column(children: [
        _tile(Icons.person_outline_rounded, 'Personal Details',
            onPersonalDetails, true),
        _tile(Icons.sell_rounded, 'Switch to Selling (Owner)', onRoleSwitch,
            true),
        _tile(Icons.support_agent_rounded, 'Contact Us', onContact, true),
        _tile(Icons.info_outline_rounded, 'About Us',
            () => go(const AboutUsScreen()), true),
        _tile(Icons.description_outlined, 'Terms & Conditions',
            () => go(const TermsScreen()), true),
        _tile(Icons.privacy_tip_outlined, 'Privacy Policy',
            () => go(const PrivacyScreen()), false),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Personal Details (customer)
// ════════════════════════════════════════════════════════════════
class _PersonalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const _PersonalDetailsScreen({required this.user});
  @override
  State<_PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<_PersonalDetailsScreen> {
  late Map<String, dynamic> _user = widget.user;

  Future<void> _reload() async {
    try {
      final res = await Api.getMe();
      final c = res['customer'] as Map<String, dynamic>?;
      if (c != null && mounted) setState(() => _user = c);
    } catch (_) {}
  }

  Future<void> _edit() async {
    final changed = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)));
    if (changed == true) _reload();
  }

  String _cap(String s) =>
      s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
  String _val(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: C.textDark),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Personal Details',
            style: TextStyle(
                color: C.textDark, fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _edit,
            child: const Text('Edit',
                style:
                    TextStyle(color: C.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _SectionLabel('Contact'),
            _InfoCard(items: [
              _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _val(_user['email'])),
              _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: _val(_user['phone'])),
            ]),
            const SizedBox(height: 16),
            _SectionLabel('Location'),
            _InfoCard(items: [
              _InfoRow(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: _cap((_user['city'] ?? '') as String)),
              _InfoRow(
                  icon: Icons.map_outlined,
                  label: 'State',
                  value: _cap((_user['state'] ?? '') as String)),
            ]),
            const SizedBox(height: 16),
            _SectionLabel('Personal'),
            _InfoCard(items: [
              _InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: _user['age'] == null ? '—' : '${_user['age']}'),
              _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Gender',
                  value: _cap((_user['gender'] ?? '') as String)),
              _InfoRow(
                  icon: Icons.work_outline,
                  label: 'Occupation',
                  value: _cap((_user['occupation'] ?? '') as String)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: C.textMuted)),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> items;
  const _InfoCard({required this.items});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: Column(
            children: List.generate(
                items.length,
                (i) => Column(children: [
                      items[i],
                      if (i < items.length - 1)
                        const Divider(height: 1, color: C.border),
                    ]))),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: C.primary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: C.textMuted)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: C.textDark)),
        ]),
      );
}

// ── Rate your experience ────────────────────────────────────────
class _RateExperience extends StatefulWidget {
  const _RateExperience();
  @override
  State<_RateExperience> createState() => _RateExperienceState();
}

class _RateExperienceState extends State<_RateExperience> {
  int _rating = 0;
  bool _sending = false;
  bool _done = false;

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _sending = true);
    try {
      await Api.submitProblem(
          'App rating: $_rating/5 stars (Rate your experience)');
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: C.error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Text('Rate Your experience',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: C.textDark)),
      const SizedBox(height: 10),
      if (_done)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.check_circle_rounded, color: C.success, size: 20),
          SizedBox(width: 8),
          Text('Thanks for your feedback!',
              style:
                  TextStyle(color: C.success, fontWeight: FontWeight.w700)),
        ])
      else ...[
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: _sending ? null : () => setState(() => _rating = i + 1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: C.primary,
                      size: 34),
                ),
              );
            })),
        if (_rating > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_sending ? 'Sending…' : 'Send feedback'),
            ),
          ),
        ],
      ],
    ]);
  }
}
