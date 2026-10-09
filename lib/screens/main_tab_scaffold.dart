import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/senyas_status_bar.dart';
import '../widgets/senyas_bottom_nav.dart';
import '../widgets/senyas_home_indicator.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Main container scaffold that manages the Bottom Navigation Bar between
/// Home (Node 2:67), History (Node 32:288), and Profile (Node 37:917).
class MainTabScaffold extends StatefulWidget {
  final int initialIndex;

  const MainTabScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Reusable Status Bar
            const SenyasStatusBar(isDark: true),

            // Tab Page Body
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  HomeScreen(onSettingsTap: _openSettings),
                  HistoryScreen(onSettingsTap: _openSettings),
                  const ProfileScreen(),
                ],
              ),
            ),

            // Bottom Navigation Bar
            SenyasBottomNav(
              currentIndex: _currentIndex,
              onTabSelected: (index) {
                setState(() => _currentIndex = index);
              },
            ),

            // iOS Home Indicator Area
            const SenyasHomeIndicator(),
          ],
        ),
      ),
    );
  }
}
