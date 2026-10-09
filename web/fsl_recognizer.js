// FSL recognizer — pretrained FSL-105 SignTransformer (remi-9/fslr-transformer-vs-iv3gru)
// converted to ONNX (tools/export_fsl_onnx.py), run with onnxruntime-web (local wasm).
// Input: MediaPipe Holistic keypoints, 178-D per frame = 89 points × (x,y):
//   25 upper-body pose + 21 left hand + 21 right hand + 22 face points.
// Feature construction mirrors the training pipeline (and tools/validate_fsl.py):
//   30 fps sampling, coords letterboxed to a square, pose visibility >= 0.35,
//   missing = 0, gaps <= 5 frames linearly interpolated, clipped to [0,1].
window.SenyasFSL = (() => {
  const POSE_UPPER_25 = [...Array(25).keys()];
  const FACE_MINIMAL_22 = [81, 13, 311, 61, 178, 14, 402, 291, 33, 133, 159, 362, 263, 386,
    70, 107, 46, 300, 336, 276, 1, 4];
  const CONF = 0.35;
  const K = 89, D = 178;

  let ort = null, session = null, labels = null, loading = null;

  async function load() {
    if (session) return true;
    if (loading) return loading;
    loading = (async () => {
      try {
        ort = await import('./vendor/ort/ort.wasm.min.mjs');
        ort.env.wasm.wasmPaths = new URL('./vendor/ort/', document.baseURI).href;
        ort.env.wasm.numThreads = 1; // no cross-origin isolation on the dev server
        session = await ort.InferenceSession.create('models/fsl105_transformer.onnx',
          { executionProviders: ['wasm'] });
        console.log('[FSL] onnx session ready, inputs:', session.inputNames);
        labels = await (await fetch('models/fsl105_labels.json')).json();
        console.log('[FSL] labels:', labels.length);
        return true;
      } catch (e) {
        session = null;
        console.error('[FSL] load failed:', String(e && (e.message || e)));
        throw e;
      }
    })();
    try { return await loading; } finally { loading = null; }
  }

  function letterbox(x, y, w, h) {
    const s = Math.max(w, h);
    return [(x * w + (s - w) / 2) / s, (y * h + (s - h) / 2) / s];
  }

  /** One HolisticLandmarker result -> {vec: Float32Array(178), mask: Uint8Array(89)} */
  function frameVector(res, w, h) {
    const vec = new Float32Array(D), mask = new Uint8Array(K);
    let k = 0;
    const put = (lms, idxs, useVis) => {
      for (const i of idxs) {
        const lm = lms && lms[i];
        if (lm && (!useVis || (lm.visibility ?? 0) >= CONF)) {
          const [x, y] = letterbox(lm.x, lm.y, w, h);
          vec[2 * k] = x; vec[2 * k + 1] = y; mask[k] = 1;
        }
        k++;
      }
    };
    put(res.poseLandmarks?.[0], POSE_UPPER_25, true);
    put(res.leftHandLandmarks?.[0], [...Array(21).keys()], false);
    put(res.rightHandLandmarks?.[0], [...Array(21).keys()], false);
    put(res.faceLandmarks?.[0], FACE_MINIMAL_22, false);
    return { vec, mask };
  }

  function interpolateGaps(frames, maxGap = 5) {
    const T = frames.length;
    const X = new Float32Array(T * D);
    frames.forEach((f, t) => X.set(f.vec, t * D));
    for (let k = 0; k < K; k++) {
      let prev = -1;
      for (let t = 0; t < T; t++) {
        if (!frames[t].mask[k]) continue;
        const gap = t - prev - 1;
        if (prev >= 0 && gap >= 1 && gap <= maxGap) {
          for (let j = 1; j <= gap; j++) {
            const a = j / (gap + 1);
            for (const c of [0, 1]) {
              const i0 = prev * D + 2 * k + c, i1 = t * D + 2 * k + c;
              X[(prev + j) * D + 2 * k + c] = (1 - a) * X[i0] + a * X[i1];
            }
          }
        }
        prev = t;
      }
    }
    for (let i = 0; i < X.length; i++) X[i] = Math.min(1, Math.max(0, X[i]));
    return X;
  }

  /** frames: [{vec,mask}] sampled at ~30 fps. Returns top-k predictions. */
  async function classify(frames, topK = 5) {
    if (!session) throw new Error('FSL model not loaded');
    const T = Math.min(frames.length, 300);
    const X = interpolateGaps(frames.slice(-T));
    const t0 = performance.now();
    const out = await session.run({ x: new ort.Tensor('float32', X, [1, T, D]) });
    const ms = Math.round(performance.now() - t0);
    const p = out.gloss_probs.data;
    const order = [...p.keys()].sort((a, b) => p[b] - p[a]).slice(0, topK);
    return {
      ms, frames: T,
      top: order.map(i => ({ gloss: labels[i].gloss, cat: labels[i].cat, prob: p[i] })),
    };
  }

  return { load, frameVector, classify, isLoaded: () => !!session,
    get labels() { return labels; } };
})();
