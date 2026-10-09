import 'dart:async';
import 'package:cactus/models/types.dart' show ChatMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:senyas/core/errors.dart';
import 'package:senyas/features/inference/inference_backend.dart';
import 'package:senyas/features/inference/model_router.dart';
import 'package:senyas/features/speech/recorder.dart';

class FakeBackend implements InferenceBackend {
  final ops = <String>[];
  int active = 0, maxActive = 0;
  bool failLm = false, failStt = false, failComplete = false;
  String transcript = 'Kailangan ko po ng tulong, ang bahay ay nasa 123 Rizal St.';
  Completer<void>? sttGate; // when set, loadStt waits on it
  bool _lm = false, _stt = false;

  Future<T> _op<T>(String name, Future<T> Function() f) async {
    active++;
    maxActive = active > maxActive ? active : maxActive;
    ops.add(name);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return await f();
    } finally {
      active--;
    }
  }

  @override
  bool get lmLoaded => _lm;
  @override
  bool get sttLoaded => _stt;

  @override
  Future<void> loadLm() => _op('loadLm', () async {
        if (failLm) throw const SenyasError(SenyasErrorCode.modelLoadFailed, 'lm');
        _lm = true;
      });

  @override
  Future<String> complete(List<ChatMessage> messages,
          {required int maxTokens, void Function(String)? onToken}) =>
      _op('complete', () async {
        if (failComplete) throw const SenyasError(SenyasErrorCode.generationFailed, 'x');
        onToken?.call('Out');
        onToken?.call('put');
        return 'Output';
      });

  @override
  Future<bool> sttPresent() async => true;

  @override
  Future<void> loadStt() => _op('loadStt', () async {
        if (sttGate != null) await sttGate!.future;
        if (failStt) throw const SenyasError(SenyasErrorCode.modelLoadFailed, 'stt');
        _stt = true;
      });

  @override
  Future<String> transcribe(String wavPath, String lang) =>
      _op('transcribe', () async => transcript);

  @override
  Future<void> unloadStt() => _op('unloadStt', () async => _stt = false);
}

class FakeRecorder implements PushToTalkRecorder {
  bool recording = false, cancelled = false;
  @override
  Future<void> start() async => recording = true;
  @override
  Future<(String, double)> stop() async {
    recording = false;
    return ('/tmp/a.wav', 1500.0);
  }

  @override
  Future<void> cancel() async {
    recording = false;
    cancelled = true;
  }

  @override
  Future<void> discard(String path) async {}
  @override
  Future<bool> get isRecording async => recording;
}

void main() {
  late FakeBackend b;
  late FakeRecorder rec;
  late ModelRouter r;

  setUp(() {
    b = FakeBackend();
    rec = FakeRecorder();
    r = ModelRouter(backend: b, recorder: rec);
  });

  test('boot loads Gemma exactly once under concurrent calls', () async {
    await Future.wait([r.boot(), r.boot(), r.boot()]);
    expect(b.ops.where((o) => o == 'loadLm').length, 1);
    expect(r.gemmaReady.value, isTrue);
    expect(r.state.value, RouterState.sign);
  });

  test('Gemma load failure degrades sign flow to labeled rule fallback', () async {
    b.failLm = true;
    await r.boot();
    expect(r.gemmaReady.value, isFalse);
    final res = await r.translateGlosses(['IKAW', 'TULONG']);
    expect(res.source, TextSource.ruleFallback);
    expect(res.warning, isNotNull);
    expect(res.text, 'Ikaw tulong.');
  });

  test('sign flow normalizes glosses and streams Gemma output', () async {
    await r.boot();
    final tokens = <String>[];
    final res = await r.translateGlosses(['ikaw', 'IKAW', 'BOGUS', 'tulong'],
        onToken: tokens.add);
    expect(res.input, 'IKAW TULONG');
    expect(res.source, TextSource.gemma);
    expect(tokens, ['Out', 'put']);
  });

  test('no valid glosses is a reported error, not fabricated text', () async {
    await r.boot();
    expect(() => r.translateGlosses(['BOGUS']), throwsA(isA<SenyasError>()));
  });

  test('speech turn: load -> transcribe -> unload -> simplify, serialized', () async {
    await r.boot();
    await r.startSpeech();
    expect(r.state.value, RouterState.recording);
    final res = await r.finishSpeech();
    expect(res.source, TextSource.gemma);
    expect(res.input, b.transcript);
    final speechOps = b.ops.skip(1).toList();
    expect(speechOps, ['loadStt', 'transcribe', 'unloadStt', 'complete']);
    expect(b.sttLoaded, isFalse);
    expect(b.maxActive, 1);
    expect(r.state.value, RouterState.sign);
  });

  test('Whisper load failure is reported and does not break sign flow', () async {
    await r.boot();
    b.failStt = true;
    await r.startSpeech();
    await expectLater(r.finishSpeech(), throwsA(isA<SenyasError>()));
    expect(r.whisperUsable, isFalse);
    expect(r.state.value, RouterState.sign);
    expect(await r.canUseWhisper(), isFalse);
    final res = await r.translateGlosses(['SALAMAT']);
    expect(res.source, TextSource.gemma);
  });

  test('cancel during Whisper load: in-flight load is destroyed after it finishes',
      () async {
    await r.boot();
    b.sttGate = Completer<void>();
    await r.startSpeech();
    final cancel = r.cancelSpeech();
    b.sttGate!.complete();
    await cancel;
    expect(rec.cancelled, isTrue);
    expect(b.sttLoaded, isFalse);
    expect(b.ops.last, 'unloadStt');
    expect(r.state.value, RouterState.sign);
  });

  test('repeated mic press during a turn is rejected as busy', () async {
    await r.boot();
    await r.startSpeech();
    await expectLater(
        r.startSpeech(),
        throwsA(isA<SenyasError>()
            .having((e) => e.code, 'code', SenyasErrorCode.busy)));
    await r.cancelSpeech();
  });

  test('sign translation during a speech turn is rejected as busy', () async {
    await r.boot();
    await r.startSpeech();
    await expectLater(r.translateGlosses(['OO']), throwsA(isA<SenyasError>()));
    await r.cancelSpeech();
  });

  test('empty transcript -> emptyAudio error, Whisper still unloaded', () async {
    await r.boot();
    b.transcript = '   ';
    await r.startSpeech();
    await expectLater(
        r.finishSpeech(),
        throwsA(isA<SenyasError>()
            .having((e) => e.code, 'code', SenyasErrorCode.emptyAudio)));
    expect(b.sttLoaded, isFalse);
  });

  test('simplify failure returns the raw transcript, clearly labeled', () async {
    await r.boot();
    b.failComplete = true;
    await r.startSpeech();
    final res = await r.finishSpeech();
    expect(res.source, TextSource.rawTranscript);
    expect(res.text, b.transcript);
    expect(res.warning, isNotNull);
  });

  test('no runtime (web/desktop): rule fallback, speech path unavailable', () async {
    final none = ModelRouter();
    await none.boot();
    expect(await none.canUseWhisper(), isFalse);
    final res = await none.translateGlosses(['KAMUSTA', 'IKAW']);
    expect(res.source, TextSource.ruleFallback);
  });
}
