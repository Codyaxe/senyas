/// Events emitted by any SenyasEngine backend (sim / web / android-native).
class EngineEvent {
  final String type;
  final Map<String, dynamic> data;
  const EngineEvent(this.type, [this.data = const {}]);

  // Types
  static const router = 'router';       // {state, gemma}
  static const log = 'log';             // {msg, kind}
  static const status = 'status';       // {status, label}
  static const gloss = 'gloss';         // {gloss, phrase:[...]}
  static const prediction = 'prediction'; // {top:[{gloss,prob,cat}], ms, frames, committed}
  static const token = 'token';         // {ch} sign-flow streamed token
  static const signResult = 'signResult';   // {sentence, glosses, source, warning?}
  static const speechState = 'speechState'; // {state: listening|transcribing|idle|fallback|mic-denied|error}
  static const speechInterim = 'speechInterim'; // {text}
  static const speechToken = 'speechToken';     // {ch} simplify streamed token
  static const speechResult = 'speechResult';   // {raw, simplified, lang, source, recognizer, warning?}
  static const error = 'error';                 // {code, message, action?}
}
