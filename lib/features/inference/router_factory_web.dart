import 'model_router.dart';
import 'web_gemma_backend.dart';

/// Web (laptop Chrome): real Gemma 4 E2B via WebGPU. No recorder → the
/// Whisper path is skipped and speech uses the browser recognizer, labeled.
ModelRouter createRouter() => ModelRouter(
    backend: WebGemmaBackend(), modelLabel: 'Gemma 4 E2B (on-device, WebGPU)');
