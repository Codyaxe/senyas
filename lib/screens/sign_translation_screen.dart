import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_assets.dart';
import '../constants/app_text_styles.dart';
import '../widgets/senyas_status_bar.dart';
import '../widgets/senyas_header.dart';
import '../widgets/senyas_home_indicator.dart';
import '../engine/engine.dart';
import '../engine/camera_view_stub.dart'
    if (dart.library.js_interop) '../engine/camera_view_web.dart';
import '../models/translation_history.dart';
import '../features/sign/gloss_vocab.dart';
import '../features/inference/pipeline.dart';
import '../features/debug/metrics_sheet.dart';

/// Figma Node 37:1111 — Sign Translation, wired to the live engine.
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
  StreamSubscription? _sub;

  String _statusLabel = 'Starting camera…';
  List<String> _phrase = const [];
  String _recognized = '';
  String _recognizedSub = 'Sign, or tap glosses below';
  String? _sourceLabel; // which engine produced the text
  String? _error;
  final List<String> _manual = []; // tap-to-select gloss fallback

  static const _demoGestures = <String, String>{
    'WAVE': '👋', 'OPEN_PALM': '✋', 'THUMBS_UP': '👍',
    'THUMBS_DOWN': '👎', 'INDEX_POINT': '☝️', 'PEACE': '✌️', 'FIST': '✊',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _sub = senyas.events.listen(_onEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => senyas.enterSignMode());
  }

  void _onEvent(EngineEvent e) {
    if (!mounted) return;
    setState(() {
      switch (e.type) {
        case EngineEvent.status:
          _statusLabel = e.data['label'] as String? ??
              (e.data['status'] == 'no-hand' ? 'No hand detected' : 'Tracking');
          break;
        case EngineEvent.gloss:
          _phrase = List<String>.from(e.data['phrase'] as List);
          if (_phrase.isEmpty) {
            _recognized = ''; // phrase flushed — rewrite streaming next
          } else {
            _recognizedSub = '';
          }
          break;
        case EngineEvent.token:
          if (_sourceLabel != null) {
            _recognized = ''; // new translation streaming in
            _sourceLabel = null;
          }
          _recognized += e.data['ch'] as String;
          break;
        case EngineEvent.signResult:
          _recognized = e.data['sentence'] as String;
          final seq = (e.data['glosses'] as List).join(' + ');
          _recognizedSub = '($seq)';
          _sourceLabel = _labelFor(e.data['source'] as String?, e.data['warning'] as String?);
          _error = null;
          HistoryStore.add(TranslationType.sign, _recognized);
          break;
        case EngineEvent.error:
          _error = '${e.data['message']}${e.data['action'] != null ? ' — ${e.data['action']}' : ''}';
          break;
      }
    });
  }

  static String _labelFor(String? source, String? warning) {
    switch (source) {
      case 'gemma':
        return 'Gemma (on-device)';
      case 'ruleFallback':
        return 'Rule-based fallback${warning != null ? ' · $warning' : ''}';
      default:
        return 'Demo rule engine (no on-device model)';
    }
  }

  void _translateManual() {
    if (_manual.isEmpty) return;
    setState(() {
      _recognized = '';
      _recognizedSub = '(${_manual.join(' + ')})';
      _sourceLabel = null;
    });
    senyas.translateGlosses(List.of(_manual));
    setState(_manual.clear);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    senyas.exitSignMode();
    super.dispose();
  }

  void _toggleDetection() {
    setState(() => _isDetecting = !_isDetecting);
    senyas.setDetecting(_isDetecting);
    if (_isDetecting) senyas.flushPhrase();
  }

  void _playTTS() {
    if (_recognized.isEmpty) return;
    setState(() => _isPlayingSpeech = true);
    senyas.speak(_recognized);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isPlayingSpeech = false);
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
            const SenyasStatusBar(isDark: true),
            SenyasSubHeader(
              title: 'Sign Translation',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Camera viewport — real preview + landmark overlay
                    Container(
                      height: 300,
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
                        fit: StackFit.expand,
                        children: [
                          buildCameraView(senyas.cameraViewType,
                              detecting: _isDetecting),
                          Positioned(
                            top: 16, left: 16,
                            child: _buildCorner(isTop: true, isLeft: true),
                          ),
                          Positioned(
                            top: 16, right: 16,
                            child: _buildCorner(isTop: true, isLeft: false),
                          ),
                          Positioned(
                            bottom: 16, left: 16,
                            child: _buildCorner(isTop: false, isLeft: true),
                          ),
                          Positioned(
                            bottom: 16, right: 16,
                            child: _buildCorner(isTop: false, isLeft: false),
                          ),
                          Positioned(
                            bottom: 14, left: 0, right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0x66000000),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isDetecting ? _statusLabel : 'Detection Paused',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Status row
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final alpha = _isDetecting
                                ? (0.4 + 0.6 * _pulseController.value)
                                : 0.2;
                            return Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentGreenDark
                                      .withValues(alpha: alpha),
                                  width: 2.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 5, height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentGreenDark
                                      .withValues(alpha: alpha),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isDetecting
                                ? (_phrase.isNotEmpty
                                    ? 'Recognized: ${_phrase.join(' · ')}'
                                    : 'Detecting Sign...')
                                : 'Detection Stopped',
                            style: AppTextStyles.body(
                                color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Committed gloss chips
                    if (_phrase.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            ..._phrase.map((g) => Chip(
                                  label: Text(g),
                                  backgroundColor: AppColors.accentGreenDark,
                                  labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  visualDensity: VisualDensity.compact,
                                )),
                            Text('pause to translate',
                                style: AppTextStyles.label(
                                        color: AppColors.textSecondary)
                                    .copyWith(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Model status / errors (visual only — deaf-first)
                    ValueListenableBuilder<RouterState>(
                      valueListenable: pipeline.state,
                      builder: (_, s, __) => s == RouterState.loadingGemma ||
                              s == RouterState.generating
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(s == RouterState.loadingGemma
                                    ? 'Loading Gemma on-device…'
                                    : 'Translating…',
                                    style: AppTextStyles.label(color: AppColors.textSecondary)),
                              ]),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: AppTextStyles.label(color: Colors.red.shade800)),
                          ),
                        ]),
                      ),

                    // Recognized sign card
                    Container(
                      constraints: const BoxConstraints(minHeight: 116),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreenSoft,
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
                                  _recognized.isEmpty ? '—' : _recognized,
                                  style: AppTextStyles.h3(
                                          color: AppColors.textPrimary)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _recognizedSub,
                                  style: AppTextStyles.body(
                                      color: AppColors.textSecondary),
                                ),
                                if (_sourceLabel != null)
                                  Text(
                                    _sourceLabel!,
                                    style: AppTextStyles.label(
                                            color: AppColors.textSecondary)
                                        .copyWith(fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _playTTS,
                            borderRadius: BorderRadius.circular(24),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48, height: 48,
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
                                width: 24, height: 24,
                                colorFilter: const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Simulator: gesture injection buttons (desktop / no camera)
                    if (senyas.isSimulated)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Wrap(
                          spacing: 8, runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: _demoGestures.entries
                              .map((e) => ActionChip(
                                    label: Text('${e.value} ${e.key}'),
                                    onPressed: () =>
                                        senyas.injectGesture(e.key),
                                  ))
                              .toList(),
                        ),
                      ),

                    // Tap-to-select gloss fallback (fixed 21-gloss vocabulary)
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: Text(
                          _manual.isEmpty
                              ? 'Tap glosses to build a phrase'
                              : 'Phrase: ${_manual.join(' ')}',
                          style: AppTextStyles.label(color: AppColors.textPrimary),
                        ),
                      ),
                      if (_manual.isNotEmpty)
                        TextButton(
                            onPressed: () => setState(_manual.clear),
                            child: const Text('Clear')),
                      FilledButton(
                        onPressed: _manual.isEmpty ? null : _translateManual,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accentGreenDark),
                        child: const Text('Isalin'),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: GlossVocab.all
                          .map((g) => ActionChip(
                                label: Text(
                                    g.liveHint != null
                                        ? '${g.liveHint!.split(' ').first} ${g.id}'
                                        : g.id,
                                    style: const TextStyle(fontSize: 12)),
                                tooltip: '${g.fil} — ${g.en}',
                                visualDensity: VisualDensity.compact,
                                onPressed: _manual.length >= 6
                                    ? null
                                    : () => setState(() => _manual.add(g.id)),
                              ))
                          .toList(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Live camera recognizes only the 7 glosses marked with a handshape. '
                        'This is a fixed demo vocabulary, not full FSL recognition.',
                        style: AppTextStyles.label(color: AppColors.textSecondary),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => showMetricsSheet(context),
                        icon: const Icon(Icons.speed, size: 16),
                        label: const Text('Diagnostics'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Stop / Resume button
                    Center(
                      child: GestureDetector(
                        onTap: _toggleDetection,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60, height: 60,
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
                            _isDetecting
                                ? AppAssets.stop
                                : AppAssets.cameraFilled,
                            width: 26, height: 26,
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
