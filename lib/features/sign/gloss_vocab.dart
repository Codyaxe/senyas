/// Demo vocabulary (21 glosses). 16 come from the Transactional FSL Dataset
/// classes (Mendeley jdyrr7cm4z v2, CC BY 4.0); the rest are basics used by the
/// live handshape demo. This is a fixed vocabulary — NOT general FSL recognition.
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
    Gloss('HELLO', 'Hello', 'Hello', '✋ open palm'),
    Gloss('IKAW', 'ikaw', 'you', '☝️ point'),
    Gloss('AKO', 'ako', 'me'),
    Gloss('SALAMAT', 'salamat', 'thank you', '✌️ peace'),
    Gloss('WALANG_ANUMAN', 'walang anuman', "you're welcome"),
    Gloss('OO', 'oo', 'yes'),
    Gloss('HINDI', 'hindi', 'no', '👎 thumbs down'),
    Gloss('MAGANDA', 'maganda', 'good', '👍 thumbs up'),
    Gloss('TULONG', 'tulong', 'help', '✊ fist'),
    Gloss('PAKI', 'pakiusap', 'please'),
    Gloss('SANDALI', 'sandali', 'wait'),
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

  static final byId = {for (final g in all) g.id: g};

  /// Keep only known glosses, uppercase, collapse immediate repeats, cap at 6.
  static List<String> normalize(Iterable<String> raw) {
    final out = <String>[];
    for (final r in raw) {
      final id = r.trim().toUpperCase().replaceAll(' ', '_');
      if (!byId.containsKey(id)) continue;
      if (out.isNotEmpty && out.last == id) continue;
      out.add(id);
    }
    return out.length > 6 ? out.sublist(out.length - 6) : out;
  }
}
