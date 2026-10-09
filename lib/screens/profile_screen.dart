import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../widgets/senyas_header.dart';
import 'settings_screen.dart';

/// Implementation of Figma Node 37:917 - Profile Page
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        SenyasHeader(
          title: 'Profile',
          onEllipsisTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
        ),

        // Main Content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo & Tagline Hero Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'senyas_profile_logo',
                        child: Image.asset(
                          AppAssets.senyasLogo,
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.accent2Soft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.sign_language_rounded,
                                size: 60,
                                color: AppColors.accent2,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sign. Speak. Understand.',
                        style: AppTextStyles.h3(color: AppColors.accent2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Settings List Items Container
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Item 1: About Senyas
                      _buildProfileRow(
                        context: context,
                        iconAsset: AppAssets.about,
                        title: 'About Senyas',
                        subtitle: 'Version 1.0.0 (Offline)',
                        onTap: () {
                          _showInfoDialog(
                            context: context,
                            title: 'About Senyas',
                            message:
                                'Senyas is an offline two-way communication assistant designed to bridge communication between Deaf, Hard of Hearing individuals and the general public using on-device ML models.',
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.divider),

                      // Item 2: Model Info -> Navigates to Settings
                      _buildProfileRow(
                        context: context,
                        iconAsset: AppAssets.modelGear,
                        title: 'Model Info',
                        subtitle: 'Gemma 4 E28 + Whispher',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.divider),

                      // Item 3: Device
                      _buildProfileRow(
                        context: context,
                        iconAsset: AppAssets.devicePhone,
                        title: 'Device',
                        subtitle: 'Cactus (Android)',
                        onTap: () {
                          _showInfoDialog(
                            context: context,
                            title: 'Device Hardware',
                            message:
                                'Platform: Android (Cactus Target)\nHardware Acceleration: NPU Enabled\nOffline Inference: Active',
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.divider),

                      // Item 4: Privacy
                      _buildProfileRow(
                        context: context,
                        iconAsset: AppAssets.privacyPadlock,
                        title: 'Privacy',
                        subtitle: 'Your data stays on your device',
                        onTap: () {
                          _showInfoDialog(
                            context: context,
                            title: 'Offline Privacy Guarantee',
                            message:
                                '100% On-Device Processing. No voice recordings or sign language video feeds are ever sent over the network or stored externally.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow({
    required BuildContext context,
    required String iconAsset,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent2Soft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconAsset,
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(AppColors.accent2Dark, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.semiBold16(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Chevron Next
            SvgPicture.asset(
              AppAssets.chevronNextAlt,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: AppTextStyles.h3()),
        content: Text(message, style: AppTextStyles.body(color: AppColors.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
