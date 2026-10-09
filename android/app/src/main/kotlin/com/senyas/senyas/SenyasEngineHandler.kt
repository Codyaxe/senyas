package com.senyas.senyas

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Channels between Dart and the native engine:
///   MethodChannel "senyas/engine"  — commands (boot, speech lifecycle, detecting)
///   EventChannel  "senyas/events"  — engine -> UI events
///   PlatformView  "senyas/signcam" — CameraX preview + landmark overlay
class SenyasEngineHandler(private val activity: FlutterActivity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var signView: SignCamView? = null
    private var recognizer: SpeechRecognizer? = null

    fun attach(engine: FlutterEngine) {
        methodChannel =
            MethodChannel(engine.dartExecutor.binaryMessenger, "senyas/engine")
        methodChannel?.setMethodCallHandler(this)
        eventChannel =
            EventChannel(engine.dartExecutor.binaryMessenger, "senyas/events")
        eventChannel?.setStreamHandler(this)
        engine.platformViewsController.registry.registerViewFactory(
            "senyas/signcam",
            SignCamViewFactory(activity, ::emit) { v -> signView = v })
    }

    fun detach() {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        signView?.shutdown()
        destroyRecognizer()
    }

    fun emit(map: Map<String, Any?>) {
        activity.runOnUiThread { eventSink?.success(map) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "boot" -> {
                emit(mapOf("type" to "log", "msg" to "native engine ready", "kind" to "model"))
                result.success(null)
            }
            "setDetecting" -> {
                signView?.setDetecting(call.argument<Boolean>("v") ?: true)
                result.success(null)
            }
            "stopSign" -> {
                signView?.setDetecting(false)
                result.success(null)
            }
            "loadSpeech" -> {
                activity.runOnUiThread { createRecognizer() }
                emit(mapOf("type" to "log", "msg" to "speech recognizer loaded", "kind" to "model"))
                result.success(null)
            }
            "startSpeech" -> {
                val lang = call.argument<String>("lang") ?: "fil-PH"
                activity.runOnUiThread { startListening(lang) }
                result.success(null)
            }
            "stopSpeech" -> {
                activity.runOnUiThread { recognizer?.stopListening() }
                result.success(null)
            }
            "unloadSpeech" -> {
                activity.runOnUiThread { destroyRecognizer() }
                emit(mapOf("type" to "log", "msg" to "speech recognizer unloaded", "kind" to "model"))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun createRecognizer() {
        if (recognizer != null) return
        try {
            recognizer =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(activity)
                }
            recognizer?.setRecognitionListener(SenyasRecognitionListener())
        } catch (e: Exception) {
            emit(mapOf("type" to "speechState", "state" to "fallback"))
        }
    }

    private fun destroyRecognizer() {
        recognizer?.destroy()
        recognizer = null
    }

    private fun startListening(lang: String) {
        try {
            createRecognizer()
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            recognizer?.startListening(intent)
            emit(mapOf("type" to "speechState", "state" to "listening"))
        } catch (e: Exception) {
            emit(mapOf("type" to "speechState", "state" to "error"))
        }
    }

    private inner class SenyasRecognitionListener : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}

        override fun onError(error: Int) {
            emit(mapOf("type" to "speechState", "state" to "idle"))
        }

        override fun onResults(results: Bundle?) {
            val texts = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val final = texts?.firstOrNull() ?: return
            emit(mapOf("type" to "transcript", "text" to final))
            emit(mapOf("type" to "speechState", "state" to "idle"))
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val texts = partialResults
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val partial = texts?.firstOrNull() ?: return
            emit(mapOf("type" to "interim", "text" to partial))
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }
}
