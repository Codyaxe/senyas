import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../models/translation_history.dart';
import '../engine/engine.dart';
import '../widgets/senyas_header.dart';

/// Implementation of Figma Node 32:288 - History Page
class HistoryScreen extends StatefulWidget {
  final VoidCallback? onSettingsTap;

  const HistoryScreen({
    super.key,
    this.onSettingsTap,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all translation history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              HistoryStore.items.value = [];
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        SenyasHeader(
          title: 'History',
          onEllipsisTap: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                        title: const Text('Clear History'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _clearHistory();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.refresh),
                        title: const Text('Restore Sample Data'),
                        onTap: () {
                          HistoryStore.items.value =
                              List.of(defaultHistoryItems);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // History items list
        Expanded(
          child: ValueListenableBuilder<List<TranslationHistoryItem>>(
            valueListenable: HistoryStore.items,
            builder: (context, items, _) => items.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildHistoryCard(item);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            AppAssets.historyInactive,
            width: 56,
            height: 56,
            colorFilter: const ColorFilter.mode(AppColors.textMuted, BlendMode.srcIn),
          ),
          const SizedBox(height: 16),
          Text(
            'No translation history yet',
            style: AppTextStyles.h3(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TranslationHistoryItem item) {
    final isSign = item.type == TranslationType.sign;
    final circleBgColor = isSign ? AppColors.accentGreenDark : AppColors.accent2Light;
    final iconAsset = isSign ? AppAssets.waveWhite : AppAssets.spectrumWhite;
    final typeColor = isSign ? AppColors.primary : AppColors.accent2Dark;

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Icon badge (60x60)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: circleBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              iconAsset,
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),

          const SizedBox(width: 14),

          // Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.typeLabel,
                  style: AppTextStyles.label(color: typeColor),
                ),
                const SizedBox(height: 6),
                Text(
                  item.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3(color: AppColors.textPrimary).copyWith(
                    fontSize: 16,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Timestamp pinned to bottom right
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item.timestamp,
                style: AppTextStyles.label(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
