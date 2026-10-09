// Senyas Sign Pipeline — REAL implementation.
// webcam -> MediaPipe HandLandmarker -> gesture classification -> segmentation
// -> gloss -> SenyasEngine.gemmaRewrite -> UI.
// Production mapping: this file == engine-vision (Kotlin) + MediaPipe Tasks + TFLite classifier.
window.SenyasSign = (() => {
  const Engine = window.SenyasEngine;

  const HAND_CONNECTIONS = [
    [0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],[5,9],[9,10],[10,11],[11,12],
    [9,13],[13,14],[14,15],[15,16],[13,17],[17,18],[18,19],[19,20],[0,17],
  ];
  const FINGERS = { index: [8, 6], middle: [12, 10], ring: [16, 14], pinky: [20, 18] };

  let video, canvas, ctx, landmarker = null, stream = null, rafId = null;
  let running = false, detecting = true;
  let lastVideoTime = -1;

  // Segmentation state
  let pendingGesture = null, pendingSince = 0;
  let lastCommitted = null, lastCommitAt = 0;
  let phraseGlosses = [];
  let noHandSince = null;
  const wristTrail = []; // {x, t} for wave detection

  const HOLD_MS = 550;        // gesture must be stable this long to commit
  const FLUSH_MS = 1500;      // no-hand pause that flushes the phrase
  const RECOMMIT_MS = 900;    // same-gloss debounce

  const cb = {}; // ui callbacks: onGesture, onGloss, onResult, onStatus, onFrame

  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y, (a.z || 0) - (b.z || 0));

  function fingerExtended(lm, [tip, pip]) {
    return dist(lm[tip], lm[0]) > dist(lm[pip], lm[0]) * 1.12;
  }
  function thumbExtended(lm) {
    return dist(lm[4], lm[17]) > dist(lm[3], lm[17]) * 1.05;
  }

  function classifyGesture(lm) {
    const ext = {
      thumb: thumbExtended(lm),
      index: fingerExtended(lm, FINGERS.index),
      middle: fingerExtended(lm, FINGERS.middle),
      ring: fingerExtended(lm, FINGERS.ring),
      pinky: fingerExtended(lm, FINGERS.pinky),
    };
    const n = ext.index + ext.middle + ext.ring + ext.pinky;

    if (ext.thumb && n === 0) {
      return lm[4].y < lm[2].y - 0.02 ? 'THUMBS_UP' : (lm[4].y > lm[2].y + 0.02 ? 'THUMBS_DOWN' : 'THUMBS_SIDE');
    }
    if (n === 4 && ext.thumb) return 'OPEN_PALM';
    if (n === 0 && !ext.thumb) return 'FIST';
    if (ext.index && !ext.middle && !ext.ring && !ext.pinky) return 'INDEX_POINT';
    if (ext.index && ext.middle && !ext.ring && !ext.pinky) return 'PEACE';
    return null;
  }

  const GESTURE_TO_GLOSS = {
    OPEN_PALM: 'HELLO', FIST: 'TULONG', INDEX_POINT: 'IKAW',
    PEACE: 'SALAMAT', THUMBS_UP: 'MAGANDA', THUMBS_DOWN: 'HINDI',
  };

  function isWaving() {
    if (wristTrail.length < 12) return false;
    const cutoff = performance.now() - 900;
    const pts = wristTrail.filter(p => p.t > cutoff);
    if (pts.length < 10) return false;
    let reversals = 0, lastDir = 0, lastX = pts[0].x;
    const range = Math.max(...pts.map(p => p.x)) - Math.min(...pts.map(p => p.x));
    for (const p of pts) {
      const dx = p.x - lastX;
      if (Math.abs(dx) > 0.008) {
        const dir = Math.sign(dx);
        if (lastDir && dir !== lastDir) reversals++;
        lastDir = dir;
        lastX = p.x;
      }
    }
    return reversals >= 3 && range > 0.08;
  }

  async function init() {
    if (landmarker) return true;
    try {
      Engine.log('Loading MediaPipe HandLandmarker (local wasm + .task)...', 'model');
      const mod = await import('./vendor/vision_bundle.mjs');
      const fileset = await mod.FilesetResolver.forVisionTasks('./vendor/wasm');
      landmarker = await mod.HandLandmarker.createFromOptions(fileset, {
        baseOptions: { modelAssetPath: './vendor/hand_landmarker.task', delegate: 'GPU' },
        runningMode: 'VIDEO',
        numHands: 1,
        minHandDetectionConfidence: 0.5,
        minHandPresenceConfidence: 0.5,
        minTrackingConfidence: 0.5,
      });
      Engine.state.models.landmarker = true;
      Engine.state.memoryMb += 60;
      Engine.log('HandLandmarker ready (7.8 MB model, GPU delegate).', 'model');
      return true;
    } catch (e) {
      Engine.log('HandLandmarker failed: ' + e.message, 'error');
      return false;
    }
  }

  async function start(videoEl, canvasEl) {
    video = videoEl; canvas = canvasEl;
    ctx = canvas.getContext('2d');
    const ok = await init();
    if (!ok) { cb.onStatus && cb.onStatus('model-error'); return false; }
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 640, height: 480, facingMode: 'user' }, audio: false,
      });
    } catch (e) {
      Engine.log('Camera denied: ' + e.message, 'error');
      cb.onStatus && cb.onStatus('camera-denied');
      return false;
    }
    video.srcObject = stream;
    await video.play();
    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;
    running = true;
    Engine.log('Camera started. Landmark extraction @15-30 fps.', 'vision');
    loop();
    return true;
  }

  function stop() {
    running = false;
    if (rafId) cancelAnimationFrame(rafId);
    if (stream) stream.getTracks().forEach(t => t.stop());
    stream = null;
    if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
    Engine.log('Camera stopped.', 'vision');
  }

  function setDetecting(v) { detecting = v; }

  function draw(lm, label) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.lineWidth = 2;
    ctx.strokeStyle = '#32D8B4';
    for (const [a, b] of HAND_CONNECTIONS) {
      ctx.beginPath();
      ctx.moveTo(lm[a].x * canvas.width, lm[a].y * canvas.height);
      ctx.lineTo(lm[b].x * canvas.width, lm[b].y * canvas.height);
      ctx.stroke();
    }
    ctx.fillStyle = '#FFFFFF';
    for (const p of lm) {
      ctx.beginPath();
      ctx.arc(p.x * canvas.width, p.y * canvas.height, 3.5, 0, 2 * Math.PI);
      ctx.fill();
    }
    if (label) {
      ctx.font = 'bold 16px Inter, sans-serif';
      ctx.fillStyle = '#32D8B4';
      ctx.fillText(label, lm[0].x * canvas.width - 30, lm[0].y * canvas.height + 30);
    }
  }

  function loop() {
    if (!running) return;
    rafId = requestAnimationFrame(loop);
    if (!detecting || video.readyState < 2 || video.currentTime === lastVideoTime) return;
    lastVideoTime = video.currentTime;
    const t0 = performance.now();
    const res = landmarker.detectForVideo(video, t0);
    const inferMs = performance.now() - t0;

    const now = performance.now();
    const lm = res.landmarks && res.landmarks[0];

    if (!lm) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      cb.onStatus && cb.onStatus('no-hand');
      if (!noHandSince) noHandSince = now;
      pendingGesture = null;
      // Phrase boundary: flush buffered glosses
      if (phraseGlosses.length && now - noHandSince > FLUSH_MS) flushPhrase();
      return;
    }
    noHandSince = null;
    wristTrail.push({ x: lm[0].x, t: now });
    if (wristTrail.length > 60) wristTrail.shift();

    let gesture = classifyGesture(lm);
    if (gesture === 'OPEN_PALM' && isWaving()) gesture = 'WAVE';

    const label = gesture ? gesture.replace('_', ' ') : '';
    draw(lm, label);
    cb.onFrame && cb.onFrame({ gesture, inferMs });
    cb.onStatus && cb.onStatus('hand', label);

    // Segmentation: commit a gloss when a gesture is held steady
    if (gesture && gesture === pendingGesture) {
      if (now - pendingSince > HOLD_MS) commitGesture(gesture, now);
    } else {
      pendingGesture = gesture;
      pendingSince = now;
    }
  }

  function commitGesture(gesture, now) {
    if (now - lastCommitAt < RECOMMIT_MS && lastCommitted === gesture) { pendingSince = now; return; }
    lastCommitted = gesture; lastCommitAt = now;
    const gloss = gesture === 'WAVE' ? 'KAMUSTA' : GESTURE_TO_GLOSS[gesture];
    if (!gloss) return;
    if (phraseGlosses[phraseGlosses.length - 1] !== gloss) phraseGlosses.push(gloss);
    if (phraseGlosses.length > 6) phraseGlosses = phraseGlosses.slice(-6);
    cb.onGloss && cb.onGloss(gloss, phraseGlosses);
    Engine.log(`Gloss committed: ${gloss} (phrase: [${phraseGlosses.join(', ')}])`, 'vision');
  }

  async function flushPhrase() {
    const seq = phraseGlosses;
    phraseGlosses = [];
    cb.onGloss && cb.onGloss(null, []);
    if (cb.onPhrase) { cb.onPhrase(seq); return; } // Flutter router handles it
    const sentence = await Engine.gemmaRewrite(seq, cb.onToken);
    if (sentence) cb.onResult && cb.onResult(sentence, seq);
  }

  function manualFlush() { if (phraseGlosses.length) { noHandSince = performance.now(); flushPhrase(); } }

  return { init, start, stop, setDetecting, manualFlush, cb,
    get phraseGlosses() { return phraseGlosses; } };
})();
