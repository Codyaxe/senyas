// ignore_for_file: implementation_imports
import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/context.dart';
import '../../core/errors.dart';
import 'model_paths.dart';

/// Thin wrapper over the cactus 1.3.0 low-level context API.
/// We deliberately bypass CactusLM/CactusSTT because they (a) resolve models
/// via a Supabase lookup on every call, (b) auto-download missing models and
/// (c) initialise Dart telemetry — all network activity. CactusContext takes
/// an explicit local path and returns a native handle.
class CactusRuntime {
  /// Engine quantization hint used only to size the output buffer.
  static const _quant = 8;

  static Future<int> load(String dir, {int contextSize = 1024}) async {
    if (!await ModelPaths.isPresent(dir)) {
      throw SenyasError(SenyasErrorCode.modelMissing, 'No model at $dir',
          action: 'Side-load the model (see docs/DEMO_SETUP.md)');
    }
    final (handle, msg) = await CactusContext.initContext(dir, contextSize);
    if (handle == null) {
      // The native lib returns null for both incompatible artifacts and
      // allocation failures; we cannot distinguish them from Dart.
      throw SenyasError(SenyasErrorCode.modelLoadFailed,
          'cactusInit failed for $dir${msg.isNotEmpty ? ': $msg' : ''}',
          action: 'Model may be incompatible with cactus 1.3.0 or out of memory');
    }
    return handle;
  }

  static void free(int handle) => CactusContext.freeContext(handle);

  /// Streaming completion. Tokens go to [onToken]; returns the final result.
  static Future<CactusCompletionResult> complete(
    int handle,
    List<ChatMessage> messages, {
    required int maxTokens,
    double temperature = 0.2,
    List<String> stop = const ['<end_of_turn>'],
    void Function(String token)? onToken,
  }) async {
    final params = CactusCompletionParams(
      maxTokens: maxTokens,
      temperature: temperature,
      stopSequences: stop,
    );
    final s = CactusContext.completionStream(handle, messages, params, _quant);
    final sub = s.stream.listen(onToken ?? (_) {}, onError: (_) {});
    try {
      return await s.result;
    } finally {
      await sub.cancel();
    }
  }

  /// Whisper language prompt. `tl` = Tagalog/Filipino, `en` = English.
  static String whisperPrompt(String lang) =>
      '<|startoftranscript|><|$lang|><|transcribe|><|notimestamps|>';

  static Future<CactusTranscriptionResult> transcribe(
          int handle, String wavPath, String lang) =>
      CactusContext.transcribe(handle, whisperPrompt(lang),
          audioFilePath: wavPath,
          params: CactusTranscriptionParams(maxTokens: 224));
}
