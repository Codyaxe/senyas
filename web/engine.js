// Senyas MVP Engine — simulates the on-device inference stack from the plan.
// Production mapping: ModelRouter -> Kotlin ModelRouter; gemmaRewrite -> cactusComplete(Gemma-4-E2B);
// simplifyTranscript -> Gemma simplify prompt; whisper lifecycle -> cactusInit/cactusDestroy of whisper-small.
window.SenyasEngine = (() => {
  const listeners = {};
  const state = {
    router: 'IDLE',
    models: { gemma: false, whisper: false, landmarker: false },
    memoryMb: 380, // simulated app overhead
    log: [],
  };

  function on(evt, cb) { (listeners[evt] = listeners[evt] || []).push(cb); }
  function emit(evt, data) { (listeners[evt] || []).forEach(cb => cb(data)); }

  function log(msg, kind = 'info') {
    const entry = { t: new Date(), msg, kind };
    state.log.push(entry);
    if (state.log.length > 200) state.log.shift();
    emit('log', entry);
  }

  function setRouter(next) {
    if (state.router === next) return;
    const prev = state.router;
    state.router = next;
    emit('router', { prev, next, models: { ...state.models }, memoryMb: state.memoryMb });
    log(`Router: ${prev} -> ${next}`, 'router');
  }

  const delay = ms => new Promise(r => setTimeout(r, ms));

  async function boot() {
    if (state.router !== 'IDLE') return;
    setRouter('WARMING');
    log('Booting engine: cactusInit(gemma-4-e2b-it, CQ4) [simulated]', 'model');
    await delay(900);
    state.models.gemma = true;
    state.memoryMb += 2900;
    emit('models', state.models);
    log('Gemma-4-E2B resident. System prompts pre-warmed (cactusPrefill).', 'model');
    setRouter('READY_SIGN');
  }

  async function enterSpeechMode() {
    if (state.router === 'SPEECH_ACTIVE' || state.router === 'STT_LOADING') return;
    setRouter('STT_LOADING');
    log('Speech mode: cactusInit(whisper-small, INT4) on demand [simulated]', 'model');
    await delay(650);
    state.models.whisper = true;
    state.memoryMb += 250;
    emit('models', state.models);
    log('Whisper loaded (250 MB). VAD active.', 'model');
    setRouter('SPEECH_ACTIVE');
  }

  async function exitSpeechMode() {
    if (state.router !== 'SPEECH_ACTIVE') return;
    setRouter('STT_UNLOADING');
    await delay(250);
    state.models.whisper = false;
    state.memoryMb -= 250;
    emit('models', state.models);
    log('Whisper unloaded — memory returned to pool.', 'model');
    setRouter('READY_SIGN');
  }

  // ---- "Mini-Gemma": deterministic stand-in for gloss -> fluent Filipino ----
  // In production this is Gemma-4-E2B with a few-shot prompt. Here: template grammar.
  const GLOSS_LEXICON = {
    KAMUSTA:   { fil: 'Kamusta ka!',       en: 'Hello / How are you',  signHint: '👋 Wave hand' },
    HELLO:     { fil: 'Hello po!',          en: 'Hello (polite)',       signHint: '✋ Open palm, hold' },
    MAGANDA:   { fil: 'Maganda!',           en: 'Good / Beautiful',     signHint: '👍 Thumbs up' },
    HINDI:     { fil: 'Hindi po.',          en: 'No / Not',             signHint: '👎 Thumbs down' },
    IKAW:      { fil: 'Ikaw',               en: 'You',                  signHint: '☝️ Point index' },
    SALAMAT:   { fil: 'Salamat po!',        en: 'Thank you',            signHint: '✌️ Peace sign' },
    TULONG:    { fil: 'Tulong!',            en: 'Help!',                signHint: '✊ Closed fist' },
  };

  // Few-shot phrase rules: gloss sequence -> natural Filipino (mirrors planned prompt pairs)
  const PHRASE_RULES = [
    { seq: ['KAMUSTA', 'IKAW'], out: 'Kamusta ka?' },
    { seq: ['IKAW', 'MAGANDA'], out: 'Maganda ka!' },
    { seq: ['MAGANDA', 'IKAW'], out: 'Maganda ka!' },
    { seq: ['SALAMAT', 'IKAW'], out: 'Salamat sa iyo!' },
    { seq: ['IKAW', 'TULONG'],  out: 'Tulungan mo ako.' },
    { seq: ['TULONG', 'IKAW'],  out: 'Kailangan ko ng tulong mo!' },
    { seq: ['KAMUSTA', 'SALAMAT'], out: 'Kamusta! Salamat po!' },
  ];

  async function gemmaRewrite(glosses, onToken) {
    // Simulated decode latency + streaming, matching planned ~200-500 ms rewrite.
    const seq = glosses.filter(g => GLOSS_LEXICON[g]);
    if (!seq.length) return null;
    let out = null;
    for (const rule of PHRASE_RULES) {
      if (rule.seq.every((g, i) => seq[i] === g) && rule.seq.length === seq.length) { out = rule.out; break; }
    }
    if (!out) out = seq.map(g => GLOSS_LEXICON[g].fil).join(' ');
    const t0 = performance.now();
    log(`gemmaComplete: glosses=[${seq.join(',')}] max_tokens=60 thinking=off`, 'model');
    await delay(220 + Math.random() * 180);
    if (onToken) {
      for (const ch of out) { onToken(ch); await delay(8); }
    }
    log(`gemmaComplete done in ${Math.round(performance.now() - t0)} ms -> "${out}"`, 'model');
    return out;
  }

  // ---- Simplifier: stand-in for the Gemma "deaf-reader rewrite" prompt ----
  const FILLERS = /\b(um+|uh+|like|you know|actually|basically|literally|nga|kasi|parang|ano ba)\b/gi;
  const SIMPLE_MAP = {
    'approximately': 'about', 'immediately': 'now', 'purchase': 'buy', 'assistance': 'help',
    'information': 'info', 'difficult': 'hard', 'require': 'need', 'commence': 'start',
    'sufficient': 'enough', 'additional': 'more', 'utilize': 'use', 'endeavor': 'try',
  };

  function simplifyTranscript(raw) {
    const t0 = performance.now();
    let text = ' ' + raw.trim() + ' ';
    text = text.replace(FILLERS, ' ');
    Object.entries(SIMPLE_MAP).forEach(([k, v]) => {
      text = text.replace(new RegExp(`\\b${k}\\b`, 'gi'), v);
    });
    // Split into short clauses (planned rule: <= ~10 words per sentence)
    const clauses = text
      .split(/[,;]|\.\s+| but | however | because | so that | and then /i)
      .map(s => s.trim())
      .filter(s => s.length > 1);
    const out = clauses
      .map(s => {
        const words = s.split(/\s+/);
        const trimmed = words.slice(0, 12).join(' ');
        return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
      })
      .join('. ')
      .replace(/\.+$/, '') + '.';
    log(`gemmaSimplify: "${raw.slice(0, 40)}..." -> "${out}" (${Math.round(performance.now() - t0)} ms)`, 'model');
    return out;
  }

  return {
    state, on, log, boot,
    enterSpeechMode, exitSpeechMode,
    gemmaRewrite, simplifyTranscript,
    GLOSS_LEXICON,
  };
})();
