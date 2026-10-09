import 'package:flutter/foundation.dart';

/// App-wide demo mode: when ON, the sign screen shows the 7-handshape
/// gesture cheat sheet and a clear demo disclaimer, and the web pipeline
/// also runs the static-handshape heuristic. OFF (default) = the real
/// FSL-105 recognizer path only.
class SenyasSettings {
  SenyasSettings._();
  static final demoMode = ValueNotifier<bool>(false);
  static final tapToGloss = ValueNotifier<bool>(false);

  /// Honest scope label shown on the sign screen (always visible).
  static const recognitionScope =
      'Isolated FSL signs · 105-sign vocabulary · still experimental';
}
