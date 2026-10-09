import 'dart:async';
import 'package:cactus/models/types.dart' show ChatMessage;
import 'package:flutter/foundation.dart';
import '../../core/errors.dart';
import '../../core/timing.dart';
import '../sign/gloss_vocab.dart';
import '../speech/recorder.dart';
import '../translation/prompts.dart';
import 'inference_backend.dart';

enum RouterState {
  idle,
  loadingGemma,
  sign,
  generating,
  loadingWhisper,
  recording,
  transcribing,
  unloading,
}

enum TextSource { gemma, ruleFallback, rawTranscript }

class PipelineResult {
  final String text;
  final TextSource source;
  final String input; // glosses or raw transcript
  final SenyasError? warning; // set when a fallback was used
  const PipelineResult(this.text, this.source, this.input, {this.warning});
}

/// Serialized model router. Invariants:
///  * every model lifecycle/inference op runs through [_serial] (single flight)
///  * Gemma stays resident once loaded; Whisper only lives inside a speech turn
///  * a Whisper failure never disables the sign flow
///  * cancellation bumps [_epoch]; stale results are dropped, not shown
class ModelRouter {
  ModelRouter({InferenceBackend? backend, PushToTalkRecorder? recorder})
      : _backend = backend,
        _recorder = recorder;

  final InferenceBackend? _backend; // null => no on-device runtime (web/desktop)
  final PushToTalkRecorder? _recorder;

  final state = ValueNotifier<RouterState>(RouterState.idle);
  final lastError = ValueNotifier<SenyasError?>(null);
  final gemmaReady = ValueNotifier<bool>(false);

  /// null = unknown (not tried yet), false = unavailable this session.
  bool? whisperUsable;

  Future<void> _tail = Future.value();
  int _epoch = 0;
  Future<void>? _whisperLoad;
  Future<void>? _bootFuture;

  static const loadGemmaTimeout = Duration(seconds: 90);
  static const loadWhisperTimeout = Duration(seconds: 30);
  static const transcribeTimeout = Duration(seconds: 45);
  static const generateTimeout = Duration(seconds: 30);

  bool get hasRuntime => _backend != null;

  Future<T> _serial<T>(Future<T> Function() op) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await op());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  void _set(RouterState s) => state.value = s;

  SenyasError _report(Object e, SenyasErrorCode fallback) {
    final err = e is SenyasError
        ? e
        : e is TimeoutException
            ? const SenyasError(SenyasErrorCode.timeout, 'Operation timed out')
            : SenyasError(fallback, e.toString());
    if (identical(err, lastError.value)) return err; // already reported
    lastError.value = err;
    debugPrint('[router] $err');
    return err;
  }

  void _checkEpoch(int epoch) {
    if (epoch != _epoch) {
      throw const SenyasError(SenyasErrorCode.cancelled, 'Superseded by a newer action');
    }
  }

  // ---------------- Boot ----------------

  /// Loads Gemma once. Safe to call repeatedly. Never throws.
  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    final b = _backend;
    if (b == null) {
      _set(RouterState.sign);
      return;
    }
    _set(RouterState.loadingGemma);
    try {
      await _serial(() => Metrics.time('gemma_load', b.loadLm))
          .timeout(loadGemmaTimeout);
      gemmaReady.value = true;
      Metrics.recordMemory('after_gemma_load');
    } catch (e) {
      _report(e, SenyasErrorCode.modelLoadFailed);
      _bootFuture = null; // allow retry
    } finally {
      _set(RouterState.sign);
    }
  }

  // ---------------- Flow A: glosses -> Filipino ----------------

  Future<PipelineResult> translateGlosses(List<String> raw,
      {void Function(String token)? onToken}) async {
    final glosses = GlossVocab.normalize(raw);
    if (glosses.isEmpty) {
      throw _report(const SenyasError(SenyasErrorCode.generationFailed,
          'No recognized glosses to translate'), SenyasErrorCode.generationFailed);
    }
    if (_inSpeechTurn) {
      throw _report(const SenyasError(SenyasErrorCode.busy,
          'Speech turn in progress'), SenyasErrorCode.busy);
    }
    final input = glosses.join(' ');
    final e2e = Stopwatch()..start();
    if (!gemmaReady.value) {
      final r = PipelineResult(_ruleRewrite(glosses), TextSource.ruleFallback, input,
          warning: lastError.value ??
              const SenyasError(SenyasErrorCode.unsupported, 'Gemma unavailable'));
      Metrics.record('sign_e2e', e2e.elapsedMicroseconds / 1000, note: 'rule fallback');
      return r;
    }
    final epoch = _epoch;
    try {
      final text = await _generate(Prompts.sign(glosses), Prompts.signMaxTokens,
          onToken: onToken, metric: 'gemma_sign');
      _checkEpoch(epoch);
      Metrics.record('sign_e2e', e2e.elapsedMicroseconds / 1000);
      return PipelineResult(text, TextSource.gemma, input);
    } catch (e) {
      final err = _report(e, SenyasErrorCode.generationFailed);
      if (err.code == SenyasErrorCode.cancelled) rethrow;
      return PipelineResult(_ruleRewrite(glosses), TextSource.ruleFallback, input,
          warning: err);
    }
  }

  Future<String> _generate(List<ChatMessage> messages, int maxTokens,
      {void Function(String)? onToken, required String metric}) {
    return _serial(() async {
      final prev = state.value;
      _set(RouterState.generating);
      final sw = Stopwatch()..start();
      double? ttft;
      try {
        final raw = await _backend!
            .complete(messages, maxTokens: maxTokens, onToken: (t) {
          ttft ??= sw.elapsedMicroseconds / 1000;
          onToken?.call(t);
        }).timeout(generateTimeout);
        Metrics.record('${metric}_ttft', ttft,
            note: ttft == null ? 'no streamed tokens' : null);
        Metrics.record('${metric}_total', sw.elapsedMicroseconds / 1000);
        final text = Prompts.clean(raw);
        if (text.isEmpty) {
          throw const SenyasError(SenyasErrorCode.generationFailed, 'Empty model output');
        }
        return text;
      } finally {
        _set(prev == RouterState.generating ? RouterState.sign : prev);
      }
    });
  }

  String _ruleRewrite(List<String> glosses) {
    final words = glosses.map((g) => GlossVocab.byId[g]!.fil).join(' ');
    return '${words[0].toUpperCase()}${words.substring(1)}.';
  }

  // ---------------- Flow B: push-to-talk -> Whisper -> simplify ----------------

  bool get _inSpeechTurn => const {
        RouterState.loadingWhisper,
        RouterState.recording,
        RouterState.transcribing,
        RouterState.unloading,
      }.contains(state.value);

  /// True when the Cactus Whisper path should be attempted for the next turn.
  Future<bool> canUseWhisper() async {
    final b = _backend;
    if (b == null || _recorder == null || whisperUsable == false) return false;
    if (!await b.sttPresent()) {
      whisperUsable = false;
      lastError.value = const SenyasError(SenyasErrorCode.modelMissing,
          'Whisper model not installed', action: 'Using on-device Android recognizer');
      return false;
    }
    return true;
  }

  /// Push-to-talk press. Starts recording immediately and loads Whisper in
  /// parallel (serialized with other model ops).
  Future<void> startSpeech() async {
    if (_inSpeechTurn) {
      throw _report(const SenyasError(SenyasErrorCode.busy, 'Already listening'),
          SenyasErrorCode.busy);
    }
    final b = _backend!, rec = _recorder!;
    final epoch = ++_epoch;
    lastError.value = null;
    _set(RouterState.loadingWhisper);
    _whisperLoad = _serial(() => Metrics.time('whisper_load', b.loadStt))
        .timeout(loadWhisperTimeout);
    // Avoid unhandled-error noise; the error is observed in finishSpeech.
    _whisperLoad!.catchError((_) {});
    try {
      await rec.start();
      _checkEpoch(epoch);
      _set(RouterState.recording);
    } catch (e) {
      await _abortTurn();
      throw _report(e, SenyasErrorCode.permissionDenied);
    }
  }

  /// Push-to-talk release: stop → transcribe → unload Whisper → simplify.
  Future<PipelineResult> finishSpeech(
      {String lang = 'tl', void Function(String token)? onToken}) async {
    if (state.value != RouterState.recording &&
        state.value != RouterState.loadingWhisper) {
      throw _report(const SenyasError(SenyasErrorCode.busy, 'Not recording'),
          SenyasErrorCode.busy);
    }
    final b = _backend!, rec = _recorder!;
    final epoch = _epoch;
    final e2e = Stopwatch()..start();
    String? wav;
    String transcript;
    try {
      final (path, durMs) = await rec.stop();
      wav = path;
      Metrics.record('audio_recorded', durMs);
      try {
        await _whisperLoad;
      } catch (e) {
        whisperUsable = false; // fall back to Android recognizer next turn
        throw _report(e, SenyasErrorCode.modelLoadFailed);
      }
      _checkEpoch(epoch);
      whisperUsable = true;
      _set(RouterState.transcribing);
      transcript = (await _serial(() => Metrics.time(
              'whisper_transcribe', () => b.transcribe(path, lang)))
          .timeout(transcribeTimeout))
          .trim();
      _checkEpoch(epoch);
    } catch (e) {
      await _abortTurn();
      if (wav != null) await rec.discard(wav);
      throw _report(e, SenyasErrorCode.transcriptionFailed);
    }
    await rec.discard(wav);
    await _unloadWhisper();
    if (transcript.isEmpty) {
      _set(RouterState.sign);
      throw _report(const SenyasError(SenyasErrorCode.emptyAudio,
          'No speech detected', action: 'Try again closer to the mic'),
          SenyasErrorCode.emptyAudio);
    }
    final r = await simplifyTranscript(transcript, onToken: onToken);
    Metrics.record('speech_e2e', e2e.elapsedMicroseconds / 1000);
    return r;
  }

  /// Simplify any transcript (Whisper or Android-recognizer fallback).
  /// On failure the raw transcript is returned, clearly labeled.
  Future<PipelineResult> simplifyTranscript(String transcript,
      {void Function(String token)? onToken}) async {
    _set(RouterState.sign);
    if (!gemmaReady.value) {
      return PipelineResult(transcript, TextSource.rawTranscript, transcript,
          warning: lastError.value ??
              const SenyasError(SenyasErrorCode.unsupported, 'Gemma unavailable'));
    }
    try {
      final text = await _generate(Prompts.simplify(transcript),
          Prompts.simplifyMaxTokens, onToken: onToken, metric: 'gemma_simplify');
      return PipelineResult(text, TextSource.gemma, transcript);
    } catch (e) {
      return PipelineResult(transcript, TextSource.rawTranscript, transcript,
          warning: _report(e, SenyasErrorCode.generationFailed));
    }
  }

  /// Mode switch / back button during a speech turn.
  Future<void> cancelSpeech() async {
    if (!_inSpeechTurn) return;
    _epoch++;
    await _abortTurn();
  }

  Future<void> _abortTurn() async {
    await _recorder?.cancel();
    await _unloadWhisper();
    _set(RouterState.sign);
  }

  Future<void> _unloadWhisper() async {
    final b = _backend;
    if (b == null) return;
    final load = _whisperLoad;
    _whisperLoad = null;
    if (load != null) {
      try {
        await load; // let an in-flight init finish, then destroy it
      } catch (_) {}
    }
    if (!b.sttLoaded) return;
    _set(RouterState.unloading);
    await _serial(() => Metrics.time('whisper_unload', b.unloadStt));
    Metrics.recordMemory('after_whisper_unload');
  }
}
