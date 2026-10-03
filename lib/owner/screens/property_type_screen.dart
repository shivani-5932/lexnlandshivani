import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'property_details_screen.dart';

class PropertyTypeScreen extends StatefulWidget {
  const PropertyTypeScreen({super.key});

  @override
  State<PropertyTypeScreen> createState() => _PropertyTypeScreenState();
}

class _PropertyTypeScreenState extends State<PropertyTypeScreen> {
  String? _selected;
  bool _dropdownOpen = false;

  final List<Map<String, dynamic>> _types = [
    {'value': 'pg', 'label': 'PG Room', 'icon': Icons.bed_rounded},
    {'value': 'guest', 'label': 'Guest Room', 'icon': Icons.hotel_rounded},
    {'value': 'plot', 'label': 'Plot', 'icon': Icons.landscape_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final selectedType =
        _types.firstWhere((t) => t['value'] == _selected, orElse: () => {});

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Select Property to Upload',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Illustration
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Building illustration (simplified)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.apartment_rounded,
                                  size: 80, color: AppColors.primary.withOpacity(0.7)),
                              const SizedBox(height: 8),
                              Text(
                                'Select a property type',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Enter Property Details heading
                    const Text(
                      'Enter Property Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose PG, Guest Room or Plot',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),

                    // Dropdown
                    GestureDetector(
                      onTap: () =>
                          setState(() => _dropdownOpen = !_dropdownOpen),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 15),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _dropdownOpen
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selected != null
                                    ? selectedType['label'] as String
                                    : 'Choose',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _selected != null
                                      ? AppColors.textDark
                                      : AppColors.textLight,
                                  fontWeight: _selected != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            Icon(
                              _dropdownOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dropdown Options
                    if (_dropdownOpen)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: _types.map((type) {
                            final isLast = _types.last == type;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selected = type['value'] as String;
                                  _dropdownOpen = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  border: isLast
                                      ? null
                                      : const Border(
                                          bottom: BorderSide(
                                              color: AppColors.border)),
                                  color: _selected == type['value']
                                      ? AppColors.primaryLight
                                      : Colors.transparent,
                                  borderRadius: isLast
                                      ? const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(type['icon'] as IconData,
                                        size: 20, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Text(
                                      type['label'] as String,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: _selected == type['value']
                                            ? AppColors.primary
                                            : AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ── Next Button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PrimaryButton(
                label: 'Next',
                onPressed: _selected == null
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please select a property type')),
                        );
                      }
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyDetailsScreen(
                                propertyType: _selected!),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
