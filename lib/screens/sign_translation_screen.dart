import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../features/sign/demo_mode.dart';
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

  /// Last recognizer prediction: top-5 glosses + confidence for correction & diagnostics.
  List<Map<String, dynamic>> _lastTop = const [];
  bool _lastCommitted = true;
  int? _lastMs;
  Map<String, dynamic>? _lastMeta;
  bool _showDiagnostics = true;

  bool _isManualRecording = false;

  static const _demoGestures = <String, String>{
    'WAVE': '👋',
    'B_HAND': '🫱',
    'ILY': '🤟',
    'INDEX_POINT': '☝️',
    'S_FIST': '✊',
    'NO_PINCH': '🤏',
    'OPEN_5': '✋',
    'V_HAND': '✌️',
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
            _lastTop = const []; // committed — clear correction row
          }
          break;
        case EngineEvent.prediction:
          _lastTop = (e.data['top'] as List)
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList();
          _lastCommitted = e.data['committed'] as bool;
          _lastMs = (e.data['ms'] as num?)?.round();
          _lastMeta = e.data['meta'] is Map
              ? Map<String, dynamic>.from(e.data['meta'] as Map)
              : null;
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
          _sourceLabel = _labelFor(e.data['source'] as String?, e.data['warning'] as String?,
              e.data['model'] as String?);
          _error = null;
          HistoryStore.add(TranslationType.sign, _recognized);
          break;
        case EngineEvent.error:
          _error = '${e.data['message']}${e.data['action'] != null ? ' — ${e.data['action']}' : ''}';
          break;
      }
    });
  }

  static String _labelFor(String? source, String? warning, String? model) {
    switch (source) {
      case 'gemma':
        return model ?? 'Gemma';
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

                    // Recognition diagnostics card & candidate correction
                    _buildDiagnosticCard(),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        SenyasSettings.recognitionScope,
                        style: AppTextStyles.label(
                            color: AppColors.textSecondary),
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
                    ValueListenableBuilder<bool>(
                      valueListenable: SenyasSettings.demoMode,
                      builder: (_, demo, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: GlossVocab.all
                                .map((g) => ActionChip(
                                      label: Text(
                                          demo && g.liveHint != null
                                              ? '${g.liveHint!.split(' ').first} ${g.id}'
                                              : g.id,
                                          style: const TextStyle(fontSize: 12)),
                                      tooltip: '${g.fil} — ${g.en}',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _manual.length >= 6
                                          ? null
                                          : () => setState(
                                              () => _manual.add(g.id)),
                                    ))
                                .toList(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              demo
                                  ? 'Demo mode: the camera also accepts the 7 static '
                                      'handshapes marked above — a heuristic demo aid, '
                                      'not part of the FSL-105 recognizer.'
                                  : 'Manual input — taps bypass the camera recognizer.',
                              style: AppTextStyles.label(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
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

                    // Controls: Camera toggle & Hold-to-Sign button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _toggleDetection,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: _isDetecting
                                  ? AppColors.cardBackground
                                  : AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isDetecting ? AppColors.border : Colors.transparent,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1F000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              _isDetecting
                                  ? AppAssets.stop
                                  : AppAssets.cameraFilled,
                              width: 20, height: 20,
                              colorFilter: ColorFilter.mode(
                                  _isDetecting ? AppColors.textSecondary : Colors.white,
                                  BlendMode.srcIn),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTapDown: (_) {
                            setState(() => _isManualRecording = true);
                            senyas.startManualRecord();
                          },
                          onTapUp: (_) {
                            setState(() => _isManualRecording = false);
                            senyas.stopManualRecord();
                          },
                          onTapCancel: () {
                            if (_isManualRecording) {
                              setState(() => _isManualRecording = false);
                              senyas.stopManualRecord();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: _isManualRecording
                                  ? const Color(0xFFE5484D)
                                  : AppColors.accentGreenDark,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isManualRecording
                                          ? const Color(0xFFE5484D)
                                          : AppColors.accentGreenDark)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isManualRecording ? Icons.fiber_manual_record : Icons.touch_app,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isManualRecording ? 'Recording Sign…' : 'Hold to Sign',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildDiagnosticCard() {
    final meta = _lastMeta;
    final top = _lastTop;
    final reason = meta?['reason'] as String?;
    final isError = reason == 'error';
    final isTooShort = reason == 'too_short';
    final hasData = top.isNotEmpty || isTooShort || isError;
    if (!hasData) return const SizedBox.shrink();

    final best = top.isNotEmpty ? top.first : null;
    final bestProb = best != null ? (best['prob'] as num).toDouble() : 0.0;
    final bestPct = (bestProb * 100).round();
    final endReason = meta?['endReason'] as String? ?? 'unknown';
    final frames = (meta?['frames'] as num?)?.round() ?? 0;

    final topGlosses =
        top.map((t) => (t['gloss'] as String).toUpperCase()).toList();
    final hasChinOverlap = topGlosses.any((g) =>
        g.contains('ORANGE') || g.contains('FISH') || g.contains('THANK'));

    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    IconData badgeIcon;

    if (isError) {
      badgeBg = const Color(0xFFFDE8E8);
      badgeText = const Color(0xFF9B1C1C);
      badgeLabel = 'Inference Error';
      badgeIcon = Icons.error_outline;
    } else if (isTooShort) {
      badgeBg = const Color(0xFFFFF3CD);
      badgeText = const Color(0xFF856404);
      badgeLabel = 'Sign Too Short (< 0.6s)';
      badgeIcon = Icons.timer_outlined;
    } else if (!_lastCommitted) {
      badgeBg = const Color(0xFFFDE8E8);
      badgeText = const Color(0xFF9B1C1C);
      badgeLabel = 'Uncertain Match ($bestPct% < 45% threshold)';
      badgeIcon = Icons.warning_amber_rounded;
    } else {
      badgeBg = const Color(0xFFDEF7EC);
      badgeText = const Color(0xFF03543F);
      badgeLabel = 'Recognized ($bestPct% confidence)';
      badgeIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !_lastCommitted || isTooShort || isError
              ? const Color(0xFFF3C7C7)
              : const Color(0xFFD1E7DD),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeText),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _showDiagnostics = !_showDiagnostics),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showDiagnostics ? 'Hide details' : 'Show details',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.accent2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _showDiagnostics
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: AppColors.accent2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showDiagnostics) ...[
            const SizedBox(height: 10),
            if (isError)
              Text(
                '• Cause: ${meta?['detail'] ?? 'Model failed during classification'}\n'
                '• Tip: If onnxruntime-web fails on this browser, enable Demo Mode in Settings for rock-solid heuristic recognition.',
                style: GoogleFonts.inter(
                    fontSize: 12, height: 1.4, color: const Color(0xFF9B1C1C)),
              )
            else if (isTooShort)
              Text(
                '• Cause: Sign lasted only $frames frames (~${(frames / 30).toStringAsFixed(1)}s).\n'
                '• Solution: FSL-105 requires at least 18 frames (~0.6s) to capture hand trajectory. Please sign at normal speed.',
                style: GoogleFonts.inter(
                    fontSize: 12, height: 1.4, color: const Color(0xFF4B5563)),
              )
            else if (!_lastCommitted)
              Text(
                '• Cause: Top pick (${best?['gloss']}) scored $bestPct%, below the 45% threshold to auto-commit.\n'
                '• Action: Tap your intended sign below to confirm it:',
                style: GoogleFonts.inter(
                    fontSize: 12, height: 1.4, color: const Color(0xFF4B5563)),
              )
            else
              Text(
                '• Cause: Model matched with confident probability ($bestPct%).\n'
                '• Telemetry: $frames frames analyzed in ${_lastMs ?? 0}ms.',
                style: GoogleFonts.inter(
                    fontSize: 12, height: 1.4, color: const Color(0xFF4B5563)),
              ),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Model Predictions (Top ${top.length}):',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              ...top.take(4).map((t) {
                final gloss = t['gloss'] as String;
                final prob = (t['prob'] as num).toDouble();
                final pct = (prob * 100).round();
                final cat = t['cat'] as String? ?? '';
                final isTopPick = t == top.first;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => senyas.commitGloss(gloss),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTopPick
                            ? const Color(0xFFF9FAFB)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isTopPick
                              ? const Color(0xFFE5E7EB)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      gloss,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isTopPick
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (cat.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '· $cat',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: prob.clamp(0.0, 1.0),
                                    minHeight: 5,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      prob >= 0.45
                                          ? AppColors.accentGreenDark
                                          : (prob >= 0.25
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF9CA3AF)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$pct%',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isTopPick
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () => senyas.commitGloss(gloss),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.accentGreenSoft,
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text('Select',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (hasChinOverlap) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: Color(0xFF15803D)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '💡 Chin Overlap Alert: THANK YOU, ORANGE, and FISH all have landmarks around the chin.\n'
                        '👉 To sign THANK YOU: Touch flat fingers to chin/lips, push outward forward away from face, then pause or drop hand.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          height: 1.35,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Trigger: $endReason · Frames: $frames · Model: ONNX WASM',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
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
