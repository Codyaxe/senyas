import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../widgets/senyas_status_bar.dart';
import '../widgets/senyas_header.dart';
import '../widgets/senyas_bottom_nav.dart';
import '../widgets/senyas_home_indicator.dart';
import '../widgets/custom_toggle_switch.dart';
import '../engine/engine.dart';
import '../features/sign/demo_mode.dart';

/// Implementation of Figma Node 36:705 - Settings Page
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _whisperSTTEnabled = false;
  bool _disableThinkingMode = false;
  bool _optimizePerformance = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Status bar
            const SenyasStatusBar(isDark: true),

            // Header with Back Arrow
            SenyasSubHeader(
              title: 'Settings',
              onBack: () => Navigator.of(context).pop(),
            ),

            // Main Settings Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Model Management
                    Text(
                      'Model Management',
                      style: AppTextStyles.h3(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Automatically loads and unloads models to save VRAM and keep performance fast.',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    // Whisper STT Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider, width: 1),
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            AppAssets.aiSparkle,
                            width: 32,
                            height: 32,
                            colorFilter: const ColorFilter.mode(
                                AppColors.textSecondary, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Whisper STT Model',
                                  style: AppTextStyles.semiBold16(),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Enable Whisper speech-to-text model management',
                                  style: AppTextStyles.caption(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          CustomToggleSwitch(
                            value: _whisperSTTEnabled,
                            onChanged: (val) {
                              setState(() => _whisperSTTEnabled = val);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Section 2: Performance
                    Text(
                      'Performance',
                      style: AppTextStyles.h3(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Settings to optimize and enhance certain feature for lower-end devices',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    // Performance Dual Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider, width: 1),
                      ),
                      child: Column(
                        children: [
                          // Row 1: Disable Thinking Mode
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  AppAssets.speechBubble,
                                  width: 30,
                                  height: 30,
                                  colorFilter: const ColorFilter.mode(
                                      AppColors.textSecondary, BlendMode.srcIn),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Disable Thinking Mode',
                                        style: AppTextStyles.semiBold16(),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Lower Latency For Real Time Use',
                                        style: AppTextStyles.caption(
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CustomToggleSwitch(
                                  value: _disableThinkingMode,
                                  onChanged: (val) {
                                    setState(() => _disableThinkingMode = val);
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Divider Line
                          const Divider(
                              height: 1, indent: 16, endIndent: 16, color: AppColors.divider),

                          // Row 2: Optimize Performance
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  AppAssets.gearSettings,
                                  width: 30,
                                  height: 30,
                                  colorFilter: const ColorFilter.mode(
                                      AppColors.textSecondary, BlendMode.srcIn),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Optimize Performance',
                                        style: AppTextStyles.semiBold16(),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Balanced performance & Memory',
                                        style: AppTextStyles.caption(
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CustomToggleSwitch(
                                  value: _optimizePerformance,
                                  onChanged: (val) {
                                    setState(() => _optimizePerformance = val);
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Divider Line
                          const Divider(
                              height: 1, indent: 16, endIndent: 16, color: AppColors.divider),

                          // Row 3: Demo Mode
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.back_hand_outlined,
                                    size: 28, color: AppColors.textSecondary),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Demo Mode',
                                        style: AppTextStyles.semiBold16(),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Show 7-handshape cheat sheet + heuristic gestures (off = FSL-105 recognizer only)',
                                        style: AppTextStyles.caption(
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CustomToggleSwitch(
                                  value: SenyasSettings.demoMode.value,
                                  onChanged: (val) {
                                    SenyasSettings.demoMode.value = val;
                                    senyas.setDemoMode(val);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            SenyasBottomNav(
              currentIndex: 0,
              onTabSelected: (index) {
                Navigator.of(context).pop();
              },
            ),

            // Home Indicator Area
            const SenyasHomeIndicator(),
          ],
        ),
      ),
    );
  }
}
