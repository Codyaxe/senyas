import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';

/// Reusable Bottom Navigation Bar (Height: 68, 3 Tabs: Home, History, Profile)
class SenyasBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const SenyasBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Home Tab
          _buildNavItem(
            index: 0,
            activeAsset: AppAssets.houseActive,
            inactiveAsset: AppAssets.houseInactive,
          ),
          // History Tab
          _buildNavItem(
            index: 1,
            activeAsset: AppAssets.historyActive,
            inactiveAsset: AppAssets.historyInactive,
          ),
          // Profile Tab
          _buildNavItem(
            index: 2,
            activeAsset: AppAssets.userActive,
            inactiveAsset: AppAssets.userInactive,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String activeAsset,
    required String inactiveAsset,
  }) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navItemActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          isSelected ? activeAsset : inactiveAsset,
          width: 24,
          height: 24,
        ),
      ),
    );
  }
}
