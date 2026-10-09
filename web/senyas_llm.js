// SenyasLLM — Gemma 4 E2B in the browser via MediaPipe LLM Inference (WebGPU).
// All assets are served locally (web/vendor/genai_*, web/models/*.task): no CDN,
// no cloud inference. Model: litert-community/gemma-4-E2B-it-litert-lm
// gemma-4-E2B-it-web.task (2.0 GB, text-only web build).
window.SenyasLLM = (() => {
  const MODEL_PATH = 'models/gemma-4-E2B-it-web.task';
  let llm = null;
  let loading = null;
  let busy = false;

  async function load() {
    if (llm) return true;
    if (loading) return loading;
    loading = (async () => {
      if (!('gpu' in navigator)) throw new Error('WebGPU not available in this browser');
      const { FilesetResolver, LlmInference } = await import('./vendor/genai_bundle.mjs');
      const fileset = await FilesetResolver.forGenAiTasks('./vendor/genai_wasm');
      llm = await LlmInference.createFromOptions(fileset, {
        baseOptions: { modelAssetPath: MODEL_PATH },
        maxTokens: 1024, // total context (prompt + output)
        topK: 1,
        temperature: 0.2,
        randomSeed: 1,
      });
      return true;
    })();
    try {
      return await loading;
    } finally {
      loading = null;
    }
  }

  // Streams output to onToken. Stops early once maxNewTokens (approx., by
  // chunk count) is exceeded or the model starts a new turn.
  async function generate(prompt, maxNewTokens, onToken) {
    if (!llm) throw new Error('Gemma not loaded');
    if (busy) throw new Error('LLM busy');
    busy = true;
    let out = '';
    let chunks = 0;
    let stopped = false;
    try {
      const full = await llm.generateResponse(prompt, (partial, done) => {
        if (stopped || !partial) return;
        chunks++;
        out += partial;
        if (out.includes('<turn|>') || out.includes('<|turn>')) {
          stopped = true;
          llm.cancelProcessing();
          return;
        }
        onToken && onToken(partial);
        if (chunks >= maxNewTokens && !done) {
          stopped = true;
          llm.cancelProcessing();
        }
      });
      return (stopped ? out : (full || out)).split('<turn|>')[0].split('<|turn>')[0];
    } catch (e) {
      if (stopped) return out.split('<turn|>')[0]; // cancellation after early stop
      throw e;
    } finally {
      busy = false;
    }
  }

  function isLoaded() { return !!llm; }

  return { load, generate, isLoaded, MODEL_PATH };
})();
