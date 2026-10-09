import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../widgets/senyas_header.dart';
import 'sign_translation_screen.dart';
import 'speech_translation_screen.dart';

/// Implementation of Figma Node 2:67 - Front Page / Home Screen
class HomeScreen extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const HomeScreen({
    super.key,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        SenyasHeader(
          title: 'Senyas',
          subtitle: 'FTL Sign Translator AI',
          onEllipsisTap: onSettingsTap,
        ),

        // Main Content Area
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Featured Region Card
                _buildFeaturedCard(context),

                const SizedBox(height: 24),

                // Sign Translation Action Button Card
                _buildActionCard(
                  context: context,
                  bgColor: AppColors.signCardBg,
                  circleBgColor: AppColors.accentGreenDark,
                  iconAsset: AppAssets.cameraFilled,
                  iconSize: 32,
                  title: 'Sign Translation',
                  subtitle: 'Sign to Text',
                  titleColor: AppColors.textPrimary,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignTranslationScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Speech Translation Action Button Card
                _buildActionCard(
                  context: context,
                  bgColor: AppColors.speechCardBg,
                  circleBgColor: AppColors.accent2Light,
                  iconAsset: AppAssets.micFilled,
                  iconSize: 32,
                  title: 'Speech Translation',
                  subtitle: 'Voice to Text',
                  titleColor: AppColors.accent2Dark,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SpeechTranslationScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SignTranslationScreen(),
          ),
        );
      },
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          color: AppColors.accent2Lighter,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Banner illustration
            Container(
              width: 142,
              height: 142,
              alignment: Alignment.bottomLeft,
              child: Image.asset(
                AppAssets.signCommunication,
                width: 142,
                height: 142,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 142,
                    height: 142,
                    color: Colors.white24,
                    child: const Icon(
                      Icons.accessibility_new_rounded,
                      size: 64,
                      color: AppColors.accent2Dark,
                    ),
                  );
                },
              ),
            ),
            // Banner text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 18, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign to translate to\nFTL',
                      style: AppTextStyles.h3(color: AppColors.textPrimary).copyWith(
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture using the camera',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required Color bgColor,
    required Color circleBgColor,
    required String iconAsset,
    required double iconSize,
    required String title,
    required String subtitle,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 116,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Icon Badge (64x64)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: circleBgColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconAsset,
                width: iconSize,
                height: iconSize,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),

            const SizedBox(width: 16),

            // Text column
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3(color: titleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Chevron Arrow Next
            SvgPicture.asset(
              AppAssets.chevronNext,
              width: 20,
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
