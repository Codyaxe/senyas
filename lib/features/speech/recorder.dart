import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/errors.dart';

/// Push-to-talk recorder: 16 kHz mono PCM16 WAV (Whisper's expected input).
/// Audio stays in the app temp dir and is deleted after transcription.
class PushToTalkRecorder {
  final _rec = AudioRecorder();
  String? _path;
  DateTime? _startedAt;

  Future<void> start() async {
    if (!await _rec.hasPermission()) {
      throw const SenyasError(
          SenyasErrorCode.permissionDenied, 'Microphone permission denied',
          action: 'Allow microphone access in Settings');
    }
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/ptt_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(
          encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: _path!,
    );
    _startedAt = DateTime.now();
  }

  /// Returns (path, durationMs). Throws emptyAudio for < 0.4 s recordings.
  Future<(String, double)> stop() async {
    final path = await _rec.stop() ?? _path;
    final dur = _startedAt == null
        ? 0.0
        : DateTime.now().difference(_startedAt!).inMicroseconds / 1000;
    _startedAt = null;
    if (path == null || !await File(path).exists()) {
      throw const SenyasError(SenyasErrorCode.emptyAudio, 'No audio recorded');
    }
    // 44-byte WAV header + 0.4 s * 16k * 2 bytes
    if (dur < 400 || await File(path).length() < 44 + 12800) {
      await discard(path);
      throw const SenyasError(SenyasErrorCode.emptyAudio,
          'Recording too short', action: 'Hold to speak a little longer');
    }
    return (path, dur);
  }

  Future<void> cancel() async {
    try {
      await _rec.cancel();
    } catch (_) {}
    _startedAt = null;
  }

  Future<void> discard(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<bool> get isRecording => _rec.isRecording();
}
