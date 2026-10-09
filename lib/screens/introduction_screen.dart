import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../widgets/senyas_status_bar.dart';
import '../widgets/senyas_home_indicator.dart';
import 'main_tab_scaffold.dart';

/// Implementation of Figma Node 57:1254 - Introduction Screen
class IntroductionScreen extends StatelessWidget {
  const IntroductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.introBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Status bar (with green primary tint)
            const SenyasStatusBar(
              isDark: false,
              textColor: AppColors.primary,
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // Senyas Brand Logo
                    Hero(
                      tag: 'senyas_logo',
                      child: Image.asset(
                        AppAssets.senyasLogo,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.accent2Soft,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.sign_language_rounded,
                                size: 80,
                                color: AppColors.accent2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tagline: "Sign. Speak. Understand."
                    Text(
                      'Sign. Speak. Understand.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2(color: AppColors.accent2),
                    ),

                    const SizedBox(height: 8),

                    // Description text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'An offline two-way communication assistant for Deaf, Hard of Hearing and everyone.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h3(color: AppColors.textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Feature Pill 1: FSL - Filipino Translation
                    _buildFeaturePill(
                      bgColor: AppColors.accent2Soft,
                      iconCircleColor: AppColors.accent2Light,
                      iconAsset: AppAssets.wave,
                      textColor: AppColors.accent2Dark,
                      title: 'FSL - Filipino Translation',
                    ),

                    const SizedBox(height: 12),

                    // Feature Pill 2: Speech - Text Translation
                    _buildFeaturePill(
                      bgColor: AppColors.accentGreenSoft,
                      iconCircleColor: AppColors.accentGreenDark,
                      iconAsset: AppAssets.spectrumTeal,
                      textColor: AppColors.primary,
                      title: 'Speech - Text Translation',
                    ),

                    const SizedBox(height: 12),

                    // Feature Pill 3: Works Offline (No Internet Needed)
                    _buildFeaturePill(
                      bgColor: AppColors.accent2Soft,
                      iconCircleColor: AppColors.accent2Light,
                      iconAsset: AppAssets.wifiBlue,
                      textColor: AppColors.accent2Dark,
                      title: 'Works Offline (No Internet Needed)',
                    ),

                    const SizedBox(height: 32),

                    // "Get Started" CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (context, anim, secAnim) =>
                                  const MainTabScaffold(),
                              transitionsBuilder: (context, anim, secAnim, child) {
                                return FadeTransition(opacity: anim, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textWhite,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                          shadowColor: Colors.transparent,
                        ),
                        child: Text(
                          'Get Started',
                          style: AppTextStyles.h3(color: AppColors.textWhite).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Home Indicator Area
            const SenyasHomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required Color bgColor,
    required Color iconCircleColor,
    required String iconAsset,
    required Color textColor,
    required String title,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      height: 63,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Row(
        children: [
          // Icon circular badge
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconCircleColor,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(6),
            child: SvgPicture.asset(
              iconAsset,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          // Feature title
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.medium12(color: textColor).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 30), // Balances the icon width
        ],
      ),
    );
  }
}
