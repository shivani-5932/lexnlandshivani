import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _all      = [];
  List<dynamic> _filtered = [];
  bool          _loading  = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilter);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getNotifications();
      final raw = res['notifications'] as List? ?? [];
      // Filter: skip chat/message notifications (owner sees those in chat tab)
      // Keep: listing, visit, system, admin_review
      final list = raw.where((n) {
        final t = (n as Map)['type'] as String? ?? '';
        final title = ((n)['title'] as String? ?? '').toLowerCase();
        return t != 'message' && !title.contains('new message');
      }).toList();
      if (mounted) {
        setState(() {
          _all     = list;
          _loading = false;
        });
        _applyFilter();
      }
      // Opening the bell counts as reading them — clear the unread badge on
      // the server so the home bell stops showing a count.
      ApiService.markAllRead().catchError((_) {});
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((n) {
              final title   = (n['title']   as String? ?? '').toLowerCase();
              final message = (n['message'] as String? ?? '').toLowerCase();
              return title.contains(q) || message.contains(q);
            }).toList();
    });
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllRead();
    setState(() {
      for (final n in _all) { (n as Map<String, dynamic>)['isRead'] = true; }
      _applyFilter();
    });
  }

  Future<void> _markOneRead(int index, String? id) async {
    if (id == null) return;
    setState(() {
      (_filtered[index] as Map<String, dynamic>)['isRead'] = true;
      for (final n in _all) {
        if ((n as Map<String, dynamic>)['_id'] == id) n['isRead'] = true;
      }
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('This will delete all notifications permanently.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear All',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.clearNotifications();
      setState(() { _all = []; _filtered = []; });
    }
  }

  // ── icon + colour by notification type ──────────────────────
  _NotifStyle _style(Map<String, dynamic> n) {
    final type  = n['type']  as String? ?? 'system';
    final title = (n['title'] as String? ?? '').toLowerCase();

    if (title.contains('verified'))    return _NotifStyle(Icons.verified_rounded,           const Color(0xFF2E7D32), const Color(0xFFE8F5E9));
    if (title.contains('suspended'))   return _NotifStyle(Icons.warning_amber_rounded,       const Color(0xFFE65100), const Color(0xFFFFF3E0));
    if (title.contains('rejected'))    return _NotifStyle(Icons.cancel_outlined,             const Color(0xFFC62828), const Color(0xFFFFEBEE));
    if (title.contains('reinstated'))  return _NotifStyle(Icons.refresh_rounded,             const Color(0xFF1565C0), const Color(0xFFE3F2FD));
    if (title.contains('re-review'))   return _NotifStyle(Icons.admin_panel_settings_rounded,const Color(0xFF6A1B9A), const Color(0xFFF3E5F5));
    if (title.contains('visit'))       return _NotifStyle(Icons.calendar_today_rounded,      AppColors.primary,       AppColors.primaryLight);
    if (title.contains('submitted'))   return _NotifStyle(Icons.upload_rounded,              AppColors.primary,       AppColors.primaryLight);
    if (title.contains('removed'))     return _NotifStyle(Icons.delete_outline_rounded,      const Color(0xFFC62828), const Color(0xFFFFEBEE));

    switch (type) {
      case 'listing': return _NotifStyle(Icons.home_rounded,               AppColors.primary,       AppColors.primaryLight);
      case 'visit':   return _NotifStyle(Icons.calendar_month_rounded,     AppColors.primary,       AppColors.primaryLight);
      default:        return _NotifStyle(Icons.notifications_outlined,     AppColors.textMuted,     AppColors.background);
    }
  }

  String _timeAgo(String? raw) {
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60)  return 'Just now';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24)  return '${diff.inHours}h ago';
      if (diff.inDays    < 7)   return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _all.where((n) => !(n['isRead'] as bool? ?? false)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          if (unread > 0)
            Text('$unread unread',
                style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          if (_all.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) { if (v == 'read') _markAllRead(); else if (v == 'clear') _clearAll(); },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'read',  child: Row(children: [
                  Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 10), Text('Mark all as read'),
                ])),
                const PopupMenuItem(value: 'clear', child: Row(children: [
                  Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 10), Text('Clear all', style: TextStyle(color: AppColors.error)),
                ])),
              ],
            ),
        ],
      ),
      body: Column(children: [
        // ── Search bar ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search notifications…',
              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textLight),
                      onPressed: () { _search.clear(); _applyFilter(); },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),

        // ── Body ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _all.isEmpty
                  ? _EmptyState()
                  : _filtered.isEmpty
                      ? _NoResults(onClear: () { _search.clear(); })
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final n      = _filtered[i] as Map<String, dynamic>;
                              final isRead = n['isRead'] as bool? ?? false;
                              final style  = _style(n);
                              final time   = _timeAgo(n['createdAt'] as String?);

                              return GestureDetector(
                                onTap: () => _markOneRead(i, n['_id'] as String?),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.white : style.bg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isRead ? AppColors.border : style.color.withValues(alpha: 0.3),
                                      width: isRead ? 1 : 1.5,
                                    ),
                                    boxShadow: isRead ? [] : [
                                      BoxShadow(
                                        color: style.color.withValues(alpha: 0.08),
                                        blurRadius: 8, offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    // Icon bubble
                                    Container(
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? AppColors.background
                                            : style.color.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(style.icon,
                                          size: 20,
                                          color: isRead ? AppColors.textLight : style.color),
                                    ),
                                    const SizedBox(width: 12),

                                    // Content
                                    Expanded(child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(child: Text(
                                            n['title'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                              color: isRead ? AppColors.textMuted : AppColors.textDark,
                                            ),
                                          )),
                                          if (!isRead)
                                            Container(
                                              width: 8, height: 8,
                                              decoration: BoxDecoration(
                                                color: style.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(
                                          n['message'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isRead ? AppColors.textLight : AppColors.textMuted,
                                            height: 1.4,
                                          ),
                                        ),
                                        if (time.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(time,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textLight,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      ],
                                    )),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color, bg;
  const _NotifStyle(this.icon, this.color, this.bg);
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Image.asset('assets/images/empty_notifications.png',
          width: 200, fit: BoxFit.contain),
      const SizedBox(height: 8),
      const Text('No notification yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 44),
        child: Text(
            'All notifications we send will appear here, so you can view them easily anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.45)),
      ),
    ]),
  );
}

class _NoResults extends StatelessWidget {
  final VoidCallback onClear;
  const _NoResults({required this.onClear});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off_rounded, size: 52, color: AppColors.textLight),
      const SizedBox(height: 14),
      const Text('No results found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      const SizedBox(height: 6),
      const Text('Try a different search term',
          style: TextStyle(color: AppColors.textMuted)),
      const SizedBox(height: 16),
      TextButton(
        onPressed: onClear,
        child: const Text('Clear Search', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}
