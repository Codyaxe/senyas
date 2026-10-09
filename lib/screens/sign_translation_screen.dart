import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../widgets/senyas_status_bar.dart';
import '../widgets/senyas_header.dart';
import '../widgets/senyas_home_indicator.dart';

/// Implementation of Figma Node 37:1111 - Sign Translation Screen
class SignTranslationScreen extends StatefulWidget {
  const SignTranslationScreen({super.key});

  @override
  State<SignTranslationScreen> createState() => _SignTranslationScreenState();
}

class _SignTranslationScreenState extends State<SignTranslationScreen>
    with SingleTickerProviderStateMixin {
  bool _isDetecting = true;
  bool _isPlayingSpeech = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
    });
  }

  void _playTTS() {
    setState(() => _isPlayingSpeech = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Playing audio: "Kamusta ka?"'),
        duration: Duration(seconds: 1),
        backgroundColor: AppColors.accentGreenDark,
      ),
    );
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isPlayingSpeech = false);
      }
    });
  }

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

            // Header with Back button
            SenyasSubHeader(
              title: 'Sign Translation',
              onBack: () => Navigator.of(context).pop(),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Camera Viewport Viewfinder (342x326)
                    Container(
                      height: 326,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A5D62),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Live Hand Landmarks / Camera Preview Simulation
                          Center(
                            child: Opacity(
                              opacity: _isDetecting ? 0.85 : 0.4,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sign_language_rounded,
                                    size: 110,
                                    color: _isDetecting
                                        ? AppColors.accent
                                        : Colors.white54,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isDetecting
                                        ? 'Hand Tracking Active'
                                        : 'Detection Paused',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Framing Reticles / Viewfinder Corners
                          Positioned(
                            top: 16,
                            left: 16,
                            child: _buildCorner(isTop: true, isLeft: true),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: _buildCorner(isTop: true, isLeft: false),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: _buildCorner(isTop: false, isLeft: true),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: _buildCorner(isTop: false, isLeft: false),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // "Detecting Sign..." Status Row
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        // Pulsing Green Indicator Ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final alpha = _isDetecting
                                ? (0.4 + 0.6 * _pulseController.value)
                                : 0.2;
                            return Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentGreenDark.withValues(alpha: alpha),
                                  width: 2.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentGreenDark.withValues(alpha: alpha),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isDetecting ? 'Detecting Sign...' : 'Detection Stopped',
                          style: AppTextStyles.body(color: AppColors.textSecondary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Recognized Sign Card (Height 116, Mint Bg)
                    Container(
                      height: 116,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreenSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          // Translated Text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Kamusta ka?',
                                  style: AppTextStyles.h3(color: AppColors.textPrimary)
                                      .copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '(How are you?)',
                                  style: AppTextStyles.body(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),

                          // Speaker Button (48x48)
                          InkWell(
                            onTap: _playTTS,
                            borderRadius: BorderRadius.circular(24),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _isPlayingSpeech
                                    ? AppColors.primary
                                    : AppColors.accentGreenDark,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                AppAssets.speaker,
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Big Stop / Resume Circular Action Button (60x60)
                    Center(
                      child: GestureDetector(
                        onTap: _toggleDetection,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _isDetecting
                                ? AppColors.accentGreenDark
                                : AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            _isDetecting ? AppAssets.stop : AppAssets.cameraFilled,
                            width: 26,
                            height: 26,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
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

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: AppColors.accent, width: 2.5)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: AppColors.accent, width: 2.5)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: AppColors.accent, width: 2.5)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: AppColors.accent, width: 2.5)
              : BorderSide.none,
        ),
      ),
    );
  }
}
