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
import '../models/translation_history.dart';
import '../features/debug/metrics_sheet.dart';

/// Figma Node 32:471 — Speech Translation, wired to the live engine.
class SpeechTranslationScreen extends StatefulWidget {
  const SpeechTranslationScreen({super.key});

  @override
  State<SpeechTranslationScreen> createState() => _SpeechTranslationScreenState();
}

class _SpeechTranslationScreenState extends State<SpeechTranslationScreen>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  bool _micDenied = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _sub;
  final _typedCtrl = TextEditingController();

  String _interim = '';
  bool _transcribing = false;
  String _streaming = '';
  String? _error;
  final List<_SpeechResult> _results = [];

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
    _sub = senyas.events.listen(_onEvent);
  }

  bool get _showFallback => senyas.isSimulated || _micDenied;

  void _onEvent(EngineEvent e) {
    if (!mounted) return;
    setState(() {
      switch (e.type) {
        case EngineEvent.speechState:
          final s = e.data['state'] as String;
          _isListening = s == 'listening';
          _transcribing = s == 'transcribing';
          _micDenied = s == 'mic-denied' || s == 'fallback';
          if (_isListening) _error = null;
          break;
        case EngineEvent.speechInterim:
          _interim = e.data['text'] as String;
          break;
        case EngineEvent.speechToken:
          _streaming += e.data['ch'] as String;
          break;
        case EngineEvent.error:
          _error = '${e.data['message']}${e.data['action'] != null ? ' — ${e.data['action']}' : ''}';
          break;
        case EngineEvent.speechResult:
          _interim = '';
          _streaming = '';
          final source = e.data['source'] as String?;
          final r = _SpeechResult(
            raw: e.data['raw'] as String,
            simplified: e.data['simplified'] as String,
            lang: e.data['lang'] as String,
            label: [
              switch (source) {
                'gemma' => 'simplified by ${e.data['model'] ?? 'Gemma'}',
                'rawTranscript' => 'raw transcript (not simplified)',
                _ => 'demo rule engine',
              },
              if (e.data['recognizer'] != null) 'via ${e.data['recognizer']}',
              if (e.data['warning'] != null) '⚠ ${e.data['warning']}',
            ].join(' · '),
          );
          _results.insert(0, r);
          HistoryStore.add(TranslationType.speech, r.simplified);
          break;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _typedCtrl.dispose();
    _pulseController.dispose();
    senyas.cancelSpeech();
    super.dispose();
  }

  void _toggleListening() {
    if (_transcribing) return; // ignore presses while processing
    if (_isListening) {
      senyas.stopSpeech();
    } else {
      senyas.startSpeech();
    }
  }

  void _submitTyped() {
    final t = _typedCtrl.text.trim();
    if (t.isEmpty) return;
    _typedCtrl.clear();
    senyas.submitTyped(t);
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
              title: 'Speech Translation',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Concentric mic
                    GestureDetector(
                      onTap: _toggleListening,
                      child: SizedBox(
                        height: 170, width: 170,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            final scale =
                                _isListening ? _pulseAnimation.value : 1.0;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 137 * scale, height: 137 * scale,
                                  decoration: const BoxDecoration(
                                    color: AppColors.micRippleOuter,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 113 * scale, height: 113 * scale,
                                  decoration: const BoxDecoration(
                                    color: AppColors.micRippleMiddle,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 94, height: 94,
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
                                    width: 44, height: 44,
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

                    Text(
                      _isListening
                          ? 'Listening… tap to stop'
                          : _transcribing
                              ? 'Transcribing…'
                              : _micDenied
                                  ? 'Mic unavailable — type below'
                                  : 'Tap to Speak',
                      style: AppTextStyles.h3(
                        color: _isListening
                            ? AppColors.accent2
                            : _micDenied
                                ? Colors.redAccent
                                : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Whisper language token: tl (Filipino/Taglish) or en
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'tl', label: Text('Filipino')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {senyas.speechLang},
                      onSelectionChanged: _isListening || _transcribing
                          ? null
                          : (s) => setState(() => senyas.speechLang = s.first),
                    ),

                    const SizedBox(height: 12),

                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: AppTextStyles.label(
                                    color: Colors.red.shade800)),
                          ),
                        ]),
                      ),

                    // Streaming simplification
                    if (_streaming.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildResultCard(
                            text: _streaming, tag: 'Gemma simplifying…', raw: '…'),
                      ),

                    // Interim transcript
                    SizedBox(
                      height: 22,
                      child: Text(
                        _interim,
                        style: AppTextStyles.body(color: AppColors.accent2)
                            .copyWith(fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Typed fallback
                    if (_showFallback)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _typedCtrl,
                          onSubmitted: (_) => _submitTyped(),
                          decoration: InputDecoration(
                            hintText:
                                'Type what was spoken, press Enter',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.accent2Soft, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.accent2Soft, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send,
                                  color: AppColors.accent2),
                              onPressed: _submitTyped,
                            ),
                          ),
                        ),
                      ),

                    // Live result cards
                    ..._results.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildResultCard(
                            text: r.simplified,
                            tag: '→ ${r.lang} · ${r.label}',
                            raw: r.raw,
                          ),
                        )),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => showMetricsSheet(context),
                        icon: const Icon(Icons.speed, size: 16),
                        label: const Text('Diagnostics'),
                      ),
                    ),
                    const SizedBox(height: 6),
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
            const SenyasHomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String text,
    required String tag,
    required String raw,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.accent2Soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: AppTextStyles.h3(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(tag, style: AppTextStyles.body(color: AppColors.textSecondary)),
          Text(
            'heard: "$raw"',
            style: AppTextStyles.label(color: AppColors.textSecondary)
                .copyWith(fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SpeechResult {
  final String raw, simplified, lang, label;
  const _SpeechResult(
      {required this.raw,
      required this.simplified,
      required this.lang,
      required this.label});
}
