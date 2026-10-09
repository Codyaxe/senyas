import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../features/inference/pipeline.dart';
import 'engine_base.dart';
import 'engine_events.dart';

/// Desktop simulator: no camera/mic/model runtime. Gestures are injected via
/// buttons; translations come from the router's labeled rule fallback.
class SimEngine extends SenyasEngineApi {
  @override
  bool get isSimulated => true;

  final List<String> _phrase = [];
  Timer? _flushTimer;
  final _tts = FlutterTts();

  static const _toGloss = {
    'WAVE': 'KAMUSTA',
    'B_HAND': 'SALAMAT',
    'ILY': 'MAHAL_KITA',
    'INDEX_POINT': 'IKAW',
    'S_FIST': 'OO',
    'NO_PINCH': 'HINDI',
    'OPEN_5': 'SANDALI',
    'V_HAND': 'DALAWA',
    'OPEN_PALM': 'SANDALI',
    'PEACE': 'SALAMAT',
    'FIST': 'OO',
    'THUMBS_UP': 'MAGANDA',
    'THUMBS_DOWN': 'HINDI',
  };

  @override
  Future<void> boot() => pipeline.boot();

  @override
  Future<void> enterSignMode() async {
    await boot();
    emit(EngineEvent.status, {'status': 'sim', 'label': 'Simulated camera'});
  }

  @override
  Future<void> exitSignMode() async {
    _flushTimer?.cancel();
    _phrase.clear();
  }

  @override
  void setDetecting(bool v) {}

  @override
  void flushPhrase() {
    _flushTimer?.cancel();
    if (_phrase.isEmpty) return;
    final seq = List.of(_phrase);
    _phrase.clear();
    emit(EngineEvent.gloss, {'gloss': null, 'phrase': const []});
    translateGlosses(seq);
  }

  @override
  void injectGesture(String gestureId) {
    final gloss = _toGloss[gestureId];
    if (gloss == null) return;
    if (_phrase.isEmpty || _phrase.last != gloss) _phrase.add(gloss);
    emit(EngineEvent.gloss, {'gloss': gloss, 'phrase': List.of(_phrase)});
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 1500), flushPhrase);
  }

  @override
  Future<void> startSpeech() async =>
      emit(EngineEvent.speechState, {'state': 'fallback'});

  @override
  Future<void> stopSpeech() async =>
      emit(EngineEvent.speechState, {'state': 'idle'});

  @override
  void submitTyped(String text) {
    if (text.trim().isNotEmpty) simplifyAndEmit(text.trim(), recognizer: 'typed');
  }

  @override
  void speak(String text) {
    _tts.setLanguage('fil-PH');
    _tts.speak(text);
  }
}
