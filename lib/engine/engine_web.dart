import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import '../features/inference/pipeline.dart';
import 'engine_base.dart';
import 'engine_events.dart';

/// Flutter-web engine: drives the JS pipeline (real MediaPipe HandLandmarker +
/// Web Speech API) through SenyasBridge in web/senyas_bridge.js.
class WebEngine extends SenyasEngineApi {
  final JSObject _b;
  static bool _viewRegistered = false;

  WebEngine._(this._b) {
    final h = JSObject();
    h['onStatus'] = ((JSString s, JSString l) => emit(EngineEvent.status,
        {'status': s.toDart, 'label': l.toDart})).toJS;
    h['onGloss'] = ((JSString g, JSArray p) => emit(EngineEvent.gloss, {
          'gloss': g.toDart.isEmpty ? null : g.toDart,
          'phrase': p.toDart.map((e) => (e as JSString).toDart).toList(),
        })).toJS;
    h['onToken'] = ((JSString ch) =>
        emit(EngineEvent.token, {'ch': ch.toDart})).toJS;
    h['onSignResult'] = ((JSString s, JSArray seq) =>
        emit(EngineEvent.signResult, {
          'sentence': s.toDart,
          'glosses': seq.toDart.map((e) => (e as JSString).toDart).toList(),
        })).toJS;
    h['onSpeechState'] = ((JSString s) =>
        emit(EngineEvent.speechState, {'state': s.toDart})).toJS;
    h['onSpeechInterim'] = ((JSString t) =>
        emit(EngineEvent.speechInterim, {'text': t.toDart})).toJS;
    h['onSpeechResult'] = ((JSString r, JSString s, JSString l) =>
        emit(EngineEvent.speechResult, {
          'raw': r.toDart,
          'simplified': s.toDart,
          'lang': l.toDart,
        })).toJS;
    h['onRouter'] = ((JSString s) => emit(EngineEvent.log,
        {'msg': 'JS demo router: ${s.toDart} (simulated)', 'kind': 'router'})).toJS;
    h['onLog'] = ((JSString m, JSString k) =>
        emit(EngineEvent.log, {'msg': m.toDart, 'kind': k.toDart})).toJS;
    h['onPhrase'] = ((JSArray seq) {
      unawaited(translateGlosses(
          seq.toDart.map((e) => (e as JSString).toDart).toList()));
    }).toJS;
    // Chrome's Web Speech API streams audio to Google — NOT offline. Labeled.
    h['onTranscript'] = ((JSString t) {
      unawaited(simplifyAndEmit(t.toDart,
          recognizer: 'Chrome Web Speech (cloud, not offline)'));
    }).toJS;
    _b.callMethod('bind'.toJS, h);
    // Must exist before the first HtmlElementView('senyas-cam') is built.
    ensureCameraViewRegistered();
  }

  static bool isSupported() =>
      globalContext.hasProperty('SenyasBridge'.toJS).toDart;

  static WebEngine create() =>
      WebEngine._(globalContext['SenyasBridge'] as JSObject);

  @override
  bool get hasNativeCamera => true;
  @override
  String get cameraViewType => 'senyas-cam';

  void ensureCameraViewRegistered() {
    if (_viewRegistered) return;
    _viewRegistered = true;
    ui_web.platformViewRegistry.registerViewFactory('senyas-cam', (int id) {
      final div = web.document.createElement('div') as web.HTMLElement;
      _b.callMethod('mountCamera'.toJS, div);
      return div;
    });
  }

  @override
  Future<void> boot() async {
    await pipeline.boot();
    if (!pipeline.gemmaReady.value && pipeline.lastError.value != null) {
      emitError(pipeline.lastError.value!);
    }
  }

  @override
  Future<void> enterSignMode() async {
    ensureCameraViewRegistered();
    unawaited(boot()); // load Gemma 4 in parallel with the camera
    // Camera mounts when the HtmlElementView is built; retry briefly.
    for (var i = 0; i < 20; i++) {
      final ok = await (_b.callMethod('startSign'.toJS) as JSPromise).toDart;
      if ((ok as JSBoolean).toDart) return;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    emit(EngineEvent.log,
        {'msg': 'camera start timed out', 'kind': 'error'});
  }

  @override
  Future<void> exitSignMode() async => _b.callMethod('stopSign'.toJS);

  @override
  void setDetecting(bool v) =>
      _b.callMethod('setDetecting'.toJS, v.toJS);

  @override
  void flushPhrase() => _b.callMethod('manualFlush'.toJS);

  @override
  Future<void> startSpeech() async {
    unawaited(boot());
    globalContext['SenyasSpeechLang'] =
        (speechLang == 'en' ? 'en-US' : 'fil-PH').toJS;
    _b.callMethod('startSpeech'.toJS);
  }

  @override
  Future<void> stopSpeech() async => _b.callMethod('stopSpeech'.toJS);

  @override
  void submitTyped(String text) {
    if (text.trim().isEmpty) return;
    unawaited(boot().then((_) => simplifyAndEmit(text.trim(), recognizer: 'typed')));
  }

  @override
  void speak(String text) => _b.callMethod('speak'.toJS, text.toJS);
}
