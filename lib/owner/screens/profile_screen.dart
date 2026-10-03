import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'payment_screen.dart';
import 'edit_profile_screen.dart';
import 'contact_us_screen.dart';
import 'info_pages.dart';
import '../../auth/role_switch.dart';

class ProfileTab extends StatefulWidget {
  final void Function(int) onSwitchTab;
  const ProfileTab({super.key, required this.onSwitchTab});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _owner;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMe();
      if (mounted)
        setState(() {
          _owner = res['owner'] as Map<String, dynamic>?;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Log Out')),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.logout();
    if (mounted)
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _openPayment() async {
    final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => const PaymentScreen(fromProfile: true)));
    if (paid == true) _load();
  }

  Future<void> _openEdit() async {
    if (_owner == null) return;
    final changed = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EditProfileScreen(owner: _owner!)));
    if (changed == true) _load();
  }

  Future<void> _openDetails() async {
    if (_owner == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _PersonalDetailsScreen(owner: _owner!)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = (_owner?['name'] ?? 'Owner').toString();
    final email = (_owner?['email'] ?? '').toString();
    final photo = (_owner?['profilePhoto'] ?? '').toString();
    // PAYMENT DISABLED — registration is free, so never show the unpaid banner.
    const bool unpaid = false;
    // final unpaid = !(_owner?['isPaid'] as bool? ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text('Profile',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(children: [
                  const SizedBox(height: 8),
                  ProfileAvatar(name: name, photo: photo, onTap: _openEdit),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  TextButton(
                    onPressed: _openEdit,
                    child: const Text('Edit',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),

                  // Registration-payment reminder (unpaid owners)
                  if (unpaid) ...[
                    GestureDetector(
                      onTap: _openPayment,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFB74D)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFE65100), size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                                'Pay the ₹100 registration fee to activate your account.',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFE65100),
                                    fontWeight: FontWeight.w600,
                                    height: 1.4)),
                          ),
                          const Text('Pay Now',
                              style: TextStyle(
                                  color: Color(0xFFE65100),
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _ProfileMenu(
                    onPersonalDetails: _openDetails,
                    roleSwitchLabel: 'Switch to Buying (Customer)',
                    roleSwitchIcon: Icons.shopping_bag_rounded,
                    onRoleSwitch: () => switchToCustomer(context),
                    onContact: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ContactUsScreen(owner: _owner ?? const {}))),
                  ),
                  const SizedBox(height: 18),
                  const _RateExperience(),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.error),
                      label: const Text('Log Out',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
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

// ── Circular avatar with a camera badge ─────────────────────────
class ProfileAvatar extends StatelessWidget {
  final String name;
  final String photo;
  final VoidCallback onTap;
  const ProfileAvatar(
      {super.key, required this.name, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = (name.isEmpty ? '?' : name[0]).toUpperCase();
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2)),
            clipBehavior: Clip.antiAlias,
            child: photo.isNotEmpty
                ? Image.network(photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initial(initial))
                : _initial(initial),
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
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(String initial) => Center(
        child: Text(initial,
            style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
      );
}

// ── Profile menu (Personal Details + role switch + info pages) ──
class _ProfileMenu extends StatelessWidget {
  final VoidCallback onPersonalDetails;
  final String roleSwitchLabel;
  final IconData roleSwitchIcon;
  final VoidCallback onRoleSwitch;
  final VoidCallback onContact;
  const _ProfileMenu({
    required this.onPersonalDetails,
    required this.roleSwitchLabel,
    required this.roleSwitchIcon,
    required this.onRoleSwitch,
    required this.onContact,
  });

  Widget _tile(IconData icon, String title, VoidCallback onTap, bool divider) =>
      Column(children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary, size: 21),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight),
          onTap: onTap,
        ),
        if (divider) const Divider(height: 1, color: AppColors.border),
      ]);

  @override
  Widget build(BuildContext context) {
    void go(Widget s) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => s));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        _tile(Icons.person_outline_rounded, 'Personal Details',
            onPersonalDetails, true),
        _tile(roleSwitchIcon, roleSwitchLabel, onRoleSwitch, true),
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
//  Personal Details — the full field list (moved off the main page)
// ════════════════════════════════════════════════════════════════
class _PersonalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> owner;
  const _PersonalDetailsScreen({required this.owner});
  @override
  State<_PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<_PersonalDetailsScreen> {
  late Map<String, dynamic> _owner = widget.owner;

  Future<void> _reload() async {
    try {
      final res = await ApiService.getMe();
      final o = res['owner'] as Map<String, dynamic>?;
      if (o != null && mounted) setState(() => _owner = o);
    } catch (_) {}
  }

  Future<void> _edit() async {
    final changed = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EditProfileScreen(owner: _owner)));
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Personal Details',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _edit,
            child: const Text('Edit',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
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
                  value: _val(_owner['email'])),
              _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: _val(_owner['phone'])),
              _InfoRow(
                  icon: Icons.chat_outlined,
                  label: 'Alt / WhatsApp',
                  value: _val(_owner['altPhone'])),
            ]),
            const SizedBox(height: 16),
            _SectionLabel('Business'),
            _InfoCard(items: [
              _InfoRow(
                  icon: Icons.store_outlined,
                  label: 'Business Name',
                  value: _val(_owner['businessName'])),
              _InfoRow(
                  icon: Icons.work_outline,
                  label: 'Occupation',
                  value: _cap((_owner['occupation'] ?? '') as String)),
              _InfoRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'GST Number',
                  value: _val(_owner['gstNumber'])),
            ]),
            const SizedBox(height: 16),
            _SectionLabel('Address'),
            _InfoCard(items: [
              _InfoRow(
                  icon: Icons.home_outlined,
                  label: 'Address',
                  value: _val(_owner['address'])),
              _InfoRow(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: _cap((_owner['city'] ?? '') as String)),
              _InfoRow(
                  icon: Icons.map_outlined,
                  label: 'State',
                  value: _cap((_owner['state'] ?? '') as String)),
              _InfoRow(
                  icon: Icons.markunread_mailbox_outlined,
                  label: 'Pincode',
                  value: _val(_owner['pincode'])),
            ]),
            const SizedBox(height: 16),
            _SectionLabel('Personal'),
            _InfoCard(items: [
              _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Gender',
                  value: _cap((_owner['gender'] ?? '') as String)),
              _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'ID Number',
                  value: _val(_owner['idNumber'])),
            ]),
            const SizedBox(height: 16),
            _SectionLabel('Account'),
            _InfoCard(items: [
              _InfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Account',
                  value: _cap((_owner['accountStatus'] ?? '') as String)),
              _InfoRow(
                  icon: Icons.event_outlined,
                  label: 'Member Since',
                  value: _memberSince(_owner['createdAt'])),
              _InfoRow(
                icon: Icons.mark_email_read_outlined,
                label: 'Email Verified',
                value: (_owner['isEmailVerified'] as bool? ?? false)
                    ? '✅ Verified'
                    : '❌ Not Verified',
              ),
              _InfoRow(
                icon: Icons.fingerprint_rounded,
                label: 'Aadhaar Verified',
                value: (_owner['isAadhaarVerified'] as bool? ?? false)
                    ? '✅ Verified'
                    : '❌ Not Verified',
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── shared field helpers ────────────────────────────────────────
String _cap(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);

String _val(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? '—' : s;
}

String _memberSince(dynamic createdAt) {
  if (createdAt == null) return '—';
  final d = DateTime.tryParse(createdAt.toString());
  if (d == null) return '—';
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${m[d.month - 1]} ${d.year}';
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
                  color: AppColors.textMuted)),
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
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
            children: List.generate(
                items.length,
                (i) => Column(children: [
                      items[i],
                      if (i < items.length - 1)
                        const Divider(height: 1, color: AppColors.border),
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
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
        ]),
      );
}

// ── Rate your experience (app feedback -> support inbox) ─────
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
      await ApiService.submitProblem(
          'App rating: $_rating/5 stars (Rate your experience)');
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error));
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark)),
      const SizedBox(height: 10),
      if (_done)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          SizedBox(width: 8),
          Text('Thanks for your feedback!',
              style: TextStyle(
                  color: AppColors.success, fontWeight: FontWeight.w700)),
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
                      color: AppColors.primary,
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
