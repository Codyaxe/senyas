// Senyas Speech Pipeline — real speech recognition where the browser supports it,
// typed fallback otherwise. Production mapping: AudioRecord -> cactusVad ->
// cactusTranscribe(whisper-small) -> Gemma simplify.
window.SenyasSpeech = (() => {
  const Engine = window.SenyasEngine;
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;

  let recog = null, active = false;
  const cb = {}; // onState, onInterim, onResult(transcript, simplified, lang)

  function supported() { return !!SR; }

  function detectLang(text) {
    const tl = /(po|ka|mo|ko|ang|ng|sa|ako|ikaw|kayo|salamat|kamusta|hindi|ano|saan|paki|naman|ba|lang)\b/i;
    return tl.test(text) ? 'Filipino' : 'English';
  }

  async function start() {
    await Engine.enterSpeechMode();
    if (!SR) { cb.onState && cb.onState('fallback'); return 'fallback'; }
    if (active) return 'listening';
    recog = new SR();
    recog.lang = 'fil-PH';
    recog.interimResults = true;
    recog.continuous = false;
    recog.onresult = e => {
      let interim = '', final = '';
      for (const r of e.results) {
        if (r.isFinal) final += r[0].transcript;
        else interim += r[0].transcript;
      }
      if (interim) cb.onInterim && cb.onInterim(interim);
      if (final) handleFinal(final.trim());
    };
    recog.onerror = e => {
      Engine.log('SpeechRecognition error: ' + e.error, 'error');
      cb.onState && cb.onState(e.error === 'not-allowed' ? 'mic-denied' : 'error');
      active = false;
    };
    recog.onend = () => {
      active = false;
      cb.onState && cb.onState('idle');
    };
    recog.start();
    active = true;
    Engine.log('VAD: listening for speech segment (browser STT in demo; on-device Whisper in production).', 'speech');
    cb.onState && cb.onState('listening');
    return 'listening';
  }

  function stop() {
    if (recog && active) { try { recog.stop(); } catch (_) {} }
    active = false;
    Engine.exitSpeechMode();
    cb.onState && cb.onState('idle');
  }

  function handleFinal(transcript) {
    if (!transcript) return;
    const lang = detectLang(transcript);
    Engine.log(`Transcript (${lang}): "${transcript}"`, 'speech');
    const simplified = Engine.simplifyTranscript(transcript);
    cb.onResult && cb.onResult(transcript, simplified, lang);
  }

  // Typed fallback path — same downstream pipeline
  function submitTyped(text) {
    Engine.enterSpeechMode();
    handleFinal(text);
    setTimeout(() => Engine.exitSpeechMode(), 800);
  }

  return { start, stop, submitTyped, supported, cb,
    get active() { return active; } };
})();
