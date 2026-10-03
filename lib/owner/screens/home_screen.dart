import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/property_thumb.dart';
import 'notification_screen.dart';
import 'message_screen.dart';

class HomeTab extends StatefulWidget {
  final void Function(int) onSwitchTab;
  const HomeTab({super.key, required this.onSwitchTab});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _owner;
  List<dynamic> _properties = [];
  int _unreadNotifs = 0;
  int _unreadMessages = 0;
  bool _loading = true;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _unreadTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _refreshUnread());
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    final n = await ApiService.getUnreadChatCount();
    if (mounted) setState(() => _unreadMessages = n);
  }

  int get _activeCount => _properties
      .where((p) => (p as Map)['status'] == 'active')
      .length;
  int get _totalViews => _properties.fold(
      0, (s, p) => s + ((p as Map)['views'] as int? ?? 0));
  double get _avgRating {
    final rated = _properties
        .where((p) => ((p as Map)['ratingCount'] as int? ?? 0) > 0)
        .toList();
    if (rated.isEmpty) return 0;
    final sum = rated.fold<double>(
        0, (s, p) => s + (((p as Map)['ratingAverage'] as num?)?.toDouble() ?? 0));
    return sum / rated.length;
  }

  Widget _ovStat(String value, String label) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 10,
                    height: 1.15,
                    color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      );

  Widget _ovDivider() => Container(
        width: 1,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.white.withValues(alpha: 0.25),
      );

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getMyProperties(),
        ApiService.getNotifications(),
        ApiService.getOwnerChats(),
      ]);
      if (mounted)
        setState(() {
          _owner = results[0]['owner'] as Map<String, dynamic>?;
          _properties = results[1]['properties'] as List? ?? [];
          _unreadNotifs = results[2]['unreadCount'] as int? ?? 0;
          final chats = results[3]['chats'] as List? ?? [];
          // Count people (conversations) with unseen messages, not total msgs.
          _unreadMessages = chats
              .where((c) => (c['unreadByOwner'] as int? ?? 0) > 0)
              .length;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Hi, ${_owner?['name'] ?? 'Owner'} 👋',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark)),
                                const Text('Manage your properties efficiently',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted)),
                              ])),
                          _HeaderIcon(
                            icon: Icons.chat_bubble_outline_rounded,
                            badge: _unreadMessages > 0
                                ? (_unreadMessages > 9
                                    ? '9+'
                                    : '$_unreadMessages')
                                : null,
                            onTap: () {
                              setState(() => _unreadMessages = 0);
                              Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const MessageScreen()))
                                  .then((_) => _load());
                            },
                          ),
                          const SizedBox(width: 10),
                          _HeaderIcon(
                            icon: Icons.notifications_none_rounded,
                            badge: _unreadNotifs > 0
                                ? (_unreadNotifs > 9 ? '9+' : '$_unreadNotifs')
                                : null,
                            onTap: () {
                              setState(() => _unreadNotifs = 0);
                              Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationScreen()))
                                  .then((_) => _load());
                            },
                          ),
                        ]),
                        const SizedBox(height: 14),
                        // Upload button → switches to Listing tab
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => widget.onSwitchTab(1),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Upload New Property',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)))
              else if (_properties.isEmpty) ...[
                // ── Empty state: no properties uploaded yet ──
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                    child: Center(
                      child: Image.asset(
                        'assets/images/no_property.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // ── Overview card ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF8E2F52)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Expanded(
                              child: Text('Overview',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                            GestureDetector(
                              onTap: () => widget.onSwitchTab(2),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('View Analysis',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text('Track your property performance',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.8))),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _ovStat('${_properties.length}',
                                  'Total\nListings'),
                              _ovDivider(),
                              _ovStat('$_activeCount', 'Active\nListings'),
                              _ovDivider(),
                              _ovStat('$_totalViews', 'Total\nViews'),
                              _ovDivider(),
                              _ovStat(
                                  _avgRating > 0
                                      ? '★ ${_avgRating.toStringAsFixed(1)}'
                                      : '★ —',
                                  'Avg.\nRating'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Recent Properties ──
                if (_properties.isNotEmpty) ...[
                  SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Properties',
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
                  )),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: _PropertyCard(
                            property: _properties[i] as Map<String, dynamic>),
                      ),
                      childCount:
                          _properties.length > 4 ? 4 : _properties.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, this.badge, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 21, color: AppColors.textDark),
          ),
        ),
      ),
      if (badge != null)
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(badge!,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ),
    ]);
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  const _PropertyCard({required this.property});
  @override
  Widget build(BuildContext context) {
    final status = property['status'] as String? ?? 'under_review';
    final isVerified = property['isVerified'] as bool? ?? false;

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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        PropertyThumb(property: property, size: 44, radius: 10),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(property['propertyName'] ?? 'Unnamed',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(property['location'] ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _SmallBadge(label: statusLabel, color: statusColor),
            if (isVerified)
              _SmallBadge(
                  label: '✓ Legally Verified', color: AppColors.success),
          ]),
        ])),
      ]),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
