// SenyasBridge — façade over the JS pipelines for the Flutter web engine.
// Flutter calls these via dart:js_interop; events flow back through the bound handler object.
window.SenyasBridge = (() => {
  let handlers = {};
  let video = null, canvas = null;

  function cb(name, ...args) {
    if (handlers && typeof handlers[name] === 'function') handlers[name](...args);
  }

  function bind(h) { handlers = h || {}; }

  function mountCamera(container) {
    container.style.position = 'relative';
    container.style.overflow = 'hidden';
    video = document.createElement('video');
    video.autoplay = true; video.playsInline = true; video.muted = true;
    canvas = document.createElement('canvas');
    for (const el of [video, canvas]) {
      el.style.position = 'absolute';
      el.style.inset = '0';
      el.style.width = '100%';
      el.style.height = '100%';
      el.style.objectFit = 'cover';
      el.style.transform = 'scaleX(-1)';
      el.style.pointerEvents = 'none';
    }
    container.appendChild(video);
    container.appendChild(canvas);
  }

  async function startSign() {
    if (!video) return false;
    await SenyasEngine.boot();
    return SenyasSign.start(video, canvas);
  }
  function stopSign() { SenyasSign.stop(); }
  function setDetecting(v) { SenyasSign.setDetecting(v); }
  function manualFlush() { SenyasSign.manualFlush(); }

  function startSpeech() { return SenyasSpeech.start(); }
  function stopSpeech() { SenyasSpeech.stop(); }
  function submitTyped(t) { SenyasSpeech.submitTyped(t); }
  function speak(t) {
    const u = new SpeechSynthesisUtterance(t);
    u.lang = 'fil-PH';
    speechSynthesis.speak(u);
  }
  function routerState() { return SenyasEngine.state.router; }

  // Wire pipeline callbacks -> Dart handlers
  SenyasSign.cb.onStatus = (s, l) => cb('onStatus', s, l || '');
  SenyasSign.cb.onGloss = (g, p) => cb('onGloss', g || '', p || []);
  SenyasSign.cb.onToken = ch => cb('onToken', ch);
  SenyasSign.cb.onResult = (s, seq) => cb('onSignResult', s, seq || []);

  SenyasSpeech.cb.onState = s => cb('onSpeechState', s);
  SenyasSpeech.cb.onInterim = t => cb('onSpeechInterim', t);
  SenyasSpeech.cb.onResult = (r, s, l) => cb('onSpeechResult', r, s, l);

  SenyasEngine.on('router', d => cb('onRouter', d.next));
  SenyasEngine.on('log', e => cb('onLog', e.msg, e.kind));

  return {
    bind, mountCamera, startSign, stopSign, setDetecting, manualFlush,
    startSpeech, stopSpeech, submitTyped, speak, routerState,
  };
})();
