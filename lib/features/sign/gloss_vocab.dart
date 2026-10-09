import 'fsl105_vocab.dart';

/// Gloss vocabulary accepted by the router:
///  * FSL-105 (105 signs) — what the live SignTransformer recognizer outputs
///  * 21 demo/transactional glosses — tap-to-select chips and the optional
///    handshape demo mode (16 are Transactional FSL Dataset classes).
class Gloss {
  final String id; // canonical gloss passed to Gemma
  final String fil; // literal Filipino meaning (also rule-based fallback)
  final String en;
  final String? liveHint; // set if the live camera classifier can produce it
  const Gloss(this.id, this.fil, this.en, [this.liveHint]);
}

class GlossVocab {
  static const all = <Gloss>[
    Gloss('KAMUSTA', 'Kamusta', 'How are you', '👋 wave'),
    Gloss('SALAMAT', 'salamat', 'thank you', '🫱 B-hand'),
    Gloss('MAHAL_KITA', 'mahal kita', 'I love you', '🤟 ILY'),
    Gloss('IKAW', 'ikaw', 'you', '☝️ point'),
    Gloss('OO', 'oo', 'yes', '✊ S-fist'),
    Gloss('HINDI', 'hindi', 'no', '🤏 N-pinch'),
    Gloss('SANDALI', 'sandali', 'wait', '✋ open 5'),
    Gloss('DALAWA', 'dalawa', 'two', '✌️ V-hand'),
    Gloss('AKO', 'ako', 'me'),
    Gloss('HELLO', 'Hello', 'Hello'),
    Gloss('WALANG_ANUMAN', 'walang anuman', "you're welcome"),
    Gloss('MAGANDA', 'maganda', 'good'),
    Gloss('TULONG', 'tulong', 'help'),
    Gloss('PAKI', 'pakiusap', 'please'),
    Gloss('ULIT', 'ulit', 'again'),
    Gloss('PROBLEMA', 'problema', 'problem'),
    Gloss('MAGKANO', 'magkano', 'how much'),
    Gloss('ILAN', 'ilan', 'how many'),
    Gloss('CASH', 'cash', 'cash'),
    Gloss('CARD', 'card', 'card'),
    Gloss('BARYA', 'barya', 'coin'),
    Gloss('RESIBO', 'resibo', 'receipt'),
    Gloss('DISKWENTO', 'diskwento', 'discount'),
  ];

  /// FSL-105 recognizer outputs (English glosses; the rule fallback shows them as-is).
  static final fsl105 = [
    for (final (id, display, cat) in fsl105Glosses) Gloss(id, display, '$display ($cat)'),
  ];

  static final byId = {
    for (final g in fsl105) g.id: g,
    for (final g in all) g.id: g,
  };

  static String idOf(String raw) =>
      raw.trim().toUpperCase().replaceAll('\u2019', "'").replaceAll(' ', '_');

  /// Keep only known glosses, uppercase, collapse immediate repeats, cap at 6.
  static List<String> normalize(Iterable<String> raw) {
    final out = <String>[];
    for (final r in raw) {
      final id = idOf(r);
      if (!byId.containsKey(id)) continue;
      if (out.isNotEmpty && out.last == id) continue;
      out.add(id);
    }
    return out.length > 6 ? out.sublist(out.length - 6) : out;
  }
}
