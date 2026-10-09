import 'dart:async';

/// Deterministic stand-in for Gemma-4-E2B (gloss -> Filipino + deaf-reader simplify).
/// Production: cactusComplete() with the few-shot system prompts from the plan.
class MiniGemma {
  static const Map<String, GlossEntry> lexicon = {
    'KAMUSTA': GlossEntry(fil: 'Kamusta ka!', en: 'Hello / How are you', hint: '👋 Wave'),
    'HELLO': GlossEntry(fil: 'Hello po!', en: 'Hello (polite)', hint: '✋ Open palm'),
    'MAGANDA': GlossEntry(fil: 'Maganda!', en: 'Good / Beautiful', hint: '👍 Thumbs up'),
    'HINDI': GlossEntry(fil: 'Hindi po.', en: 'No / Not', hint: '👎 Thumbs down'),
    'IKAW': GlossEntry(fil: 'Ikaw', en: 'You', hint: '☝️ Point index'),
    'SALAMAT': GlossEntry(fil: 'Salamat po!', en: 'Thank you', hint: '✌️ Peace sign'),
    'TULONG': GlossEntry(fil: 'Tulong!', en: 'Help!', hint: '✊ Fist'),
  };

  static const _phraseRules = <List<String>, String>{
    ['KAMUSTA', 'IKAW']: 'Kamusta ka?',
    ['IKAW', 'MAGANDA']: 'Maganda ka!',
    ['MAGANDA', 'IKAW']: 'Maganda ka!',
    ['SALAMAT', 'IKAW']: 'Salamat sa iyo!',
    ['IKAW', 'TULONG']: 'Tulungan mo ako.',
    ['TULONG', 'IKAW']: 'Kailangan ko ng tulong mo!',
    ['KAMUSTA', 'SALAMAT']: 'Kamusta! Salamat po!',
  };

  /// Streams the rewritten sentence through [onToken], returns full text.
  static Future<String> rewrite(List<String> glosses,
      {void Function(String ch)? onToken}) async {
    final seq = glosses.where(lexicon.containsKey).toList();
    if (seq.isEmpty) return '';
    final out = _phraseRules.entries
            .firstWhere(
              (e) => _seqEq(e.key, seq),
              orElse: () => const MapEntry([], ''),
            )
            .value
            .ifEmpty(seq.map((g) => lexicon[g]!.fil).join(' '));
    await Future.delayed(Duration(milliseconds: 220 + (out.length * 3)));
    if (onToken != null) {
      for (final ch in out.split('')) {
        onToken(ch);
        await Future.delayed(const Duration(milliseconds: 8));
      }
    }
    return out;
  }

  static final _fillers = RegExp(
      r'\b(um+|uh+|like|you know|actually|basically|literally|nga|kasi|parang|ano ba)\b',
      caseSensitive: false);
  static const _simpleMap = {
    'approximately': 'about', 'immediately': 'now', 'purchase': 'buy',
    'assistance': 'help', 'information': 'info', 'difficult': 'hard',
    'require': 'need', 'commence': 'start', 'sufficient': 'enough',
    'additional': 'more', 'utilize': 'use', 'endeavor': 'try',
  };

  /// Deaf-reader simplification: short sentences, plain vocabulary.
  static String simplify(String raw) {
    var text = ' ${raw.trim()} '.replaceAll(_fillers, ' ');
    _simpleMap.forEach((k, v) {
      text = text.replaceAll(RegExp('\\b$k\\b', caseSensitive: false), v);
    });
    final clauses = text
        .split(RegExp(r'[,;]|\.\s+| but | however | because | so that | and then ',
            caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.length > 1);
    final body = clauses.map((s) {
      final words = s.split(RegExp(r'\s+'));
      final t = words.take(12).join(' ');
      return t[0].toUpperCase() + t.substring(1);
    }).join('. ');
    return '${body.replaceAll(RegExp(r'\.+$'), '')}.';
  }

  static bool _seqEq(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);
}

class GlossEntry {
  final String fil, en, hint;
  const GlossEntry({required this.fil, required this.en, required this.hint});
}

extension _IfEmpty on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
