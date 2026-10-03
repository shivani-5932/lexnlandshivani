import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Lets the owner control a property's visibility:
///  • Available    → status 'active' (shown to customers, if verified)
///  • Booked/Sold  → status 'sold'   (hidden from customers, marked sold)
///  • Archived     → status 'archived' (hidden until the owner restores it)
class ChangeStatusScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  const ChangeStatusScreen({super.key, required this.property});
  @override
  State<ChangeStatusScreen> createState() => _ChangeStatusScreenState();
}

class _ChangeStatusScreenState extends State<ChangeStatusScreen> {
  late bool _sold;
  late bool _archived;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final status = (widget.property['status'] ?? '').toString();
    _sold = status == 'sold';
    _archived = status == 'archived';
  }

  bool get _available => !_sold;

  Future<void> _save() async {
    final id = widget.property['_id']?.toString();
    if (id == null) return;
    final status = _archived ? 'archived' : (_sold ? 'sold' : 'active');
    setState(() => _saving = true);
    try {
      await ApiService.updatePropertyStatus(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_archived
              ? 'Property archived'
              : _sold
                  ? 'Marked as Booked / Sold'
                  : 'Property is now available')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.property['propertyName'] ?? 'Property').toString();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context)),
        title: Text(name,
            style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Visibility'),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        _row(
                          title: 'Available',
                          subtitle: 'Visible to buyers (once verified)',
                          value: _available,
                          enabled: !_archived,
                          onChanged: (v) => setState(() => _sold = !v),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _row(
                          title: 'Booked / Sold',
                          subtitle:
                              'Hidden from buyers · shown to you as sold ✓',
                          value: _sold,
                          enabled: !_archived,
                          onChanged: (v) => setState(() => _sold = v),
                        ),
                      ]),
                    ),
                    if (_sold && !_archived) ...[
                      const SizedBox(height: 8),
                      Row(children: const [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 16),
                        SizedBox(width: 6),
                        Text('You marked this property as sold',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ]),
                    ],
                    const SizedBox(height: 22),
                    const _SectionLabel('Archive'),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _row(
                        title: 'Archive this property',
                        subtitle:
                            'Hidden from everyone until you restore it. You can make it public again anytime.',
                        value: _archived,
                        enabled: true,
                        onChanged: (v) => setState(() => _archived = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Done',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) =>
      Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeColor: Colors.white,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted)),
      );
}
