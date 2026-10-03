import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class GroupRoomScreen extends StatefulWidget {
  const GroupRoomScreen({super.key});

  @override
  State<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends State<GroupRoomScreen> {
  // Room counts
  final _totalCtrl = TextEditingController(text: '7');
  final _acCtrl = TextEditingController(text: '3');
  final _nonAcCtrl = TextEditingController(text: '4');

  // Pricing — 2 persons
  final _price2Ctrl = TextEditingController(text: '5,999');
  final _deposit2Ctrl = TextEditingController(text: '2,999');

  // Pricing — 3 persons
  final _price3Ctrl = TextEditingController(text: '8,999');
  final _deposit3Ctrl = TextEditingController(text: '4,999');

  // Pricing — 4 persons
  final _price4Ctrl = TextEditingController(text: '11,999');
  final _deposit4Ctrl = TextEditingController(text: '8,999');

  Widget _cardRow(String label, TextEditingController ctrl,
      {String prefix = 'Rs ', bool showBorder = true, String? sublabel}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.8))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
                if (sublabel != null)
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          Text(prefix,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countRow(String label, TextEditingController ctrl,
      {bool showBorder = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.8))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 50,
            child: TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          const SizedBox(width: 8),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Group Room Details',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Room Details ──
                    _sectionHeader('Group Room Details', ''),
                    _card([
                      _countRow('Total Group Rooms', _totalCtrl),
                      _countRow('Ac Rooms', _acCtrl),
                      _countRow('Non Ac Rooms', _nonAcCtrl, showBorder: false),
                    ]),

                    // ── Pricing ──
                    _sectionHeader('Group Pricing', 'Monthly For\nEntire Room'),

                    // 2 Persons
                    _card([
                      _cardRow('For  2 Persons Room', _price2Ctrl),
                      _cardRow('Advance Deposit', _deposit2Ctrl,
                          sublabel: '( First time before stay)',
                          showBorder: false),
                    ]),

                    // 3 Persons
                    _card([
                      _cardRow('For  3 Persons Room', _price3Ctrl),
                      _cardRow('Advance Deposit', _deposit3Ctrl,
                          sublabel: '( First time before stay)',
                          showBorder: false),
                    ]),

                    // 4 Persons
                    _card([
                      _cardRow('For  4 Persons Room', _price4Ctrl),
                      _cardRow('Advance Deposit', _deposit4Ctrl,
                          sublabel: '( First time before stay)',
                          showBorder: false),
                    ]),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PrimaryButton(
                label: 'Save',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Group room details saved!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
