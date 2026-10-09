import 'package:flutter/foundation.dart';
import 'engine_base.dart';
import 'engine_io.dart';
import 'sim_engine.dart';

/// IO platforms: real native engine on Android, simulator elsewhere.
SenyasEngineApi createEngineImpl() {
  if (defaultTargetPlatform == TargetPlatform.android) return IoEngine();
  return SimEngine();
}
