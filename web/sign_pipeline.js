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
  const MIN_FRAMES = 24;           // ~0.8 s minimum for a real sign
  const MAX_FRAMES = 90;           // ~3 s (FSL-105 clip length)
  const END_NO_HAND = 10;          // ~0.33 s without hands ends a sign
  const END_STILL = 16;            // ~0.53 s of holding still ends a sign
  const MOTION_START = 0.022;      // deliberate wrist movement (ignores tremor)
  const MOTION_STILL = 0.009;      // stillness threshold for sign completion
  const COMMIT_PROB = 0.52;        // confident auto-commit threshold
  const COOLDOWN_MS = 1200;        // 1.2s pause between signs to stop continuous loop
  const FLUSH_MS = 2500;           // idle time after last gloss -> translate phrase

  let video, canvas, ctx, holistic = null, stream = null, rafId = null;
  let running = false, detecting = true, demoMode = false;
  let lastSampleAt = 0, lastVideoTime = -1;

  // segmentation state
  let state = 'idle';
  let cooldownUntil = 0;
  const preroll = [];
  let seg = [], segHandshapes = [], noHand = 0, still = 0, lastWrists = null;
  let classifying = false;

  let phrase = [];
  let flushTimer = null;

  const cb = {}; // onStatus, onGloss, onPrediction, onPhrase, onToken, onResult, onFrame

  // Handshape analyzer for disambiguation (e.g. THANK YOU vs ORANGE vs FISH)
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const ext = (lm, tip, pip) => dist(lm[tip], lm[0]) > dist(lm[pip], lm[0]) * 1.12;

  function analyzeHandshape(lm) {
    if (!lm || lm.length < 21) return null;
    const thumb = dist(lm[4], lm[17]) > dist(lm[3], lm[17]) * 1.05;
    const i = ext(lm, 8, 6), m = ext(lm, 12, 10), r = ext(lm, 16, 14), p = ext(lm, 20, 18);
    const n = (i ? 1 : 0) + (m ? 1 : 0) + (r ? 1 : 0) + (p ? 1 : 0);

    // 1. Flat B-hand (SALAMAT / THANK YOU): 4 fingers flat together
    if (i && m && r && p) {
      const together = dist(lm[8], lm[12]) < 0.085 && dist(lm[12], lm[16]) < 0.085;
      return together ? 'FLAT_B' : 'OPEN_5';
    }
    // 2. ILY hand: thumb + index + pinky
    if (thumb && i && !m && !r && p) return 'ILY';
    // 3. Index point: 1 finger
    if (i && !m && !r && !p) return 'INDEX_POINT';
    // 4. V-hand: 2 fingers
    if (i && m && !r && !p) return 'V_HAND';
    // 5. N-pinch: tips meeting thumb
    if (!r && !p && (dist(lm[8], lm[4]) < 0.12 || dist(lm[12], lm[4]) < 0.12)) return 'N_PINCH';
    // 6. S-fist: closed fist
    if (n === 0 && !thumb) return 'S_FIST';

    return null;
  }

  function getDominantHandshape(shapes) {
    if (!shapes || !shapes.length) return null;
    const counts = {};
    for (const s of shapes) if (s) counts[s] = (counts[s] || 0) + 1;
    let best = null, max = 0;
    for (const [k, v] of Object.entries(counts)) {
      if (v > max) { max = v; best = k; }
    }
    return max >= 4 ? best : null;
  }

  function disambiguateCandidates(top, dominantHs) {
    if (!top || !top.length) return top;
    const candidates = top.slice();

    // 1. Flat B-hand: In FSL, THANK YOU is signed with flat B-hand moving from chin outward.
    // If model predicted ORANGE / FISH due to chin collision, promote THANK YOU.
    if (dominantHs === 'FLAT_B') {
      const thankIdx = candidates.findIndex(c => c.gloss.includes('THANK'));
      if (thankIdx >= 0) {
        const thank = candidates.splice(thankIdx, 1)[0];
        thank.prob = Math.max(thank.prob * 2.2, 0.85);
        candidates.unshift(thank);
      } else if (candidates.some(c => c.gloss === 'ORANGE' || c.gloss === 'FISH')) {
        candidates.unshift({ gloss: 'THANK YOU', cat: 'GREETING', prob: 0.84 });
      }
    } else if (dominantHs === 'ILY') {
      candidates.unshift({ gloss: 'MAHAL KITA', cat: 'RELATIONSHIPS', prob: 0.90 });
    } else if (dominantHs === 'S_FIST') {
      const yesIdx = candidates.findIndex(c => c.gloss === 'YES');
      if (yesIdx >= 0) {
        const yes = candidates.splice(yesIdx, 1)[0];
        yes.prob = Math.max(yes.prob * 2.0, 0.85);
        candidates.unshift(yes);
      } else {
        candidates.unshift({ gloss: 'YES', cat: 'SURVIVAL', prob: 0.85 });
      }
    } else if (dominantHs === 'N_PINCH') {
      const noIdx = candidates.findIndex(c => c.gloss === 'NO');
      if (noIdx >= 0) {
        const no = candidates.splice(noIdx, 1)[0];
        no.prob = Math.max(no.prob * 2.0, 0.85);
        candidates.unshift(no);
      } else {
        candidates.unshift({ gloss: 'NO', cat: 'SURVIVAL', prob: 0.85 });
      }
    } else if (dominantHs === 'INDEX_POINT') {
      const targetIdx = candidates.findIndex(c => c.gloss === 'HOW ARE YOU' || c.gloss === 'ONE');
      if (targetIdx >= 0) {
        const target = candidates.splice(targetIdx, 1)[0];
        target.prob = Math.max(target.prob * 1.8, 0.80);
        candidates.unshift(target);
      }
    } else if (dominantHs === 'V_HAND') {
      const twoIdx = candidates.findIndex(c => c.gloss === 'TWO');
      if (twoIdx >= 0) {
        const two = candidates.splice(twoIdx, 1)[0];
        two.prob = Math.max(two.prob * 2.0, 0.85);
        candidates.unshift(two);
      } else {
        candidates.unshift({ gloss: 'TWO', cat: 'NUMBER', prob: 0.85 });
      }
    }

    return candidates.slice(0, 5);
  }

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

  function resetSegment() { state = 'idle'; seg = []; segHandshapes = []; noHand = 0; still = 0; preroll.length = 0; }

  function startManualRecord() {
    if (classifying) return;
    state = 'recording';
    seg = [];
    segHandshapes = [];
    noHand = 0;
    still = 0;
    clearTimeout(flushTimer);
    cb.onStatus && cb.onStatus('signing', 'Recording sign…');
  }

  function stopManualRecord() {
    if (state !== 'recording') return;
    const frames = seg;
    const dominantHs = getDominantHandshape(segHandshapes);
    resetSegment();
    cooldownUntil = performance.now() + COOLDOWN_MS;
    state = 'cooldown';
    if (frames.length >= 15) {
      recognize(frames, 'manual_stop', dominantHs);
    } else {
      cb.onStatus && cb.onStatus('hand', 'Recording too short');
    }
  }

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

    // Status pill badge at top center
    ctx.save();
    let badgeText = '', badgeColor = '', badgeBg = 'rgba(15, 23, 42, 0.88)';
    if (state === 'recording') {
      badgeText = `● SIGNING (${(seg.length / 30).toFixed(1)}s)`;
      badgeColor = '#EF4444';
    } else if (state === 'cooldown') {
      badgeText = '⏸ PAUSE';
      badgeColor = '#F59E0B';
    } else if (state === 'idle') {
      badgeText = 'READY TO SIGN';
      badgeColor = '#32D8B4';
    }
    if (badgeText) {
      ctx.font = 'bold 14px Inter, -apple-system, sans-serif';
      const w = ctx.measureText(badgeText).width + 24;
      const x = (canvas.width - w) / 2;
      ctx.fillStyle = badgeBg;
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(x, 14, w, 28, 14); else ctx.rect(x, 14, w, 28);
      ctx.fill();
      ctx.strokeStyle = badgeColor;
      ctx.lineWidth = 1.5;
      ctx.stroke();
      ctx.fillStyle = badgeColor;
      ctx.fillText(badgeText, x + 12, 33);
    }
    ctx.restore();
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
    const activeHand = rh || lh;
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

    // Cooldown state
    if (state === 'cooldown') {
      if (now < cooldownUntil) {
        cb.onStatus && cb.onStatus('hand', `Sign captured (${Math.ceil((cooldownUntil - now)/1000)}s pause)`);
        return;
      }
      state = 'idle';
      seg = [];
      segHandshapes = [];
      preroll.length = 0;
      noHand = 0;
      still = 0;
    }

    if (state === 'idle') {
      preroll.push(frame);
      if (preroll.length > PREROLL) preroll.shift();
      if (hands && motion > MOTION_START && !classifying) {
        state = 'recording';
        seg = preroll.slice();
        segHandshapes = [];
        preroll.length = 0;
        noHand = 0;
        still = 0;
        clearTimeout(flushTimer);
        cb.onStatus && cb.onStatus('signing', 'Signing… (hold steady at end)');
      } else {
        cb.onStatus && cb.onStatus(hands ? 'hand' : 'no-hand',
          hands ? 'Ready — sign when ready' : 'Show your hands');
      }
      return;
    }

    // recording state
    seg.push(frame);
    if (activeHand) {
      const hs = analyzeHandshape(activeHand);
      if (hs) segHandshapes.push(hs);
    }
    noHand = hands ? 0 : noHand + 1;
    still = hands && motion < MOTION_STILL ? still + 1 : 0;
    if (seg.length % 10 === 0) {
      cb.onStatus && cb.onStatus('signing', `Signing… (${seg.length} frames)`);
    }
    const endReason = noHand >= END_NO_HAND ? 'hand_dropped'
      : (seg.length >= 24 && still >= END_STILL) ? 'stillness'
      : seg.length >= MAX_FRAMES ? 'max_frames' : null;
    const done = !!endReason;
    if (done) {
      const frames = seg;
      const dominantHs = getDominantHandshape(segHandshapes);
      resetSegment();
      cooldownUntil = now + COOLDOWN_MS;
      state = 'cooldown';
      if (frames.length >= MIN_FRAMES) {
        recognize(frames, endReason, dominantHs);
      } else {
        const durSec = (frames.length / 30).toFixed(2);
        cb.onStatus && cb.onStatus('hand', `Too short (${frames.length} frames, ${durSec}s) — need ≥ 24 frames`);
        cb.onPrediction && cb.onPrediction([], 0, frames.length, false, JSON.stringify({
          reason: 'too_short',
          detail: `Sign lasted only ${frames.length} frames (${durSec}s). Hold sign a moment longer (~0.8s+).`,
          endReason,
          frames: frames.length,
        }));
      }
    }
  }

  async function recognize(frames, endReason, dominantHs) {
    classifying = true;
    cb.onStatus && cb.onStatus('classifying', 'Recognizing…');
    try {
      const r = await FSL.classify(frames, 8);
      const top = disambiguateCandidates(r.top, dominantHs);
      const best = top[0];
      const committed = best.prob >= COMMIT_PROB;
      const pct = Math.round(best.prob * 100);
      let reason = committed ? 'committed' : 'low_confidence';
      let detail = '';
      if (!committed) {
        const runnerUps = top.slice(1, 4).map(t => `${t.gloss} (${Math.round(t.prob * 100)}%)`).join(', ');
        detail = `Top candidate '${best.gloss}' reached only ${pct}% (below ${Math.round(COMMIT_PROB * 100)}% auto-commit threshold). Contenders: ${runnerUps}.`;
      } else {
        detail = `Recognized '${best.gloss}' at ${pct}% confidence (${r.frames} frames, ${r.ms}ms, handshape: ${dominantHs || 'dynamic'}).`;
      }
      const meta = {
        reason,
        detail,
        endReason: endReason || 'unknown',
        handshape: dominantHs || 'dynamic',
        frames: r.frames,
        ms: r.ms,
        threshold: COMMIT_PROB,
      };
      cb.onPrediction && cb.onPrediction(top, r.ms, r.frames, committed, JSON.stringify(meta));
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

  // ---------- optional demo mode: authentic FSL handshapes ----------
  let demoPending = null, demoSince = 0, demoLast = null, demoLastAt = 0;
  function demoHandshape(lm, now) {
    const g = analyzeHandshape(lm);
    let mapped = null;
    if (g === 'FLAT_B') mapped = 'SALAMAT';
    else if (g === 'ILY') mapped = 'MAHAL_KITA';
    else if (g === 'INDEX_POINT') mapped = 'IKAW';
    else if (g === 'S_FIST') mapped = 'OO';
    else if (g === 'N_PINCH') mapped = 'HINDI';
    else if (g === 'V_HAND') mapped = 'DALAWA';
    else if (g === 'OPEN_5') mapped = 'SANDALI';

    if (!mapped || state === 'recording') { demoPending = null; return; }
    if (mapped !== demoPending) { demoPending = mapped; demoSince = now; return; }
    if (now - demoSince > 600 && !(mapped === demoLast && now - demoLastAt < 1500)) {
      demoLast = mapped; demoLastAt = now; addGloss(mapped);
    }
  }

  return { init, start, stop, setDetecting, setDemoMode, manualFlush, addGloss,
    startManualRecord, stopManualRecord, cb,
    get phraseGlosses() { return phrase; } };
})();
