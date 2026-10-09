import 'package:flutter/material.dart';

/// Design tokens and colors extracted from Figma "Senyas" design.
class AppColors {
  // Primary
  static const Color primary = Color(0xFF084131); // Forest green

  // Accent Mint / Teal family
  static const Color accent = Color(0xFF32D8B4); // Main mint accent
  static const Color accentMint = Color(0xFF32D8B4);
  static const Color accentGreenDark = Color(0xFF50B09B); // Camera & icon circles
  static const Color accentGreenSoft = Color(0xFFB4F5E7); // Speech-Text pill bg

  // Accent Blue family
  static const Color accent2 = Color(0xFF318DEF); // Brand blue for tagline
  static const Color accent2Dark = Color(0xFF143150); // Deep navy for speech titles
  static const Color accent2Medium = Color(0xFF4092E9); // Speech card tint
  static const Color accent2Light = Color(0xFF79A8DB); // Mic & wave circle
  static const Color accent2Lighter = Color(0xFFCBDFF3); // Feature card banner bg
  static const Color accent2Soft = Color(0xFFC5E0FD); // FSL & offline pill bg

  // Cards and Gradients
  static const Color signCardBg = Color(0x5232D8B4); // rgba(50, 216, 180, 0.32)
  static const Color speechCardBg = Color(0x6B4092E9); // rgba(64, 146, 233, 0.42)
  static const Color micRippleOuter = Color(0xFFE2F0FD);
  static const Color micRippleMiddle = Color(0xFFBADCF9);

  // Backgrounds & Neutrals
  static const Color background = Color(0xFFFFFFFF);
  static const Color introBackground = Color(0xFFF4F8F9);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color navItemActiveBg = Color(0xFFF4F5F6);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E4E7);
  static const Color divider = Color(0xFFCDE3EB);

  // Typography Neutrals
  static const Color textPrimary = Color(0xFF000000);
  static const Color textDark = Color(0xFF30343B);
  static const Color textSecondary = Color(0xFF697174);
  static const Color textMuted = Color(0xFFB2B3B3);
  static const Color textWhite = Color(0xFFF4F8F9);

  // Interactive UI
  static const Color switchTrackInactive = Color(0xFF767F8D);
  static const Color switchTrackActive = Color(0xFF32D8B4);
  static const Color homeIndicator = Color(0xFF30343B);
}
