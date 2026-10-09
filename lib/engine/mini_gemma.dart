import 'dart:async';

/// Deterministic stand-in for Gemma-4-E2B (gloss -> Filipino + deaf-reader simplify).
/// Production: cactusComplete() with the few-shot system prompts from the plan.
class MiniGemma {
  static const Map<String, GlossEntry> lexicon = {
    'KAMUSTA': GlossEntry(fil: 'Kamusta ka!', en: 'Hello / How are you', hint: '👋 Wave'),
    'HELLO': GlossEntry(fil: 'Hello po!', en: 'Hello (polite)', hint: '👋 Hello'),
    'SALAMAT': GlossEntry(fil: 'Salamat po!', en: 'Thank you', hint: '🫱 Flat B-hand'),
    'THANK YOU': GlossEntry(fil: 'Salamat po!', en: 'Thank you', hint: '🫱 Flat B-hand'),
    'MAHAL_KITA': GlossEntry(fil: 'Mahal kita!', en: 'I love you', hint: '🤟 ILY sign'),
    'MAHAL KITA': GlossEntry(fil: 'Mahal kita!', en: 'I love you', hint: '🤟 ILY sign'),
    'IKAW': GlossEntry(fil: 'Ikaw', en: 'You', hint: '☝️ Point forward'),
    'YOU': GlossEntry(fil: 'Ikaw', en: 'You', hint: '☝️ Point forward'),
    'OO': GlossEntry(fil: 'Opo!', en: 'Yes', hint: '✊ S-fist'),
    'YES': GlossEntry(fil: 'Opo!', en: 'Yes', hint: '✊ S-fist'),
    'HINDI': GlossEntry(fil: 'Hindi po.', en: 'No / Not', hint: '🤏 N-pinch'),
    'NO': GlossEntry(fil: 'Hindi po.', en: 'No / Not', hint: '🤏 N-pinch'),
    'SANDALI': GlossEntry(fil: 'Sandali lang po.', en: 'Wait / Hold on', hint: '✋ Open 5-palm'),
    'WAIT': GlossEntry(fil: 'Sandali lang po.', en: 'Wait / Hold on', hint: '✋ Open 5-palm'),
    'DALAWA': GlossEntry(fil: 'Dalawa', en: 'Two', hint: '✌️ V-hand'),
    'TWO': GlossEntry(fil: 'Dalawa', en: 'Two', hint: '✌️ V-hand'),
    'ONE': GlossEntry(fil: 'Isa', en: 'One', hint: '☝️ One'),
    'GOOD MORNING': GlossEntry(fil: 'Magandang umaga po!', en: 'Good morning', hint: '🌅 Morning'),
    'GOOD AFTERNOON': GlossEntry(fil: 'Magandang hapon po!', en: 'Good afternoon', hint: '☀️ Afternoon'),
    'GOOD EVENING': GlossEntry(fil: 'Magandang gabi po!', en: 'Good evening', hint: '🌙 Evening'),
    'HOW ARE YOU': GlossEntry(fil: 'Kamusta ka?', en: 'How are you', hint: '❓ How are you'),
    'IM FINE': GlossEntry(fil: 'Mabuti naman po ako.', en: "I'm fine", hint: '😊 Fine'),
    'NICE TO MEET YOU': GlossEntry(fil: 'Ikinagagalak kitang makilala.', en: 'Nice to meet you', hint: '🤝 Meet'),
    'MAGANDA': GlossEntry(fil: 'Maganda!', en: 'Good / Beautiful', hint: '✨ Maganda'),
    'TULONG': GlossEntry(fil: 'Tulong po!', en: 'Help!', hint: '🤲 Tulong'),
    'HELP': GlossEntry(fil: 'Tulong po!', en: 'Help!', hint: '🤲 Tulong'),
    'AKO': GlossEntry(fil: 'Ako', en: 'Me / I', hint: '👉 Ako'),
  };

  static const _phraseRules = <List<String>, String>{
    ['KAMUSTA', 'IKAW']: 'Kamusta ka?',
    ['HELLO', 'IKAW']: 'Kamusta ka?',
    ['HOW ARE YOU']: 'Kamusta ka?',
    ['IKAW', 'MAHAL_KITA']: 'Mahal kita!',
    ['MAHAL_KITA', 'IKAW']: 'Mahal kita!',
    ['IKAW', 'MAHAL KITA']: 'Mahal kita!',
    ['SALAMAT', 'IKAW']: 'Salamat sa iyo!',
    ['THANK YOU', 'YOU']: 'Salamat sa iyo!',
    ['THANK YOU', 'IKAW']: 'Salamat sa iyo!',
    ['IKAW', 'SALAMAT']: 'Salamat sa iyo!',
    ['OO', 'SALAMAT']: 'Opo, salamat po!',
    ['YES', 'THANK YOU']: 'Opo, salamat po!',
    ['HINDI', 'SALAMAT']: 'Hindi po, salamat.',
    ['NO', 'THANK YOU']: 'Hindi po, salamat.',
    ['SANDALI', 'IKAW']: 'Sandali lang, ikaw muna.',
    ['WAIT', 'YOU']: 'Sandali lang po.',
    ['IKAW', 'TULONG']: 'Tulungan mo ako.',
    ['TULONG', 'IKAW']: 'Kailangan ko ng tulong mo!',
    ['HELP', 'YOU']: 'Kailangan ko ng tulong mo!',
    ['KAMUSTA', 'SALAMAT']: 'Kamusta! Salamat po!',
    ['GOOD MORNING', 'HOW ARE YOU']: 'Magandang umaga! Kamusta ka?',
  };

  /// Streams the rewritten sentence through [onToken], returns full text.
  static Future<String> rewrite(List<String> glosses,
      {void Function(String ch)? onToken}) async {
    if (glosses.isEmpty) return '';
    final normalized = glosses.map((g) => g.trim().toUpperCase()).toList();
    
    // Check phrase rules
    String out = '';
    for (final entry in _phraseRules.entries) {
      if (_seqEq(entry.key, normalized)) {
        out = entry.value;
        break;
      }
    }

    if (out.isEmpty) {
      // Per-gloss lookup or fallback
      final translated = normalized.map((g) {
        if (lexicon.containsKey(g)) return lexicon[g]!.fil;
        final cleanKey = g.replaceAll(' ', '_');
        if (lexicon.containsKey(cleanKey)) return lexicon[cleanKey]!.fil;
        return g.toLowerCase();
      }).toList();
      out = translated.join(' ');
      if (out.isNotEmpty) {
        out = out[0].toUpperCase() + out.substring(1);
      }
    }

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
