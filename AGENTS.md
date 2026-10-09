# Senyas — agent notes

## Verify
- `flutter analyze` (must be clean)
- `flutter test` (router state-machine tests in `test/model_router_test.dart` use a fake backend)
- `flutter build web --release --no-wasm-dry-run` (guards that `dart:ffi`/cactus never leaks into the web graph)
- Android build needs the Android SDK (not installed on the original dev machine): `flutter build apk --release`

## Architecture
- `lib/features/inference/model_router.dart` — serialized router; all model ops go through `_serial`.
- `cactus_backend.dart` / `cactus_runtime.dart` import cactus FFI → only reachable via `router_factory_io.dart`.
  Never import them from shared code (breaks web build).
- `lib/engine/` — perception backends (Android Kotlin channels, web JS bridge, desktop sim) → call the router.
- Models are side-loaded, never downloaded: see `docs/DEMO_SETUP.md`.

## Verified facts (cactus pub 1.3.0)
- Native lib supports Gemma(3)/Qwen/LFM2/Whisper only — no Gemma 4. Fallback LLM: gemma3-1b.
- CactusLM/CactusSTT do network calls (Supabase lookup, auto-download, telemetry) → use CactusContext directly.
- Native lib contains a Supabase telemetry uploader; release manifest strips INTERNET (`tools:node="remove"`).
- Plugin's Whisper catalog (`rest/v1/whisper`) no longer exists; HF whisper-base-int8 is a newer weight format.
