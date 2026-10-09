# Senyas demo setup (offline)

## 1. Models (on the PC; once, with internet)

Already downloaded into `../models_staging/` (outside the repo, not committed):

| Model | Source | Size | Status |
|---|---|---|---|
| gemma3-1b (Cactus v1 format, INT8 + .scale) | Cactus catalog for plugin 1.3.0 | 642 MB zip | format matches plugin lib; **load on device NOT yet verified** |
| whisper-base INT8 | `huggingface.co/Cactus-Compute/whisper-base` `weights/whisper-base-int8.zip` (engine v1.12) | 99 MB zip | **likely incompatible** with plugin 1.3.0 lib (newer format, no .scale files); app falls back to Android on-device recognizer |

Gemma 4 E2B is **not used**: the cactus 1.3.0 Flutter plugin's native lib has no Gemma 4 model class
and its catalog has no Gemma 4. Running Gemma 4 requires building Cactus v2 (`cactus build --android`)
and raw FFI bindings — needs the Android NDK and is out of scope for the hackathon.

```bash
python tools/prepare_models.py ../models_staging   # -> ../models_staging/models/{gemma3-1b,whisper-base}
```

## 2. Install and push (needs Android SDK platform-tools)

```bash
flutter build apk --release          # release = no INTERNET permission (OS-enforced offline)
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.senyas.senyas/.MainActivity   # creates the external files dir; then close the app
adb push ../models_staging/models /sdcard/Android/data/com.senyas.senyas/files/
adb shell ls /sdcard/Android/data/com.senyas.senyas/files/models/gemma3-1b/config.txt
```

If `adb push` into `Android/data` is refused on the device, use a **debug** build and the internal dir:

```bash
adb push ../models_staging/models /data/local/tmp/senyas_models
adb shell run-as com.senyas.senyas sh -c 'mkdir -p app_flutter && cp -r /data/local/tmp/senyas_models app_flutter/models'
```

## 3. Pre-demo checklist

1. Airplane mode ON (Wi-Fi + data off).
2. Open the app → Sign Translation → wait for "Loading Gemma on-device…" to disappear.
3. Diagnostics (bottom of the screen) → `gemma_load` has a value, Models shows both paths (or whisper MISSING).
4. Tap `IKAW` `TULONG` → **Isalin** → the result label says "Gemma (on-device)".
5. Speech: tap the mic, speak, tap again → the card says which recognizer was used (`whisper-base (cactus)` or `android-on-device`).
   Android's on-device recognizer needs the Filipino/English offline speech pack installed in
   Settings → System → Languages → Speech (device-dependent; NEEDS VERIFICATION on the demo phone).
6. Note the Diagnostics numbers. These are the only latency/memory figures we can claim.
