// ignore_for_file: implementation_imports
import 'package:cactus/models/types.dart';
import '../../core/errors.dart';
import 'cactus_runtime.dart';
import 'inference_backend.dart';
import 'model_paths.dart';

/// Cactus 1.3.0 backend: gemma3-1b resident + whisper-base on demand.
class CactusBackend implements InferenceBackend {
  int? _lm, _stt;

  @override
  bool get lmLoaded => _lm != null;
  @override
  bool get sttLoaded => _stt != null;

  @override
  Future<void> loadLm() async {
    if (_lm != null) return;
    _lm = await CactusRuntime.load(await ModelPaths.gemma(), contextSize: 1024);
  }

  @override
  Future<String> complete(List<ChatMessage> messages,
      {required int maxTokens, void Function(String)? onToken}) async {
    final h = _lm;
    if (h == null) {
      throw const SenyasError(SenyasErrorCode.generationFailed, 'Gemma not loaded');
    }
    final r = await CactusRuntime.complete(h, messages,
        maxTokens: maxTokens, onToken: onToken);
    if (!r.success) {
      throw SenyasError(SenyasErrorCode.generationFailed, r.response);
    }
    return r.response;
  }

  @override
  Future<bool> sttPresent() async => ModelPaths.isPresent(await ModelPaths.whisper());

  @override
  Future<void> loadStt() async {
    if (_stt != null) return;
    _stt = await CactusRuntime.load(await ModelPaths.whisper(), contextSize: 448);
  }

  @override
  Future<String> transcribe(String wavPath, String lang) async {
    final h = _stt;
    if (h == null) {
      throw const SenyasError(SenyasErrorCode.transcriptionFailed, 'Whisper not loaded');
    }
    final r = await CactusRuntime.transcribe(h, wavPath, lang);
    if (!r.success) {
      throw SenyasError(SenyasErrorCode.transcriptionFailed,
          r.errorMessage ?? 'Whisper returned failure');
    }
    return r.text;
  }

  /// Calls cactus freeContext (native destroy). Whether the OS reclaims the
  /// pages immediately is NOT verified — check the rss metric after unload.
  @override
  Future<void> unloadStt() async {
    final h = _stt;
    _stt = null;
    if (h != null) CactusRuntime.free(h);
  }
}
