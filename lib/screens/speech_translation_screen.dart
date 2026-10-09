import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../widgets/senyas_status_bar.dart';
import '../widgets/senyas_header.dart';
import '../widgets/senyas_home_indicator.dart';

/// Implementation of Figma Node 32:471 - Speech Translation Screen
class SpeechTranslationScreen extends StatefulWidget {
  const SpeechTranslationScreen({super.key});

  @override
  State<SpeechTranslationScreen> createState() => _SpeechTranslationScreenState();
}

class _SpeechTranslationScreenState extends State<SpeechTranslationScreen>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
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
              title: 'Speech Translation',
              onBack: () => Navigator.of(context).pop(),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Concentric Animated Microphone Area (170px height)
                    GestureDetector(
                      onTap: _toggleListening,
                      child: SizedBox(
                        height: 170,
                        width: 170,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            final scale = _isListening ? _pulseAnimation.value : 1.0;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer Ring (137x137)
                                Container(
                                  width: 137 * scale,
                                  height: 137 * scale,
                                  decoration: const BoxDecoration(
                                    color: AppColors.micRippleOuter,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                // Middle Ring (113x113)
                                Container(
                                  width: 113 * scale,
                                  height: 113 * scale,
                                  decoration: const BoxDecoration(
                                    color: AppColors.micRippleMiddle,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                // Center Dark Circle (94x94) with Mic Icon
                                Container(
                                  width: 94,
                                  height: 94,
                                  decoration: BoxDecoration(
                                    color: _isListening
                                        ? AppColors.primary
                                        : AppColors.accent2Dark,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1F000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: SvgPicture.asset(
                                    AppAssets.micLarge,
                                    width: 44,
                                    height: 44,
                                    colorFilter: const ColorFilter.mode(
                                        Colors.white, BlendMode.srcIn),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Label: Tap to Speak / Listening...
                    Text(
                      _isListening ? 'Listening...' : 'Tap to Speak',
                      style: AppTextStyles.h3(
                        color: _isListening ? AppColors.accent2 : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Speak in Filipino or English',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: 28),

                    // Translation Card 1: English
                    _buildResultCard(
                      text: 'Hello, how are you today?',
                      tag: '→ English',
                      hasChevron: false,
                    ),

                    const SizedBox(height: 14),

                    // Translation Card 2: Filipino
                    _buildResultCard(
                      text: 'Ano ginagawa mo?',
                      tag: '→ Filipino',
                      hasChevron: true,
                    ),

                    const SizedBox(height: 20),

                    // Down Chevron Scroll Indicator "∨"
                    const Center(
                      child: Text(
                        '∨',
                        style: TextStyle(
                          fontSize: 22,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
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

  Widget _buildResultCard({
    required String text,
    required String tag,
    required bool hasChevron,
  }) {
    return Container(
      width: double.infinity,
      height: 116,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.accent2Soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: AppTextStyles.h3(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  tag,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (hasChevron)
            SvgPicture.asset(
              AppAssets.chevronNext,
              width: 20,
              height: 20,
            ),
        ],
      ),
    );
  }
}
