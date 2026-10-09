import 'dart:async';
import '../core/errors.dart';
import '../features/inference/pipeline.dart';
import 'engine_events.dart';

/// Abstract engine API implemented by SimEngine (desktop fallback),
/// WebEngine (Flutter web -> JS MediaPipe bridge), and IoEngine (Android).
/// Perception (camera/mic) lives in the subclasses; all model work goes
/// through the shared [pipeline] router.
abstract class SenyasEngineApi {
  final _events = StreamController<EngineEvent>.broadcast();
  Stream<EngineEvent> get events => _events.stream;
  void emit(String type, [Map<String, dynamic> data = const {}]) {
    if (!_events.isClosed) _events.add(EngineEvent(type, data));
  }

  SenyasEngineApi() {
    pipeline.state.addListener(() => emit(EngineEvent.router, {
          'state': pipeline.state.value.name,
          'gemma': pipeline.gemmaReady.value,
        }));
  }

  /// Whisper language token: 'tl' (Filipino/Taglish) or 'en'.
  String speechLang = 'tl';

  /// True when there is no real perception backend (desktop sim).
  bool get isSimulated => false;

  /// Whether the UI should embed the platform camera view.
  bool get hasNativeCamera => false;

  /// View type id for the embedded camera widget, or null.
  String? get cameraViewType => null;

  Future<void> boot();
  Future<void> enterSignMode();
  Future<void> exitSignMode();
  void setDetecting(bool v);
  void flushPhrase();

  /// Demo mode (7-handshape heuristic + cheat sheet). No-op on backends
  /// without a heuristic path.
  void setDemoMode(bool v) {}

  /// Manual recording controls (hold/tap to sign without relying on auto-segmentation)
  void startManualRecord() {}
  void stopManualRecord() {}

  /// Commit a user-confirmed gloss into the live phrase buffer (used by
  /// prediction correction taps). Default: translate it as a 1-gloss phrase.
  void commitGloss(String gloss) => translateGlosses([gloss]);
  Future<void> startSpeech();
  Future<void> stopSpeech();
  void submitTyped(String text);
  void speak(String text);

  /// Mode switch / leaving the speech screen mid-turn.
  Future<void> cancelSpeech() => stopSpeech();

  /// Sim-only: inject a demo gesture as if the classifier saw it.
  void injectGesture(String gestureId) {}

  /// Flow A — shared by live recognition and the tap-to-select chips.
  Future<void> translateGlosses(List<String> glosses) async {
    try {
      final r = await pipeline.translateGlosses(glosses,
          onToken: (t) => emit(EngineEvent.token, {'ch': t}));
      emit(EngineEvent.signResult, {
        'sentence': r.text,
        'glosses': r.input.split(' '),
        'source': r.source.name,
        'model': pipeline.modelLabel,
        if (r.warning != null) 'warning': r.warning!.message,
      });
    } on SenyasError catch (e) {
      if (e.code != SenyasErrorCode.cancelled) emitError(e);
    }
  }

  /// Flow B tail — simplify a transcript from any recognizer.
  Future<void> simplifyAndEmit(String transcript, {required String recognizer}) async {
    final r = await pipeline.simplifyTranscript(transcript,
        onToken: (t) => emit(EngineEvent.speechToken, {'ch': t}));
    emitSpeechResult(r, recognizer: recognizer);
  }

  void emitSpeechResult(PipelineResult r, {required String recognizer}) {
    emit(EngineEvent.speechResult, {
      'raw': r.input,
      'simplified': r.text,
      'lang': speechLang == 'en' ? 'English' : 'Filipino',
      'source': r.source.name,
      'model': pipeline.modelLabel,
      'recognizer': recognizer,
      if (r.warning != null) 'warning': r.warning!.message,
    });
  }

  void emitError(SenyasError e) => emit(EngineEvent.error, {
        'code': e.code.name,
        'message': e.message,
        if (e.action != null) 'action': e.action,
      });

  void dispose() => _events.close();
}
