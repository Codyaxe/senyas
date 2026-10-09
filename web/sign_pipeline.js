// Senyas sign pipeline (browser):
// webcam -> MediaPipe HolisticLandmarker (pose + both hands + face, local wasm)
//        -> 30 fps keypoint frames -> motion-based sign segmentation
//        -> FSL-105 SignTransformer (SenyasFSL, ONNX) -> gloss
//        -> phrase buffer -> Flutter router -> Gemma 4 -> Filipino sentence.
// Optional demo mode adds the old 7-handshape heuristic (off by default).
window.SenyasSign = (() => {
  const FSL = window.SenyasFSL;

  const HAND_CONNECTIONS = [
    [0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],[5,9],[9,10],[10,11],[11,12],
    [9,13],[13,14],[14,15],[15,16],[13,17],[17,18],[18,19],[19,20],[0,17],
  ];
  const POSE_CONNECTIONS = [[11,12],[11,13],[13,15],[12,14],[14,16],[11,23],[12,24],[23,24]];

  // Segmentation / commit tuning
  const SAMPLE_MS = 1000 / 30;     // training sampled at 30 fps
  const PREROLL = 8;               // frames kept before motion starts
  const MIN_FRAMES = 18;           // ~0.6 s
  const MAX_FRAMES = 90;           // ~3 s (FSL-105 clip length)
  const END_NO_HAND = 8;           // ~0.27 s without hands ends a sign
  const END_STILL = 8;             // ~0.27 s of holding still ends a sign
  const MOTION_START = 0.012;      // wrist displacement / frame (normalized)
  const MOTION_STILL = 0.008;      // relaxed stillness threshold to tolerate natural hand tremor
  const COMMIT_PROB = 0.45;        // below this, ask the user to confirm
  const FLUSH_MS = 2500;           // idle time after last gloss -> translate phrase

  let video, canvas, ctx, holistic = null, stream = null, rafId = null;
  let running = false, detecting = true, demoMode = false;
  let lastSampleAt = 0, lastVideoTime = -1;

  // segmentation state
  let state = 'idle';
  const preroll = [];
  let seg = [], noHand = 0, still = 0, lastWrists = null;
  let classifying = false;

  let phrase = [];
  let flushTimer = null;

  const cb = {}; // onStatus, onGloss, onPrediction, onPhrase, onToken, onResult, onFrame

  async function init() {
    if (holistic && FSL.isLoaded()) return true;
    try {
      if (!holistic) {
        const mod = await import('./vendor/vision_bundle.mjs');
        const fileset = await mod.FilesetResolver.forVisionTasks('./vendor/wasm');
        holistic = await mod.HolisticLandmarker.createFromOptions(fileset, {
          baseOptions: { modelAssetPath: './vendor/holistic_landmarker.task', delegate: 'GPU' },
          runningMode: 'VIDEO',
          minPoseDetectionConfidence: 0.5,
          minPosePresenceConfidence: 0.5,
          minHandLandmarksConfidence: 0.35,
        });
      }
      if (!FSL.isLoaded()) {
        cb.onStatus && cb.onStatus('loading', 'Loading FSL recognizer…');
        await FSL.load();
      }
      return true;
    } catch (e) {
      console.error('[SenyasSign] init failed:', String(e && (e.message || e)));
      cb.onStatus && cb.onStatus('model-error',
        'Recognizer failed to load: ' + String(e && (e.message || e)));
      return false;
    }
  }

  async function start(videoEl, canvasEl) {
    video = videoEl; canvas = canvasEl; ctx = canvas.getContext('2d');
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 640, height: 480, facingMode: 'user' }, audio: false });
    } catch (e) {
      cb.onStatus && cb.onStatus('camera-denied', 'Camera permission denied');
      return false;
    }
    video.srcObject = stream;
    await video.play();
    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;
    cb.onStatus && cb.onStatus('loading', 'Loading MediaPipe Holistic…');
    if (!(await init())) return true; // camera still shows; error already reported
    running = true;
    cb.onStatus && cb.onStatus('ready', 'Ready — sign in front of the camera');
    loop();
    return true;
  }

  function stop() {
    running = false;
    if (rafId) cancelAnimationFrame(rafId);
    if (stream) stream.getTracks().forEach(t => t.stop());
    stream = null;
    clearTimeout(flushTimer);
    resetSegment();
    if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
  }

  function setDetecting(v) { detecting = v; if (!v) resetSegment(); }
  function setDemoMode(v) { demoMode = !!v; }

  function resetSegment() { state = 'idle'; seg = []; noHand = 0; still = 0; preroll.length = 0; }

  // ---------- drawing ----------
  function drawLms(lms, conns, color, r) {
    if (!lms) return;
    const W = canvas.width, H = canvas.height;
    ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = 2;
    for (const [a, b] of conns) {
      if (!lms[a] || !lms[b]) continue;
      ctx.beginPath(); ctx.moveTo(lms[a].x * W, lms[a].y * H); ctx.lineTo(lms[b].x * W, lms[b].y * H); ctx.stroke();
    }
    for (const p of lms) { ctx.beginPath(); ctx.arc(p.x * W, p.y * H, r, 0, 2 * Math.PI); ctx.fill(); }
  }

  function draw(res) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const pose = res.poseLandmarks?.[0];
    if (pose) drawLms(pose.slice(0, 25), POSE_CONNECTIONS, 'rgba(255,255,255,0.7)', 2);
    drawLms(res.leftHandLandmarks?.[0], HAND_CONNECTIONS, '#32D8B4', 3);
    drawLms(res.rightHandLandmarks?.[0], HAND_CONNECTIONS, '#79A8DB', 3);
    const face = res.faceLandmarks?.[0];
    if (face) {
      ctx.fillStyle = 'rgba(255,255,255,0.5)';
      for (const i of [13, 14, 61, 291, 33, 263, 1]) {
        const p = face[i]; if (p) { ctx.beginPath(); ctx.arc(p.x * canvas.width, p.y * canvas.height, 1.5, 0, 6.3); ctx.fill(); }
      }
    }
    if (state === 'recording') {
      ctx.fillStyle = '#E5484D';
      ctx.beginPath(); ctx.arc(canvas.width - 22, 22, 8, 0, 6.3); ctx.fill();
    }
  }

  // ---------- main loop ----------
  function loop() {
    if (!running) return;
    rafId = requestAnimationFrame(loop);
    if (!detecting || video.readyState < 2 || video.currentTime === lastVideoTime) return;
    const now = performance.now();
    if (now - lastSampleAt < SAMPLE_MS) return;
    lastSampleAt = now;
    lastVideoTime = video.currentTime;

    let res;
    try { res = holistic.detectForVideo(video, now); } catch (e) { return; }
    draw(res);

    const frame = FSL.frameVector(res, video.videoWidth, video.videoHeight);
    const lh = res.leftHandLandmarks?.[0], rh = res.rightHandLandmarks?.[0];
    const hands = !!(lh || rh);
    const wrists = [lh?.[0], rh?.[0]];
    let motion = 0;
    if (lastWrists) {
      let n = 0;
      for (let i = 0; i < 2; i++) {
        if (wrists[i] && lastWrists[i]) {
          motion += Math.hypot(wrists[i].x - lastWrists[i].x, wrists[i].y - lastWrists[i].y); n++;
        }
      }
      motion = n ? motion / n : 0;
    }
    lastWrists = wrists;

    if (demoMode && hands) demoHandshape(lh || rh, now);

    if (state === 'idle') {
      preroll.push(frame);
      if (preroll.length > PREROLL) preroll.shift();
      if (hands && motion > MOTION_START && !classifying) {
        state = 'recording'; seg = preroll.slice(); preroll.length = 0; noHand = 0; still = 0;
        clearTimeout(flushTimer);
        cb.onStatus && cb.onStatus('signing', 'Signing…');
      } else {
        cb.onStatus && cb.onStatus(hands ? 'hand' : 'no-hand',
          hands ? 'Hands detected' : 'Show your hands');
      }
      return;
    }

    // recording
    seg.push(frame);
    noHand = hands ? 0 : noHand + 1;
    still = hands && motion < MOTION_STILL ? still + 1 : 0;
    if (seg.length % 12 === 0) {
      cb.onStatus && cb.onStatus('signing', `Signing… (${seg.length} frames)`);
    }
    const endReason = noHand >= END_NO_HAND ? 'hand_dropped'
      : (seg.length >= 20 && still >= END_STILL) ? 'stillness'
      : seg.length >= MAX_FRAMES ? 'max_frames' : null;
    const done = !!endReason;
    if (done) {
      const frames = seg;
      resetSegment();
      if (frames.length >= MIN_FRAMES) {
        recognize(frames, endReason);
      } else {
        const durSec = (frames.length / 30).toFixed(2);
        cb.onStatus && cb.onStatus('hand', `Too short (${frames.length} frames, ${durSec}s) — need ≥ 18 frames`);
        cb.onPrediction && cb.onPrediction([], 0, frames.length, false, JSON.stringify({
          reason: 'too_short',
          detail: `Sign lasted only ${frames.length} frames (${durSec}s). Minimum is 18 frames (~0.6s). Please sign a bit slower or hold longer.`,
          endReason,
          frames: frames.length,
        }));
      }
    }
  }

  async function recognize(frames, endReason) {
    classifying = true;
    cb.onStatus && cb.onStatus('classifying', 'Recognizing…');
    try {
      const r = await FSL.classify(frames, 5);
      const best = r.top[0];
      const committed = best.prob >= COMMIT_PROB;
      const pct = Math.round(best.prob * 100);
      let reason = committed ? 'committed' : 'low_confidence';
      let detail = '';
      if (!committed) {
        const runnerUps = r.top.slice(1, 4).map(t => `${t.gloss} (${Math.round(t.prob * 100)}%)`).join(', ');
        detail = `Top candidate '${best.gloss}' reached only ${pct}% (below ${Math.round(COMMIT_PROB * 100)}% auto-commit threshold). Contenders: ${runnerUps}.`;
      } else {
        detail = `Recognized '${best.gloss}' at ${pct}% confidence (${r.frames} frames, ${r.ms}ms).`;
      }
      const meta = {
        reason,
        detail,
        endReason: endReason || 'unknown',
        frames: r.frames,
        ms: r.ms,
        threshold: COMMIT_PROB,
      };
      cb.onPrediction && cb.onPrediction(r.top, r.ms, r.frames, committed, JSON.stringify(meta));
      if (committed) addGloss(best.gloss);
      cb.onStatus && cb.onStatus('ready', committed
        ? `${best.gloss} (${pct}%)`
        : `Uncertain: ${best.gloss} (${pct}%) — tap candidate below`);
    } catch (e) {
      console.error('[SenyasSign] classify failed:', String(e && (e.message || e)));
      cb.onStatus && cb.onStatus('model-error',
        'Recognition failed: ' + String(e && (e.message || e)));
      cb.onPrediction && cb.onPrediction([], 0, frames.length, false, JSON.stringify({
        reason: 'error',
        detail: 'Inference error: ' + String(e && (e.message || e)),
      }));
    } finally {
      classifying = false;
    }
  }

  function addGloss(gloss) {
    if (phrase[phrase.length - 1] !== gloss) phrase.push(gloss);
    if (phrase.length > 6) phrase = phrase.slice(-6);
    cb.onGloss && cb.onGloss(gloss, phrase.slice());
    clearTimeout(flushTimer);
    flushTimer = setTimeout(flushPhrase, FLUSH_MS);
  }

  function flushPhrase() {
    clearTimeout(flushTimer);
    if (!phrase.length) return;
    const seq = phrase;
    phrase = [];
    cb.onGloss && cb.onGloss(null, []);
    cb.onPhrase && cb.onPhrase(seq);
  }

  function manualFlush() { flushPhrase(); }

  // ---------- optional demo mode: 7 static handshapes (heuristic) ----------
  let demoPending = null, demoSince = 0, demoLast = null, demoLastAt = 0;
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const ext = (lm, tip, pip) => dist(lm[tip], lm[0]) > dist(lm[pip], lm[0]) * 1.12;
  function handshape(lm) {
    const thumb = dist(lm[4], lm[17]) > dist(lm[3], lm[17]) * 1.05;
    const i = ext(lm, 8, 6), m = ext(lm, 12, 10), r = ext(lm, 16, 14), p = ext(lm, 20, 18);
    const n = i + m + r + p;
    if (thumb && n === 0) return lm[4].y < lm[2].y - 0.02 ? 'MAGANDA' : lm[4].y > lm[2].y + 0.02 ? 'HINDI' : null;
    if (n === 4 && thumb) return 'HELLO';
    if (n === 0 && !thumb) return 'TULONG';
    if (i && !m && !r && !p) return 'IKAW';
    if (i && m && !r && !p) return 'SALAMAT';
    return null;
  }
  function demoHandshape(lm, now) {
    const g = handshape(lm);
    if (!g || state === 'recording') { demoPending = null; return; }
    if (g !== demoPending) { demoPending = g; demoSince = now; return; }
    if (now - demoSince > 600 && !(g === demoLast && now - demoLastAt < 1500)) {
      demoLast = g; demoLastAt = now; addGloss(g);
    }
  }

  return { init, start, stop, setDetecting, setDemoMode, manualFlush, addGloss, cb,
    get phraseGlosses() { return phrase; } };
})();
