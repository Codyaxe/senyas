import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:cactus/models/types.dart';
import '../../core/errors.dart';
import 'inference_backend.dart';

/// Laptop/Chrome backend: real Gemma 4 E2B via MediaPipe LLM Inference
/// (WebGPU) through window.SenyasLLM (web/senyas_llm.js). No STT here —
/// the router's Whisper path is disabled on web (no recorder).
class WebGemmaBackend implements InferenceBackend {
  JSObject get _llm => globalContext['SenyasLLM'] as JSObject;
  bool _loaded = false;

  @override
  bool get lmLoaded => _loaded;

  @override
  Future<void> loadLm() async {
    if (_loaded) return;
    try {
      await (_llm.callMethod('load'.toJS) as JSPromise).toDart;
      _loaded = true;
    } catch (e) {
      throw SenyasError(SenyasErrorCode.modelLoadFailed, 'Gemma 4 web load failed: $e',
          action: 'Use Chrome with WebGPU and check web/models/gemma-4-E2B-it-web.task');
    }
  }

  /// Gemma 4 chat format (from the official chat_template.jinja).
  /// Thinking stays OFF: it is only enabled by a `<|think|>` token at the top
  /// of the system turn, which we never emit.
  static String formatGemma4(List<ChatMessage> messages) {
    final b = StringBuffer();
    for (final m in messages) {
      final role = m.role == 'assistant' ? 'model' : m.role;
      b.write('<|turn>$role\n${m.content.trim()}<turn|>\n');
    }
    b.write('<|turn>model\n');
    return b.toString();
  }

  @override
  Future<String> complete(List<ChatMessage> messages,
      {required int maxTokens, void Function(String)? onToken}) async {
    if (!_loaded) {
      throw const SenyasError(SenyasErrorCode.generationFailed, 'Gemma not loaded');
    }
    try {
      final r = await (_llm.callMethod(
        'generate'.toJS,
        formatGemma4(messages).toJS,
        maxTokens.toJS,
        ((JSString t) => onToken?.call(t.toDart)).toJS,
      ) as JSPromise<JSString>)
          .toDart;
      return r.toDart;
    } catch (e) {
      throw SenyasError(SenyasErrorCode.generationFailed, 'Gemma 4 web: $e');
    }
  }

  @override
  bool get sttLoaded => false;
  @override
  Future<bool> sttPresent() async => false;
  @override
  Future<void> loadStt() async =>
      throw const SenyasError(SenyasErrorCode.unsupported, 'No Whisper on web yet');
  @override
  Future<String> transcribe(String wavPath, String lang) async =>
      throw const SenyasError(SenyasErrorCode.unsupported, 'No Whisper on web yet');
  @override
  Future<void> unloadStt() async {}
}
