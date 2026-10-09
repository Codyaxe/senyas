import 'dart:io' show ProcessInfo;
import 'package:flutter/foundation.dart';

/// One measured metric. `ms == null` means the value was not available
/// (never fabricated).
class Metric {
  final String name;
  final double? ms;
  final DateTime at;
  final String? note;
  Metric(this.name, this.ms, {this.note}) : at = DateTime.now();

  @override
  String toString() =>
      '$name: ${ms == null ? 'n/a' : '${ms!.toStringAsFixed(0)} ms'}${note != null ? ' ($note)' : ''}';
}

/// Minimal metrics store the UI can listen to.
class Metrics {
  static final latest = ValueNotifier<Map<String, Metric>>({});
  static final log = ValueNotifier<List<Metric>>([]);

  static void record(String name, double? ms, {String? note}) {
    final m = Metric(name, ms, note: note);
    latest.value = {...latest.value, name: m};
    final l = [m, ...log.value];
    log.value = l.length > 100 ? l.sublist(0, 100) : l;
    debugPrint('[metric] $m');
  }

  /// Total process RSS in MB (native + Dart heap + mapped model weights).
  /// This is NOT Dart heap usage. Unavailable on web.
  static final memoryMb = ValueNotifier<Map<String, double?>>({});

  static void recordMemory(String label) {
    double? mb;
    if (!kIsWeb) {
      try {
        mb = ProcessInfo.currentRss / (1024 * 1024);
      } catch (_) {}
    }
    memoryMb.value = {...memoryMb.value, label: mb};
    debugPrint('[memory] $label rss=${mb?.toStringAsFixed(0) ?? 'n/a'} MB');
  }

  /// Times an async op and records it, also on failure.
  static Future<T> time<T>(String name, Future<T> Function() op) async {
    final sw = Stopwatch()..start();
    try {
      final r = await op();
      record(name, sw.elapsedMicroseconds / 1000);
      return r;
    } catch (_) {
      record(name, sw.elapsedMicroseconds / 1000, note: 'failed');
      rethrow;
    }
  }
}
