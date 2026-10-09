import 'package:flutter/foundation.dart';
import '../speech/recorder.dart';
import 'cactus_backend.dart';
import 'model_router.dart';

/// Android: Cactus backend + push-to-talk recorder. Other IO platforms: no
/// on-device runtime (the cactus plugin ships arm64 Android/iOS libs only).
ModelRouter createRouter() => defaultTargetPlatform == TargetPlatform.android
    ? ModelRouter(backend: CactusBackend(), recorder: PushToTalkRecorder())
    : ModelRouter();
