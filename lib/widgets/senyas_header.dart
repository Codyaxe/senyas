import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';

/// Main Header used in Home, History, and Profile pages (Height: 89)
class SenyasHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onEllipsisTap;

  const SenyasHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onEllipsisTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 89,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title + Subtitle
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h1(),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.label(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          // 3-dots action button
          InkWell(
            onTap: onEllipsisTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: SvgPicture.asset(
                AppAssets.ellipsis,
                width: 20,
                height: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub Header used in detail screens like Settings, Speech Translation, Sign Translation
class SenyasSubHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const SenyasSubHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 89,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          InkWell(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.arrowBack,
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h2(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
