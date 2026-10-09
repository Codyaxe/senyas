import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography definitions based on the Figma specs (Inter family).
class AppTextStyles {
  // H1: Bold 28px, LineHeight 36
  static TextStyle h1({Color color = AppColors.textPrimary}) {
    return GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 36 / 28,
      color: color,
    );
  }

  // H2: Semi Bold 22px, LineHeight 28
  static TextStyle h2({Color color = AppColors.textPrimary}) {
    return GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 28 / 22,
      color: color,
    );
  }

  // H3: Semi Bold 18px, LineHeight 24
  static TextStyle h3({Color color = AppColors.textPrimary}) {
    return GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 24 / 18,
      color: color,
    );
  }

  // Body: Regular 14px, LineHeight 20
  static TextStyle body({Color color = AppColors.textSecondary}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      color: color,
    );
  }

  // Caption: Regular 14px, LineHeight 20
  static TextStyle caption({Color color = AppColors.textSecondary}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      color: color,
    );
  }

  // Label: Semi Bold 12px, LineHeight 16
  static TextStyle label({Color color = AppColors.textMuted}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 16 / 12,
      color: color,
    );
  }

  // Medium text: Medium 12px, LineHeight 16
  static TextStyle medium12({Color color = AppColors.accent2Dark}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 16 / 12,
      color: color,
    );
  }

  // Status Bar Time: Semi Bold 14px
  static TextStyle statusTime({Color color = AppColors.primary}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  // Subtitle/Body Bold: Semi Bold 16px
  static TextStyle semiBold16({Color color = AppColors.textPrimary}) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }
}
