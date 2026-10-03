import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/property_thumb.dart';
import '../widgets/delete_confirm_sheet.dart';
import 'notification_screen.dart';
// import 'scheduled_visit_screen.dart'; // scheduled-visit feature disabled
import 'message_screen.dart';
import 'edit_property_screen.dart';

class DashboardTab extends StatefulWidget {
  final void Function(int) onSwitchTab;
  const DashboardTab({super.key, required this.onSwitchTab});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _properties = [];
  int _unreadMessages = 0;
  int _unreadNotifs = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getDashboardStats(),
        ApiService.getMyProperties(),
        ApiService.getNotifications(),
        ApiService.getChats(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0]['stats'] as Map<String, dynamic>? ?? {};
          _properties = results[1]['properties'] as List? ?? [];
          _unreadNotifs = results[2]['unreadCount'] as int? ?? 0;
          final chats = results[3]['chats'] as List? ?? [];
          _unreadMessages =
              chats.fold(0, (s, c) => s + (c['unreadCount'] as int? ?? 0));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProperty(Map<String, dynamic> prop) async {
    final id = prop['_id']?.toString();
    if (id == null) return;
    final name = (prop['propertyName'] ?? 'this property').toString();

    final confirm = await showDeleteListingSheet(context, name: name);
    if (!confirm || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    try {
      await ApiService.deleteProperty(id);
      if (!mounted) return;
      Navigator.pop(context); // remove spinner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property deleted')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // remove spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dashboard',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark)),
                            Text('Overview & manage your listings',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else ...[
                // ── Stats ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _StatCard(
                                label: 'Total',
                                value: '${_stats['total'] ?? 0}',
                                color: AppColors.primary,
                                bg: AppColors.primaryLight),
                            const SizedBox(width: 10),
                            _StatCard(
                                label: 'Active',
                                value: '${_stats['active'] ?? 0}',
                                color: AppColors.success,
                                bg: AppColors.successBg),
                            const SizedBox(width: 10),
                            _StatCard(
                                label: 'Review',
                                value: '${_stats['underReview'] ?? 0}',
                                color: const Color(0xFFE65100),
                                bg: const Color(0xFFFFF3E0)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Quick Actions ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick Actions',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Visits action tile removed — scheduled-visit feature disabled
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Messages',
                                badge: _unreadMessages > 0
                                    ? '$_unreadMessages'
                                    : null,
                                color: const Color(0xFF1565C0),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const MessageScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.notifications_outlined,
                                label: 'Alerts',
                                badge:
                                    _unreadNotifs > 0 ? '$_unreadNotifs' : null,
                                color: const Color(0xFFE65100),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: Icons.add_home_rounded,
                                label: 'Upload',
                                badge: null,
                                color: const Color(0xFF00695C),
                                onTap: () => widget.onSwitchTab(1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── My Properties header ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('My Properties',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark)),
                        TextButton(
                          onPressed: () => widget.onSwitchTab(1),
                          child: const Text('View all',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Properties list ─────────────────────────────
                if (_properties.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'No properties yet. Upload one from the Listing tab.',
                            style: TextStyle(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final prop = _properties[i] as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _DashboardPropertyCard(
                            property: prop,
                            onEdit: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditPropertyScreen(property: prop),
                                ),
                              );
                              _load();
                            },
                            onDelete: () => _deleteProperty(prop),
                          ),
                        );
                      },
                      childCount: _properties.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard property card ────────────────────────────────────
class _DashboardPropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DashboardPropertyCard(
      {required this.property, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = property['status'] as String? ?? 'under_review';
    final isVerified = property['isVerified'] as bool? ?? false;
    final type = property['propertyType'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        statusLabel = 'Active';
        break;
      case 'sold':
        statusColor = AppColors.success;
        statusLabel = '✓ Booked / Sold';
        break;
      case 'archived':
        statusColor = AppColors.textLight;
        statusLabel = 'Archived';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusLabel = 'Rejected';
        break;
      case 'inactive':
        statusColor = AppColors.textLight;
        statusLabel = 'Inactive';
        break;
      case 'suspended':
        statusColor = AppColors.error;
        statusLabel = 'Suspended';
        break;
      default:
        statusColor = const Color(0xFFE65100);
        statusLabel = 'Under Review';
    }

    // Price info
    String priceInfo = '';
    if (type == 'plot') {
      final d = property['plotDetails'] as Map<String, dynamic>?;
      final price = d?['totalPrice'];
      if (price != null && (price as num) > 0) {
        priceInfo = '₹${price.toStringAsFixed(0)}';
      }
    } else if (type == 'pg') {
      final d = property['pgDetails'] as Map<String, dynamic>?;
      final sp = d?['sharingPricing']?['singleRoom']?['price'];
      if (sp != null && (sp as num) > 0) {
        priceInfo = '₹$sp/mo';
      }
    } else if (type == 'guest') {
      final d = property['guestRoomDetails'] as Map<String, dynamic>?;
      final sp = d?['pricing']?['singleRoom']?['price'];
      if (sp != null && (sp as num) > 0) {
        priceInfo = '₹$sp/night';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Type / photo thumbnail
              PropertyThumb(property: property, size: 48, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['propertyName'] ?? 'Unnamed',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            property['location'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (priceInfo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        priceInfo,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ),
              // Edit button
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),
              // Delete button
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete property',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusBadge(label: statusLabel, color: statusColor),
              if (isVerified)
                _StatusBadge(
                    label: '✓ Legally Verified', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          _PropertyAnalytics(property: property),
        ],
      ),
    );
  }
}

// ── Per-property analytics: rating · views · likes ──────────────
class _PropertyAnalytics extends StatelessWidget {
  final Map<String, dynamic> property;
  const _PropertyAnalytics({required this.property});

  @override
  Widget build(BuildContext context) {
    final avg = (property['ratingAverage'] as num?)?.toDouble() ?? 0;
    final ratingCount = property['ratingCount'] as int? ?? 0;
    final views = property['views'] as int? ?? 0;
    final likes = property['favouritesCount'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _metric(
                Icons.star_rounded,
                const Color(0xFFF5A623),
                avg > 0 ? avg.toStringAsFixed(1) : '—',
                ratingCount > 0 ? '$ratingCount ratings' : 'No ratings'),
            _divider(),
            _metric(Icons.visibility_outlined, AppColors.primary, '$views',
                views == 1 ? 'view' : 'views'),
            _divider(),
            _metric(Icons.favorite_rounded, AppColors.error, '$likes',
                likes == 1 ? 'like' : 'likes'),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, color: AppColors.border);

  Widget _metric(IconData icon, Color color, String value, String label) =>
      Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ],
        ),
      );
}

// ── Status badge ───────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

// ── Stat card ──────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color, bg;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 0.8))),
            ],
          ),
        ),
      );
}

// ── Action tile ────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.badge,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppColors.error, shape: BoxShape.circle),
                        child: Text(badge!,
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      );
}
