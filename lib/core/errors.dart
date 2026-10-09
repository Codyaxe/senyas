/// Structured pipeline errors surfaced to the UI. Never swallowed silently.
enum SenyasErrorCode {
  modelMissing,
  modelIncompatible,
  sdkInitFailed,
  unsupported,
  modelLoadFailed,
  emptyAudio,
  transcriptionFailed,
  generationFailed,
  busy,
  cancelled,
  timeout,
  outOfMemory,
  permissionDenied,
}

class SenyasError implements Exception {
  final SenyasErrorCode code;
  final String message;
  final String? action; // what the user/operator can do next
  const SenyasError(this.code, this.message, {this.action});

  @override
  String toString() =>
      'SenyasError(${code.name}): $message${action != null ? ' — $action' : ''}';
}
