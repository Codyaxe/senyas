import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable iOS Home Indicator Area (Height: 34, Pill: 120x4)
class SenyasHomeIndicator extends StatelessWidget {
  const SenyasHomeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: double.infinity,
      alignment: Alignment.center,
      child: Container(
        width: 120,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.homeIndicator,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}
