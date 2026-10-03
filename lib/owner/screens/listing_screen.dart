import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/property_thumb.dart';
import '../widgets/delete_confirm_sheet.dart';
import 'change_status_screen.dart';
import 'upload_property_screen.dart';
import 'edit_property_screen.dart';

class ListingTab extends StatefulWidget {
  final void Function(int) onSwitchTab;
  const ListingTab({super.key, required this.onSwitchTab});
  @override
  State<ListingTab> createState() => _ListingTabState();
}

class _ListingTabState extends State<ListingTab> {
  List<dynamic> _properties = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMyProperties(
        status: _filter == 'all' ? null : _filter,
      );
      if (mounted) setState(() {
        _properties = res['properties'] as List? ?? [];
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _deleteProperty(Map<String, dynamic> prop) async {
    final id = prop['_id']?.toString();
    if (id == null) return;
    final name = (prop['propertyName'] ?? 'this listing').toString();

    final confirm = await showDeleteListingSheet(context, name: name);
    if (!confirm || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
    );
    try {
      await ApiService.deleteProperty(id);
      if (!mounted) return;
      Navigator.pop(context); // remove spinner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing deleted')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // remove spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  String _filterLabel(String f) {
    const map = {'all': 'All', 'active': 'Active', 'under_review': 'Under Review',
                 'rejected': 'Rejected', 'inactive': 'Inactive'};
    return map[f] ?? f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Listings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                Text('All your uploaded properties', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ])),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: AppColors.primary)),
              IconButton(
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UploadPropertyScreen()));
                  _load(); // refresh after upload
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              children: ['all', 'active', 'under_review', 'rejected', 'inactive'].map((f) {
                final active = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: GestureDetector(
                      onTap: () { setState(() => _filter = f); _load(); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(_filterLabel(f),
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: active ? Colors.white : AppColors.textDark,
                            )),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _properties.isEmpty
                    ? _EmptyState(onUpload: () async {
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const UploadPropertyScreen()));
                        _load();
                      })
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: _properties.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _PropertyTile(
                            property: _properties[i] as Map<String, dynamic>,
                            onEdit: () async {
                              await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => EditPropertyScreen(
                                    property: _properties[i] as Map<String, dynamic>),
                              ));
                              _load();
                            },
                            onDelete: () => _deleteProperty(
                                _properties[i] as Map<String, dynamic>),
                            onStatus: () async {
                              final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ChangeStatusScreen(
                                          property: _properties[i]
                                              as Map<String, dynamic>)));
                              if (changed == true) _load();
                            },
                          ),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyState({required this.onUpload});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Image.asset('assets/images/no_property.png', width: 240),
      const SizedBox(height: 12),
      const Text('Upload your first property to get started', style: TextStyle(color: AppColors.textMuted)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onUpload,
        icon: const Icon(Icons.add),
        label: const Text('Upload Property'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}

class _PropertyTile extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStatus;
  const _PropertyTile(
      {required this.property,
      required this.onEdit,
      required this.onDelete,
      required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final status     = property['status']       as String? ?? 'under_review';
    final isVerified = property['isVerified']   as bool?   ?? false;
    final rejNote    = property['rejectionNote'] as String? ?? '';

    Color statusColor; String statusLabel;
    switch (status) {
      case 'active':   statusColor = AppColors.success;       statusLabel = 'Active';       break;
      case 'sold':     statusColor = AppColors.success;       statusLabel = '✓ Booked / Sold'; break;
      case 'archived': statusColor = AppColors.textLight;     statusLabel = 'Archived';     break;
      case 'rejected': statusColor = AppColors.error;         statusLabel = 'Rejected';     break;
      case 'suspended':statusColor = AppColors.error;         statusLabel = 'Suspended';    break;
      case 'inactive': statusColor = AppColors.textLight;     statusLabel = 'Inactive';     break;
      default:         statusColor = const Color(0xFFE65100); statusLabel = 'Under Review';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PropertyThumb(property: property, size: 48, radius: 12),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(property['propertyName'] ?? 'Unnamed',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(property['location'] ?? '',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          // Edit button
          IconButton(
            onPressed: onEdit,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
            ),
          ),
          // Status (availability) button
          IconButton(
            onPressed: onStatus,
            tooltip: 'Change status',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.published_with_changes_rounded,
                  size: 16, color: AppColors.primary),
            ),
          ),
          // Delete button
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete listing',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _Badge(label: statusLabel, color: statusColor),
          if (isVerified)
            _Badge(label: '✓ Legally Verified', color: AppColors.success),
          if (status == 'under_review' && !isVerified)
            _Badge(label: '⏳ Awaiting Verification', color: const Color(0xFFE65100)),
        ]),
        if (status == 'rejected' && rejNote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text('Rejection reason: $rejNote',
                style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ),
        ],
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}
