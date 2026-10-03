import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class PlotDetailScreen extends StatefulWidget {
  final String plotId;
  const PlotDetailScreen({super.key, required this.plotId});
  @override
  State<PlotDetailScreen> createState() => _PlotDetailScreenState();
}

class _PlotDetailScreenState extends State<PlotDetailScreen> {
  Map<String, dynamic>? _plot;
  int _myRating = 0;
  bool _ratingBusy = false;
  bool _loading = true;
  bool _isFav = false;
  int _activePhoto = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Opens the owner's exact Google Maps link. Only called when one exists.
  Future<void> _openLocation() async {
    final mapLink = (_plot?['mapLink'] ?? '').toString().trim();
    if (mapLink.isEmpty) return;
    final uri = Uri.parse(mapLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')));
    }
  }

  Future<void> _load() async {
    try {
      final res = await Api.getPlotById(widget.plotId);
      if (mounted)
        setState(() {
          _plot = res['property'] as Map<String, dynamic>?;
          _loading = false;
        });
      _checkFav();
      _loadMyRating();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyRating() async {
    try {
      final res = await Api.myPlotRating(widget.plotId);
      if (mounted && res['success'] == true) {
        setState(() => _myRating = (res['myRating'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _submitRating(int r) async {
    setState(() => _ratingBusy = true);
    try {
      final res = await Api.ratePlot(widget.plotId, r);
      if (mounted && res['success'] == true) {
        setState(() {
          _myRating = (res['myRating'] as num?)?.toInt() ?? r;
          if (_plot != null) {
            _plot!['ratingAverage'] = res['ratingAverage'];
            _plot!['ratingCount'] = res['ratingCount'];
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for rating!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not submit rating. Please sign in and try again.'),
              backgroundColor: C.error),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingBusy = false);
    }
  }

  Future<void> _checkFav() async {
    try {
      final ids = await Api.getFavouriteIds();
      final list = ids['ids'] as List? ?? [];
      if (mounted) setState(() => _isFav = list.contains(widget.plotId));
    } catch (_) {}
  }

  Future<void> _toggleFav() async {
    final was = _isFav;
    setState(() => _isFav = !was);
    try {
      await Api.toggleFavourite(widget.plotId, was);
    } catch (_) {
      if (mounted) setState(() => _isFav = was);
    }
  }

  Future<void> _openChat() async {
    final ownerId = (_plot!['owner'] as Map?)?['_id'] as String?;
    if (ownerId == null) return;
    try {
      final res =
          await Api.getOrCreateChat(plotId: widget.plotId, ownerId: ownerId);
      final chat = res['chat'] as Map<String, dynamic>;
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chat['_id'] as String,
                ownerName:
                    (chat['owner'] as Map?)?['name'] as String? ?? 'Owner',
                plotName: _plot!['propertyName'] ?? 'Plot',
              ),
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: C.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: C.primary)));
    if (_plot == null)
      return const Scaffold(body: Center(child: Text('Plot not found')));

    final d = _plot!['plotDetails'] as Map<String, dynamic>? ?? {};
    final photos = _plot!['photos'] as List? ?? [];
    final owner = _plot!['owner'] as Map<String, dynamic>? ?? {};
    final price = d['totalPrice'] as num? ?? 0;
    final size = d['plotSize'] as num? ?? 0;
    final ppSqft = d['pricePerSqft'] as num? ?? 0;
    final len = (d['plotDimensions']?['length'] as num?)?.toInt() ?? 0;
    final wid = (d['plotDimensions']?['width'] as num?)?.toInt() ?? 0;
    final isVerified = _plot!['isVerified'] as bool? ?? false;
    final status = (_plot!['status'] ?? 'active').toString();
    final hasRegistry =
        (_plot!['registryDocument'] ?? '').toString().isNotEmpty;
    final hasNoc = (_plot!['nocDocument'] ?? '').toString().isNotEmpty;
    final idVerified = owner['isAadhaarVerified'] == true;
    final avg = (_plot!['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = _plot!['ratingCount'] as int? ?? 0;
    final hasMap = (_plot!['mapLink'] ?? '').toString().trim().isNotEmpty;
    final facilities = (d['facilities'] as List? ?? []);

    final statusLabel = status == 'sold'
        ? 'Booked / Sold'
        : status == 'archived'
            ? 'Archived'
            : 'Available';
    final statusColor =
        status == 'active' ? C.success : C.textMuted;

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        slivers: [
          // ── Photo header (back + favourite only — no share) ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: C.primary,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const BackButton(color: Colors.white),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleFav,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFav ? const Color(0xFFEF5350) : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                if (photos.isEmpty)
                  Container(
                      color: C.primaryLight,
                      child: Center(
                          child: Image.asset('assets/images/logo_lexnland.png',
                              width: 96, height: 96)))
                else
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _activePhoto = i),
                    itemBuilder: (_, i) => Image.network(
                      _fullUrl(photos[i] as String),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: C.primaryLight,
                          child: Center(
                              child: Image.asset(
                                  'assets/images/logo_lexnland.png',
                                  width: 72,
                                  height: 72))),
                    ),
                  ),
                // Price badge (top-left)
                Positioned(
                  left: 14,
                  top: MediaQuery.of(context).padding.top + 56,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: C.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                        price > 0 ? '₹${_fmt(price.toInt())}' : 'Ask Price',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                // Photo counter (bottom-right)
                if (photos.length > 1)
                  Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${_activePhoto + 1} / ${photos.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      )),
              ]),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + plot type
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(_plot!['propertyName'] ?? 'Plot',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: C.textDark)),
                          ),
                          if ((d['plotType'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: Text(d['plotType'].toString(),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: C.textMuted)),
                            ),
                        ]),
                    const SizedBox(height: 6),

                    // Location + Directions
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 15, color: C.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Text(_plot!['location'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: C.textMuted))),
                      if (hasMap)
                        GestureDetector(
                          onTap: _openLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.directions_rounded,
                                      size: 15, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 4),
                                  Text('Directions',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2E7D32))),
                                ]),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 10),

                    // Status + rating
                    Row(children: [
                      Text(statusLabel,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: statusColor)),
                      const Spacer(),
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFA726), size: 18),
                      const SizedBox(width: 3),
                      Text(ratingCount > 0 ? avg.toStringAsFixed(1) : 'New',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.textDark)),
                    ]),
                    const SizedBox(height: 14),

                    // Trust chips
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (idVerified) const _TagChip('Verified Owner'),
                      if (hasRegistry && hasNoc)
                        const _TagChip('Legal Checked'),
                    ]),
                    const SizedBox(height: 20),

                    // ── Plot Specification ──
                    _SectionTitle('Plot Specification'),
                    const SizedBox(height: 10),
                    _SpecCard(items: [
                      if (size > 0) _Spec('Area', '${size.toInt()}\nsq ft'),
                      if ((d['facing'] ?? '').toString().isNotEmpty)
                        _Spec('Facing', d['facing'].toString()),
                      if (len > 0 && wid > 0) _Spec('L x B', '$len x $wid'),
                      if (ppSqft > 0)
                        _Spec('Per sqft', '₹${ppSqft.toInt()}'),
                      if ((d['ownershipType'] ?? '').toString().isNotEmpty)
                        _Spec('Ownership', d['ownershipType'].toString()),
                    ]),
                    const SizedBox(height: 18),

                    // ── Legal & Approvals ──
                    _SectionTitle('Legal & Approvals'),
                    const SizedBox(height: 10),
                    _ApprovalCard(items: [
                      _Approval('Verified Property', isVerified),
                      _Approval('Registry Available', hasRegistry),
                      _Approval('NOC Available', hasNoc),
                      _Approval('Approved Area', isVerified),
                    ]),
                    const SizedBox(height: 18),

                    // ── Facilities ──
                    if (facilities.isNotEmpty) ...[
                      _SectionTitle('Facilities'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: C.border),
                        ),
                        child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: facilities
                                .map((f) => _FacilityChip(f.toString()))
                                .toList()),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // ── Description ──
                    if ((d['description'] ?? '').toString().isNotEmpty) ...[
                      _SectionTitle('Description'),
                      const SizedBox(height: 8),
                      Text(d['description'].toString(),
                          style: const TextStyle(
                              fontSize: 14, color: C.textMuted, height: 1.6)),
                      const SizedBox(height: 18),
                    ],

                    // ── Rating ──
                    _buildRatingSection(),
                    const SizedBox(height: 18),

                    // ── Owner (chat only) ──
                    _SectionTitle('Owner'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: C.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                              color: C.primaryLight, shape: BoxShape.circle),
                          child: Center(
                              child: Text(
                            (owner['name'] as String? ?? 'O')[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: C.primary),
                          )),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(owner['name'] ?? 'Property Owner',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: C.textDark)),
                              const SizedBox(height: 2),
                              const Text('Property Owner',
                                  style: TextStyle(
                                      fontSize: 13, color: C.textMuted)),
                            ])),
                        // Chat icon (no call)
                        GestureDetector(
                          onTap: _openChat,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: C.primaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: C.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded,
                                size: 20, color: C.primary),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 80),
                  ]),
            ),
          ),
        ],
      ),

      // ── Single CTA: Contact Owner (chat) ──
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: C.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
              label: const Text('Contact Owner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    final avg = (_plot?['ratingAverage'] as num?)?.toDouble() ?? 0.0;
    final count = _plot?['ratingCount'] as int? ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFA726), size: 22),
          const SizedBox(width: 6),
          Text(count > 0 ? avg.toStringAsFixed(1) : 'No ratings yet',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: C.textDark)),
          const SizedBox(width: 6),
          if (count > 0)
            Text('($count ${count == 1 ? "rating" : "ratings"})',
                style: const TextStyle(fontSize: 13, color: C.textMuted)),
        ]),
        const SizedBox(height: 12),
        Text(_myRating > 0 ? 'Your rating' : 'Rate this plot',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: C.textMuted)),
        const SizedBox(height: 6),
        Row(
            children: List.generate(5, (i) {
          final filled = i < _myRating;
          return GestureDetector(
            onTap: _ratingBusy ? null : () => _submitRating(i + 1),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFFFA726),
                  size: 32),
            ),
          );
        })),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: C.textDark));
}

// Horizontal spec grid (Area | Facing | L x B | …)
class _SpecCard extends StatelessWidget {
  final List<_Spec> items;
  const _SpecCard({required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(Expanded(child: _specCol(items[i])));
      if (i < items.length - 1) {
        children.add(Container(width: 1, height: 38, color: C.border));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
    );
  }

  Widget _specCol(_Spec s) => Column(children: [
        Text(s.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: C.primary)),
        const SizedBox(height: 4),
        Text(s.value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: C.textDark,
                height: 1.2)),
      ]);
}

class _Spec {
  final String label, value;
  const _Spec(this.label, this.value);
}

// Legal & approvals row of checkmarks
class _ApprovalCard extends StatelessWidget {
  final List<_Approval> items;
  const _ApprovalCard({required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Row(
          children: items
              .map((a) => Expanded(
                    child: Column(children: [
                      Icon(
                          a.ok
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: a.ok ? C.success : C.textLight,
                          size: 22),
                      const SizedBox(height: 6),
                      Text(a.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: C.textDark,
                              height: 1.2)),
                    ]),
                  ))
              .toList()),
    );
  }
}

class _Approval {
  final String label;
  final bool ok;
  const _Approval(this.label, this.ok);
}

class _FacilityChip extends StatelessWidget {
  final String label;
  const _FacilityChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.border),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: C.textDark)),
      );
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: C.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.primary.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: C.primary)),
      );
}

String _fullUrl(String url) =>
    url.startsWith('http') ? url : '${Api.mediaBase}$url';
String _fmt(int n) {
  if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)} Cr';
  if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)} L';
  return n.toString();
}
