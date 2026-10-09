import 'package:cactus/models/types.dart';

/// What the router needs from an inference runtime. Lets tests inject a fake.
abstract class InferenceBackend {
  Future<void> loadLm();
  bool get lmLoaded;
  Future<String> complete(List<ChatMessage> messages,
      {required int maxTokens, void Function(String)? onToken});

  Future<void> loadStt();
  bool get sttLoaded;
  Future<String> transcribe(String wavPath, String lang);
  Future<void> unloadStt();

  /// Whether the STT model artifact exists locally (cheap check).
  Future<bool> sttPresent();
}
