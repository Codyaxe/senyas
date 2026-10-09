// ignore_for_file: implementation_imports
import 'package:cactus/models/types.dart';
import '../sign/gloss_vocab.dart';

/// Prompt v1. Short prompts + small token caps keep latency down.
/// Thinking mode: gemma3-1b has no thinking mode, and cactus 1.3.0 exposes no
/// thinking option, so nothing to disable. (Gemma 4 path: NEEDS VERIFICATION.)
class Prompts {
  static const version = 'v1';
  static const signMaxTokens = 40;
  static const simplifyMaxTokens = 96;

  static const _signSystem =
      'Ikaw ay tagasalin ng Filipino Sign Language (FSL) gloss tungo sa natural na Filipino.\n'
      'Mga patakaran:\n'
      '- Gamitin LAMANG ang kahulugan ng mga gloss na ibinigay. Huwag magdagdag ng bagong impormasyon.\n'
      '- Isang maikli at natural na pangungusap lamang.\n'
      '- Panatilihin ang pagkaapurahan (hal. TULONG).\n'
      '- Ibalik lamang ang pangungusap, walang paliwanag.\n'
      'Halimbawa:\n'
      'KAMUSTA IKAW -> Kamusta ka?\n'
      'MAGKANO CARD -> Magkano kung card ang gamit?\n'
      'AKO TULONG -> Tulungan mo ako!\n'
      'SALAMAT -> Salamat po.';

  static List<ChatMessage> sign(List<String> glosses) {
    final meanings = glosses
        .map((g) => '$g (${GlossVocab.byId[g]?.en ?? '?'})')
        .join(', ');
    return [
      ChatMessage(role: 'system', content: _signSystem),
      ChatMessage(
          role: 'user',
          content: 'Gloss: ${glosses.join(' ')}\nKahulugan: $meanings\nFilipino:'),
    ];
  }

  static const _simplifySystem =
      'Rewrite the transcript so a Deaf reader can understand it quickly.\n'
      '- Use short sentences and simple, common words.\n'
      '- Keep the same language: Filipino, English, or natural Taglish.\n'
      '- Keep names, numbers, dates, negation (hindi/not) and emergency words exactly.\n'
      '- Do not add information. Do not answer the transcript.\n'
      '- Output only the rewritten text.';

  static List<ChatMessage> simplify(String transcript) => [
        ChatMessage(role: 'system', content: _simplifySystem),
        ChatMessage(role: 'user', content: 'Transcript: $transcript'),
      ];

  /// Clean model output. Returns '' if nothing usable remains.
  static String clean(String raw) {
    var s = raw
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    s = s.replaceFirst(RegExp(r'^(Filipino|Rewritten|Output)\s*:\s*', caseSensitive: false), '');
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s.trim();
  }
}
