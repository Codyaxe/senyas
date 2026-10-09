import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/errors.dart';
import '../features/inference/pipeline.dart';
import 'engine_base.dart';
import 'engine_events.dart';

/// Android engine. Native Kotlin (senyas_engine) provides CameraX + MediaPipe
/// HandLandmarker glosses and the Android SpeechRecognizer fallback; all model
/// work (Gemma, Whisper) goes through the Dart [pipeline] router via Cactus.
class IoEngine extends SenyasEngineApi {
  static const _methods = MethodChannel('senyas/engine');
  static const _events = EventChannel('senyas/events');

  @override
  bool get hasNativeCamera => true;
  @override
  String get cameraViewType => 'senyas/signcam';

  final List<String> _phrase = [];
  final _tts = FlutterTts();

  /// Which recognizer owns the current speech turn.
  String? _turn; // 'whisper' | 'android' | null

  IoEngine() {
    _events.receiveBroadcastStream().listen((e) {
      if (e is! Map) return;
      final m = Map<String, dynamic>.from(e);
      switch (m['type']) {
        case 'gloss':
          final g = m['gloss'] as String;
          if (_phrase.isEmpty || _phrase.last != g) _phrase.add(g);
          emit(EngineEvent.gloss, {'gloss': g, 'phrase': List.of(_phrase)});
          break;
        case 'phraseFlush':
          flushPhrase();
          break;
        case 'status':
          emit(EngineEvent.status, {'status': m['status'], 'label': m['label']});
          break;
        case 'log':
          emit(EngineEvent.log, {'msg': m['msg'], 'kind': m['kind'] ?? 'info'});
          break;
        case 'speechState':
          if (_turn == 'android') {
            if (m['state'] != 'listening') _turn = null;
            emit(EngineEvent.speechState, {'state': m['state']});
          }
          break;
        case 'interim':
          emit(EngineEvent.speechInterim, {'text': m['text']});
          break;
        case 'transcript':
          final t = (m['text'] as String).trim();
          if (t.isNotEmpty) simplifyAndEmit(t, recognizer: 'android-on-device');
          break;
      }
    });
  }

  @override
  Future<void> boot() async {
    await _invoke('boot');
    await pipeline.boot();
    if (!pipeline.gemmaReady.value && pipeline.lastError.value != null) {
      emitError(pipeline.lastError.value!);
    }
  }

  @override
  Future<void> enterSignMode() async {
    await Permission.camera.request();
    await boot();
  }

  @override
  Future<void> exitSignMode() async {
    _phrase.clear();
    await _invoke('stopSign');
  }

  @override
  void setDetecting(bool v) => _invoke('setDetecting', {'v': v});

  @override
  void flushPhrase() {
    if (_phrase.isEmpty) return;
    final seq = List.of(_phrase);
    _phrase.clear();
    emit(EngineEvent.gloss, {'gloss': null, 'phrase': const []});
    translateGlosses(seq);
  }

  // ---------------- Speech ----------------

  @override
  Future<void> startSpeech() async {
    if (_turn != null) return; // repeated press: ignore
    await pipeline.boot();
    _invoke('setDetecting', {'v': false}); // pause sign processing
    if (await pipeline.canUseWhisper()) {
      _turn = 'whisper';
      try {
        await pipeline.startSpeech();
        emit(EngineEvent.speechState, {'state': 'listening', 'recognizer': 'whisper'});
      } on SenyasError catch (e) {
        _turn = null;
        emitError(e);
        emit(EngineEvent.speechState, {
          'state': e.code == SenyasErrorCode.permissionDenied ? 'mic-denied' : 'idle'
        });
      }
      return;
    }
    // Fallback: Android on-device SpeechRecognizer (not Whisper).
    if (pipeline.lastError.value != null) emitError(pipeline.lastError.value!);
    if (!await Permission.microphone.request().isGranted) {
      emit(EngineEvent.speechState, {'state': 'mic-denied'});
      return;
    }
    _turn = 'android';
    await _invoke('loadSpeech');
    await _invoke('startSpeech', {'lang': speechLang == 'en' ? 'en-US' : 'fil-PH'});
  }

  @override
  Future<void> stopSpeech() async {
    final turn = _turn;
    if (turn == 'android') {
      await _invoke('stopSpeech'); // final transcript arrives as an event
      await _invoke('unloadSpeech');
      return;
    }
    if (turn != 'whisper') return;
    emit(EngineEvent.speechState, {'state': 'transcribing'});
    try {
      final r = await pipeline.finishSpeech(
          lang: speechLang,
          onToken: (t) => emit(EngineEvent.speechToken, {'ch': t}));
      emitSpeechResult(r, recognizer: 'whisper-base (cactus)');
    } on SenyasError catch (e) {
      if (e.code != SenyasErrorCode.cancelled) emitError(e);
    } finally {
      _turn = null;
      emit(EngineEvent.speechState, {'state': 'idle'});
    }
  }

  @override
  Future<void> cancelSpeech() async {
    final turn = _turn;
    _turn = null;
    if (turn == 'whisper') await pipeline.cancelSpeech();
    if (turn == 'android') {
      await _invoke('stopSpeech');
      await _invoke('unloadSpeech');
    }
    emit(EngineEvent.speechState, {'state': 'idle'});
  }

  @override
  void submitTyped(String text) {
    if (text.trim().isNotEmpty) simplifyAndEmit(text.trim(), recognizer: 'typed');
  }

  @override
  void speak(String text) {
    _tts.setLanguage('fil-PH');
    _tts.speak(text);
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _methods.invokeMethod(method, args);
    } on MissingPluginException {
      emit(EngineEvent.log, {'msg': 'Channel $method missing', 'kind': 'error'});
    } on PlatformException catch (e) {
      emit(EngineEvent.log, {'msg': '$method: ${e.message}', 'kind': 'error'});
    }
  }
}
