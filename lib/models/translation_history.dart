enum TranslationType { sign, speech }

class TranslationHistoryItem {
  final String id;
  final TranslationType type;
  final String text;
  final String timestamp;
  final String? subtitle;

  const TranslationHistoryItem({
    required this.id,
    required this.type,
    required this.text,
    required this.timestamp,
    this.subtitle,
  });

  String get typeLabel =>
      type == TranslationType.sign ? 'Sign Translation' : 'Speech Translation';
}

/// Default mock history matching Figma node 32:288
final List<TranslationHistoryItem> defaultHistoryItems = [
  const TranslationHistoryItem(
    id: '1',
    type: TranslationType.sign,
    text: 'Kamusta Ka?',
    timestamp: '9:41 PM',
  ),
  const TranslationHistoryItem(
    id: '2',
    type: TranslationType.speech,
    text: 'Hello, nice to meet you po',
    timestamp: '9:40 PM',
  ),
  const TranslationHistoryItem(
    id: '3',
    type: TranslationType.sign,
    text: 'Salamat po.',
    timestamp: '9:11 PM',
  ),
  const TranslationHistoryItem(
    id: '4',
    type: TranslationType.speech,
    text: 'Punta lang po kayo sa unang kanto.',
    timestamp: '9:11 PM',
  ),
  const TranslationHistoryItem(
    id: '5',
    type: TranslationType.sign,
    text: 'Saang kanto po ang karinderya?',
    timestamp: '9:41 PM',
  ),
];
