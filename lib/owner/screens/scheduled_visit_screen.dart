import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

// ══════════════════════════════════════════════════════════════
//  Owner — Scheduled Visits (matches Figma mockup)
// ══════════════════════════════════════════════════════════════
class ScheduledVisitScreen extends StatefulWidget {
  const ScheduledVisitScreen({super.key});
  @override
  State<ScheduledVisitScreen> createState() => _ScheduledVisitScreenState();
}

class _ScheduledVisitScreenState extends State<ScheduledVisitScreen> {
  List<dynamic> _visits = [];
  bool _loading = true;
  String _timePeriod = 'Today'; // Today / Upcoming / Past
  String _status = 'All'; // All / Pending / Confirmed / Rescheduled / Cancelled

  final _timePeriods = ['Today', 'Upcoming', 'Past'];
  final _statuses = ['All', 'Pending', 'Confirmed', 'Rescheduled', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getVisits();
      if (mounted)
        setState(() {
          _visits = res['visits'] as List? ?? [];
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    final now = DateTime.now();
    return _visits.where((v) {
      final vMap = v as Map<String, dynamic>;
      final status = (vMap['status'] as String? ?? '').toLowerCase();
      // Time period filter
      DateTime? vDate;
      try {
        vDate = DateTime.parse(vMap['visitDate'] as String? ?? '').toLocal();
      } catch (_) {}
      if (vDate != null) {
        final isToday = vDate.year == now.year &&
            vDate.month == now.month &&
            vDate.day == now.day;
        final isUpcoming = vDate.isAfter(now) && !isToday;
        final isPast = vDate.isBefore(now) && !isToday;
        if (_timePeriod == 'Today' && !isToday) return false;
        if (_timePeriod == 'Upcoming' && !isUpcoming) return false;
        if (_timePeriod == 'Past' && !isPast) return false;
      }
      // Status filter
      if (_status != 'All' && status != _status.toLowerCase()) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        title: const Text('Scheduled Visits',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textDark)),
        actions: [
          IconButton(
              onPressed: _load,
              icon:
                  const Icon(Icons.refresh_rounded, color: AppColors.primary)),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(children: [
            // Time period tabs
            Row(
                children: _timePeriods.map((p) {
              final active = _timePeriod == p;
              return GestureDetector(
                onTap: () => setState(() => _timePeriod = p),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(p,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textMuted,
                      )),
                ),
              );
            }).toList()),
            const SizedBox(height: 10),
            // Status chips
            SizedBox(
              height: 36,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _statuses.map((s) {
                    final active = _status == s;
                    return GestureDetector(
                      onTap: () => setState(() => _status = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: Text(s,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : AppColors.textDark,
                            )),
                      ),
                    );
                  }).toList()),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty
                  ? const _EmptyVisits()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _VisitCard(
                          visit: _filtered[i] as Map<String, dynamic>,
                          onRefresh: _load,
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ── Visit card ─────────────────────────────────────────────────
class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final VoidCallback onRefresh;
  const _VisitCard({required this.visit, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final v = visit;
    final status = v['status'] as String? ?? 'pending';
    final awaiting = (v['awaitingFrom'] as String?) ??
        (status == 'pending'
            ? 'owner'
            : status == 'rescheduled'
                ? 'customer'
                : null);
    final prop = v['property'] as Map<String, dynamic>? ?? {};
    final customer = v['customer'] as Map<String, dynamic>? ?? {};
    final name =
        v['visitorName'] as String? ?? customer['name'] as String? ?? '—';
    final phone =
        v['visitorPhone'] as String? ?? customer['phone'] as String? ?? '—';
    final req = v['requirement'] as String? ?? '';
    final dateStr = _fmtDate(v['visitDate'] as String?);
    final time = v['visitTime'] as String? ?? '';

    Color sc;
    String sl;
    switch (status) {
      case 'confirmed':
        sc = const Color(0xFF2E7D32);
        sl = 'Confirmed';
        break;
      case 'rescheduled':
        if (awaiting == 'owner') {
          sc = const Color(0xFFE65100);
          sl = 'Action needed';
        } else {
          sc = const Color(0xFF1565C0);
          sl = 'Awaiting customer';
        }
        break;
      case 'cancelled':
        sc = const Color(0xFFC62828);
        sl = 'Cancelled';
        break;
      case 'completed':
        sc = AppColors.textLight;
        sl = 'Completed';
        break;
      default:
        sc = const Color(0xFFE65100);
        sl = 'Action needed';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark))),
            Text(sl,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: sc)),
          ]),
          const SizedBox(height: 3),
          Text('$dateStr, $time',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(prop['propertyName'] ?? '—',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          if (req.isNotEmpty)
            Text(req,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          Row(children: [
            // View Details button
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _VisitDetailScreen(
                          visitId: v['_id'] as String, onRefresh: onRefresh))),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('View Details',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const Spacer(),
            // Phone icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_outlined,
                  size: 16, color: AppColors.primary),
            ),
          ]),
        ]),
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      const mo = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${mo[d.month - 1]}, ${d.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Visit detail screen ────────────────────────────────────────
class _VisitDetailScreen extends StatefulWidget {
  final String visitId;
  final VoidCallback onRefresh;
  const _VisitDetailScreen({required this.visitId, required this.onRefresh});
  @override
  State<_VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<_VisitDetailScreen> {
  Map<String, dynamic>? _visit;
  bool _loading = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getVisitById(widget.visitId);
      if (mounted)
        setState(() {
          _visit = res['visit'] as Map<String, dynamic>?;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _acting = true);
    try {
      await ApiService.confirmVisitOwner(widget.visitId);
      widget.onRefresh();
      if (mounted) {
        _showConfirmDialog();
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel() async {
    final reason = await _reasonDialog(
        'Reason for Cancelling', 'Eg Already Booked / Sold');
    if (reason == null || !mounted) return;
    setState(() => _acting = true);
    try {
      await ApiService.cancelVisitOwner(widget.visitId, reason);
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reschedule() async {
    final v = _visit;
    if (v == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _RescheduleScreen(
                visit: v,
                onDone: () {
                  widget.onRefresh();
                  Navigator.pop(context);
                })));
  }

  void _showConfirmDialog() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32), size: 54),
                SizedBox(height: 14),
                Text('Visit Confirmed!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('Once Confirmed, visitor will be notified automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ]),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    _load();
                  },
                  child: const Text('Done',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ));
  }

  Future<String?> _reasonDialog(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textLight),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg.replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppColors.primary)));
    final v = _visit!;
    final status = v['status'] as String? ?? 'pending';
    final awaiting = (v['awaitingFrom'] as String?) ??
        (status == 'pending'
            ? 'owner'
            : status == 'rescheduled'
                ? 'customer'
                : null);
    final proposals = (v['proposals'] as List?) ?? [];
    final ownerTurn =
        awaiting == 'owner' && (status == 'pending' || status == 'rescheduled');
    final customerTurn = awaiting == 'customer' && status == 'rescheduled';
    final prop = v['property'] as Map<String, dynamic>? ?? {};
    final name = v['visitorName'] as String? ?? '—';
    final phone = v['visitorPhone'] as String? ?? '—';
    final req = v['requirement'] as String? ?? '';
    final date = _fmtDate(v['visitDate'] as String?);
    final time = v['visitTime'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        title: const Text('View Details',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textDark)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Visitor info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(prop['propertyName'] ?? '—',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
              if (req.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(req,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
              const SizedBox(height: 8),
              Text('mobile no: $phone',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
            ]),
          ),
          const SizedBox(height: 12),
          // Visit date card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Visit info',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Text('$date, $time',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Proposal history thread ──
          if (proposals.length > 1) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('History',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    ...proposals.map((p) {
                      final m = p as Map<String, dynamic>;
                      final by = (m['by'] as String? ?? '') == 'owner'
                          ? 'You'
                          : 'Customer';
                      final d = _fmtDate(m['date'] as String?);
                      final t = m['time'] as String? ?? '';
                      final note = m['note'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                            '$by proposed $d at $t${note.isNotEmpty ? ' — $note' : ''}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textDark)),
                      );
                    }),
                  ]),
            ),
          ],

          // ── Owner's turn: confirm the current slot / propose another / cancel ──
          if (ownerTurn) ...[
            if (status == 'rescheduled')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFE65100).withValues(alpha: 0.3)),
                ),
                child: const Text(
                    'The customer proposed this time. Confirm to accept it, or propose another.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.w600)),
              ),
            Row(children: [
              Expanded(
                  child: ElevatedButton(
                onPressed: _acting ? null : _confirm,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Confirm Visit',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                onPressed: _acting ? null : _reschedule,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Propose Time',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _acting ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Cancel Visit',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                )),
          ],

          // ── Customer's turn: owner already proposed, waiting ──
          if (customerTurn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Waiting for the customer to respond',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1565C0))),
                    const SizedBox(height: 2),
                    Text('You proposed $date at $time.',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF1565C0))),
                  ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _acting ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Cancel Visit',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                )),
          ],

          // ── Confirmed: complete / reschedule / cancel ──
          if (status == 'confirmed') ...[
            Row(children: [
              Expanded(
                  child: ElevatedButton(
                onPressed: _acting
                    ? null
                    : () async {
                        setState(() => _acting = true);
                        await ApiService.completeVisitOwner(widget.visitId);
                        widget.onRefresh();
                        if (mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Mark Completed',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                onPressed: _acting ? null : _reschedule,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Reschedule',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _acting ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Cancel Visit',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                )),
          ],
        ]),
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      const mo = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${mo[d.month - 1]},${d.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Reschedule screen ──────────────────────────────────────────
class _RescheduleScreen extends StatefulWidget {
  final Map<String, dynamic> visit;
  final VoidCallback onDone;
  const _RescheduleScreen({required this.visit, required this.onDone});
  @override
  State<_RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<_RescheduleScreen> {
  DateTime? _date;
  String? _time;
  final _reason = TextEditingController();
  bool _saving = false;

  final _times = [
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM'
  ];

  Future<void> _save() async {
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a date and time'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.rescheduleVisitOwner(
        widget.visit['_id'] as String,
        newDate: _date!.toIso8601String(),
        newTime: _time!,
        reason: _reason.text.trim(),
      );
      widget.onDone();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final name = v['visitorName'] as String? ?? '—';
    final curr = _fmtDate(v['visitDate'] as String?);
    final time = v['visitTime'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        title: const Text('Reschedule Visit',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textDark)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rescheduling',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('Date: $curr',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
              Text('Time: $time',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(height: 20),
          // Pick new date
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 60)),
                builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary)),
                    child: child!),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _date != null ? AppColors.primary : AppColors.border,
                    width: _date != null ? 1.5 : 1),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    color:
                        _date != null ? AppColors.primary : AppColors.textLight,
                    size: 18),
                const SizedBox(width: 10),
                Text(
                    _date == null
                        ? 'Select new date'
                        : '${_date!.day}/${_date!.month}/${_date!.year}',
                    style: TextStyle(
                        fontSize: 14,
                        color: _date != null
                            ? AppColors.textDark
                            : AppColors.textLight,
                        fontWeight:
                            _date != null ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Time slots
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _times
                  .map((t) => GestureDetector(
                        onTap: () => setState(() => _time = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color:
                                _time == t ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _time == t
                                    ? AppColors.primary
                                    : AppColors.border),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _time == t
                                      ? Colors.white
                                      : AppColors.textDark)),
                        ),
                      ))
                  .toList()),
          const SizedBox(height: 16),
          const Text('Reason for rescheduling',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Eg owner not available.',
              hintStyle: const TextStyle(color: AppColors.textLight),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text('Reschedule',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              )),
          const SizedBox(height: 10),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Cancel',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      const mo = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${mo[d.month - 1]},${d.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calendar_month_outlined,
              size: 60, color: AppColors.textLight),
          SizedBox(height: 14),
          Text('No visits found',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          SizedBox(height: 6),
          Text('Customer visit requests will appear here',
              style: TextStyle(color: AppColors.textMuted)),
        ]),
      );
}
