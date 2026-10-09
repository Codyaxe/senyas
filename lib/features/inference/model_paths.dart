import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Local model locations. Models are side-loaded before the demo (see
/// docs/DEMO_SETUP.md); nothing is downloaded at runtime.
///
/// Search order (first dir containing config.txt wins):
///  1. external app-specific dir — adb-pushable, works for release builds:
///     /sdcard/Android/data/com.senyas.senyas/files/models/<model>
///  2. internal docs dir (debug builds via `run-as`):
///     /data/user/0/com.senyas.senyas/app_flutter/models/<model>
///
/// Gemma 4 E2B is the intended model but is NOT loadable by the bundled
/// cactus 1.3.0 native lib (no Gemma 4 model class) — gemma3-1b is the
/// documented fallback running through the same Cactus runtime.
class ModelPaths {
  static const gemmaDir = 'gemma3-1b';
  static const whisperDir = 'whisper-base';

  static Future<List<String>> roots() async {
    final out = <String>[];
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) out.add('${ext.path}/models');
    } catch (_) {}
    out.add('${(await getApplicationDocumentsDirectory()).path}/models');
    return out;
  }

  static Future<String> _resolve(String name) async {
    final rs = await roots();
    for (final r in rs) {
      if (await isPresent('$r/$name')) return '$r/$name';
    }
    return '${rs.first}/$name'; // expected location, for error messages
  }

  static Future<String> gemma() => _resolve(gemmaDir);
  static Future<String> whisper() => _resolve(whisperDir);

  static Future<bool> isPresent(String dir) =>
      File('$dir/config.txt').exists();

  /// Startup readiness check for UI/debug display.
  static Future<Map<String, Object>> readiness() async {
    final g = await gemma(), w = await whisper();
    return {
      'gemma': await isPresent(g) ? g : 'MISSING ($g)',
      'whisper': await isPresent(w) ? w : 'MISSING ($w)',
    };
  }
}
