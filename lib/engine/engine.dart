import 'package:flutter/material.dart';
import '../models/translation_history.dart';
import 'engine_base.dart';
import 'engine_factory_stub.dart'
    if (dart.library.js_interop) 'engine_factory_web.dart';

export 'engine_base.dart';
export 'engine_events.dart';
export 'mini_gemma.dart';

/// Global engine instance — one per app run.
final SenyasEngineApi senyas = createEngineImpl();

/// Session history (local only, per the privacy plan).
class HistoryStore {
  static final items = ValueNotifier<List<TranslationHistoryItem>>(
      List.of(defaultHistoryItems));

  static void add(TranslationType type, String text) {
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final p = now.period == DayPeriod.am ? 'AM' : 'PM';
    items.value = [
      TranslationHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        text: text,
        timestamp: '$h:$m $p',
      ),
      ...items.value,
    ];
  }
}
