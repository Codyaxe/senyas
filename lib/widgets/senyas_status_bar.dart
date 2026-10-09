import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';

/// Implementation of Figma Node 32:412 - Status Bar
/// A pixel-accurate iOS status bar component with responsive layout and customizable tint.
class SenyasStatusBar extends StatelessWidget {
  final String time;
  final bool isDark;
  final Color? textColor;

  const SenyasStatusBar({
    super.key,
    this.time = '9:41',
    this.isDark = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // When isDark is false, we use the primary green (#084131) as seen in Node 32:412
    // When isDark is true, we use the dark neutral (#30343B)
    final resolvedColor = textColor ?? (isDark ? AppColors.textDark : AppColors.primary);
    final signalAsset = isDark ? AppAssets.iosSignalDark : AppAssets.iosSignalGreen;
    final wifiAsset = isDark ? AppAssets.iosWifiDark : AppAssets.iosWifiGreen;
    final batteryAsset = isDark ? AppAssets.iosBatteryDark : AppAssets.iosBatteryGreen;

    return Container(
      height: 54,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time
          Text(
            time,
            style: AppTextStyles.statusTime(color: resolvedColor),
          ),
          // Device status indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cellular Signal
              SvgPicture.asset(
                signalAsset,
                width: 17,
                height: 17,
                colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 5),
              // Wi-Fi Signal
              SvgPicture.asset(
                wifiAsset,
                width: 17,
                height: 17,
                colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 5),
              // Battery
              SvgPicture.asset(
                batteryAsset,
                width: 25,
                height: 17,
                colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
