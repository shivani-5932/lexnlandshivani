import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'listing_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

/// MainShell — persistent bottom nav using IndexedStack.
/// All four tabs stay alive; switching never rebuilds or loses state.
/// Sub-screens (visits, notifications etc.) are pushed on top via
/// Navigator.push from within a tab — they get their own AppBar back
/// button and the bottom bar stays hidden under them (standard UX).
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void switchTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          HomeTab(onSwitchTab: switchTab),
          ListingTab(onSwitchTab: switchTab),
          DashboardTab(onSwitchTab: switchTab),
          ProfileTab(onSwitchTab: switchTab),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onTap: switchTab,
      ),
    );
  }
}

// ── Persistent bottom bar ──────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.list_alt_rounded, label: 'Listing'),
      _NavItem(icon: Icons.bar_chart_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              final color = active ? AppColors.primary : AppColors.textLight;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primaryLight
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(items[i].icon, size: 22, color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(items[i].label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}
