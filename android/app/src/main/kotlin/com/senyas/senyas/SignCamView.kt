package com.senyas.senyas

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.sign

/// PlatformView: CameraX preview (front cam) + MediaPipe HandLandmarker in
/// LIVE_STREAM mode + gesture classifier + phrase segmenter + overlay painter.
/// Emits gloss/status/phraseFlush events to Dart via the EventChannel sink.
class SignCamViewFactory(
    private val activity: FlutterActivity,
    private val emit: (Map<String, Any?>) -> Unit,
    private val onCreated: (SignCamView) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val v = SignCamView(activity, emit)
        onCreated(v)
        return v
    }
}

class SignCamView(
    private val activity: FlutterActivity,
    private val emit: (Map<String, Any?>) -> Unit,
) : PlatformView {

    private val root = FrameLayout(activity)
    private val previewView = PreviewView(activity)
    private val overlay = LandmarkOverlay(activity)
    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private var landmarker: HandLandmarker? = null

    @Volatile private var detecting = true

    // Segmenter state (mirrors sign_pipeline.js)
    private var pendingGesture: String? = null
    private var pendingSince = 0L
    private var lastCommitted: String? = null
    private var lastCommitAt = 0L
    private var noHandSince: Long? = null
    private var phraseActive = false
    private val wristTrail = ArrayDeque<Pair<Float, Long>>()

    companion object {
        const val HOLD_MS = 550L
        const val FLUSH_MS = 1500L
        const val RECOMMIT_MS = 900L
        val CONNECTIONS = arrayOf(
            0 to 1, 1 to 2, 2 to 3, 3 to 4, 0 to 5, 5 to 6, 6 to 7, 7 to 8,
            5 to 9, 9 to 10, 10 to 11, 11 to 12, 9 to 13, 13 to 14, 14 to 15,
            15 to 16, 13 to 17, 17 to 18, 18 to 19, 19 to 20, 0 to 17)
    }

    init {
        root.addView(previewView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT))
        root.addView(overlay,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT))
        initLandmarker()
        startCamera()
    }

    private fun initLandmarker() {
        try {
            val base = BaseOptions.builder()
                .setModelAssetPath("hand_landmarker.task")
                .build()
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(base)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(1)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener(::onLandmarks)
                .setErrorListener { e ->
                    emit(mapOf("type" to "log",
                        "msg" to "landmarker error: ${e.message}", "kind" to "error"))
                }
                .build()
            landmarker = HandLandmarker.createFromOptions(activity, options)
            emit(mapOf("type" to "log",
                "msg" to "HandLandmarker ready (asset, LIVE_STREAM)", "kind" to "model"))
        } catch (e: Exception) {
            emit(mapOf("type" to "log",
                "msg" to "landmarker init failed: ${e.message}", "kind" to "error"))
        }
    }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(activity)
        future.addListener({
            try {
                val provider = future.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(
                        ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                analysis.setAnalyzer(cameraExecutor) { proxy -> analyze(proxy) }
                provider.unbindAll()
                provider.bindToLifecycle(
                    activity as LifecycleOwner,
                    CameraSelector.DEFAULT_FRONT_CAMERA,
                    preview, analysis)
                emit(mapOf("type" to "log", "msg" to "CameraX started", "kind" to "vision"))
            } catch (e: Exception) {
                emit(mapOf("type" to "status", "status" to "camera-denied",
                    "label" to "Camera unavailable: ${e.message}"))
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    @androidx.annotation.OptIn(ExperimentalGetImage::class)
    private fun analyze(proxy: ImageProxy) {
        try {
            if (!detecting) return
            val lm = landmarker ?: return
            val bmp = proxy.toBitmap()
            val matrix = Matrix().apply {
                postRotate(proxy.imageInfo.rotationDegrees.toFloat())
            }
            val rotated = android.graphics.Bitmap.createBitmap(
                bmp, 0, 0, bmp.width, bmp.height, matrix, true)
            val mpImage = BitmapImageBuilder(rotated).build()
            lm.detectAsync(mpImage, proxy.imageInfo.timestamp / 1_000_000)
        } catch (_: Exception) {
        } finally {
            proxy.close()
        }
    }

    // ---- Landmark results -> classification -> segmentation ----

    private fun onLandmarks(result: HandLandmarkerResult, input: com.google.mediapipe.framework.image.MPImage) {
        val now = System.currentTimeMillis()
        val hands = result.landmarks()
        if (hands.isEmpty()) {
            activity.runOnUiThread { overlay.setLandmarks(null, null) }
            emit(mapOf("type" to "status", "status" to "no-hand",
                "label" to "No hand detected"))
            if (noHandSince == null) noHandSince = now
            pendingGesture = null
            if (phraseActive && now - noHandSince!! > FLUSH_MS) {
                phraseActive = false
                emit(mapOf("type" to "phraseFlush"))
            }
            return
        }
        noHandSince = null
        val lm = hands[0]
        wristTrail.addLast(lm[0].x() to now)
        while (wristTrail.size > 60) wristTrail.removeFirst()

        var gesture = classify(lm)
        if (gesture == "OPEN_PALM" && isWaving(now)) gesture = "WAVE"

        val label = gesture?.replace('_', ' ')
        activity.runOnUiThread { overlay.setLandmarks(lm, label) }
        emit(mapOf("type" to "status", "status" to "hand",
            "label" to (label?.let { "Sign: $it" } ?: "Hand Tracking Active")))

        if (gesture != null && gesture == pendingGesture) {
            if (now - pendingSince > HOLD_MS) commit(gesture, now)
        } else {
            pendingGesture = gesture
            pendingSince = now
        }
    }

    private fun commit(gesture: String, now: Long) {
        if (gesture == lastCommitted && now - lastCommitAt < RECOMMIT_MS) {
            pendingSince = now
            return
        }
        lastCommitted = gesture
        lastCommitAt = now
        val gloss = when (gesture) {
            "WAVE" -> "KAMUSTA"
            "OPEN_PALM" -> "HELLO"
            "THUMBS_UP" -> "MAGANDA"
            "THUMBS_DOWN" -> "HINDI"
            "INDEX_POINT" -> "IKAW"
            "PEACE" -> "SALAMAT"
            "FIST" -> "TULONG"
            else -> null
        } ?: return
        phraseActive = true
        emit(mapOf("type" to "gloss", "gloss" to gloss))
    }

    // ---- Gesture classification ----

    private fun dist(a: NormalizedLandmark, b: NormalizedLandmark) =
        hypot((a.x() - b.x()).toDouble(), (a.y() - b.y()).toDouble())

    private fun fingerExtended(lm: List<NormalizedLandmark>, tip: Int, pip: Int) =
        dist(lm[tip], lm[0]) > dist(lm[pip], lm[0]) * 1.12

    private fun classify(lm: List<NormalizedLandmark>): String? {
        val thumb = dist(lm[4], lm[17]) > dist(lm[3], lm[17]) * 1.05
        val index = fingerExtended(lm, 8, 6)
        val middle = fingerExtended(lm, 12, 10)
        val ring = fingerExtended(lm, 16, 14)
        val pinky = fingerExtended(lm, 20, 18)
        val n = (if (index) 1 else 0) + (if (middle) 1 else 0) +
                (if (ring) 1 else 0) + (if (pinky) 1 else 0)

        if (thumb && n == 0) {
            return if (lm[4].y() < lm[2].y() - 0.02f) "THUMBS_UP"
                   else if (lm[4].y() > lm[2].y() + 0.02f) "THUMBS_DOWN"
                   else "THUMBS_SIDE"
        }
        if (n == 4 && thumb) return "OPEN_PALM"
        if (n == 0 && !thumb) return "FIST"
        if (index && !middle && !ring && !pinky) return "INDEX_POINT"
        if (index && middle && !ring && !pinky) return "PEACE"
        return null
    }

    private fun isWaving(now: Long): Boolean {
        val cutoff = now - 900
        val pts = wristTrail.filter { it.second > cutoff }
        if (pts.size < 10) return false
        var reversals = 0
        var lastDir = 0
        var lastX = pts[0].first
        val xs = pts.map { it.first }
        val range = (xs.max() - xs.min())
        for (p in pts) {
            val dx = p.first - lastX
            if (abs(dx) > 0.008f) {
                val dir = sign(dx).toInt()
                if (lastDir != 0 && dir != lastDir) reversals++
                lastDir = dir
                lastX = p.first
            }
        }
        return reversals >= 3 && range > 0.08f
    }

    fun setDetecting(v: Boolean) { detecting = v }

    fun shutdown() {
        landmarker?.close()
        cameraExecutor.shutdown()
    }

    override fun getView(): View = root

    override fun dispose() = shutdown()

    // ---- Landmark overlay painter (mirrored for front camera) ----

    private class LandmarkOverlay(context: Context) : View(context) {
        private var landmarks: List<NormalizedLandmark>? = null
        private var label: String? = null
        private val linePaint = Paint().apply {
            color = Color.parseColor("#32D8B4")
            strokeWidth = 5f
            isAntiAlias = true
        }
        private val pointPaint = Paint().apply {
            color = Color.WHITE
            isAntiAlias = true
        }
        private val textPaint = Paint().apply {
            color = Color.parseColor("#32D8B4")
            textSize = 42f
            isAntiAlias = true
            isFakeBoldText = true
        }

        fun setLandmarks(lm: List<NormalizedLandmark>?, l: String?) {
            landmarks = lm
            label = l
            postInvalidate()
        }

        override fun onDraw(canvas: Canvas) {
            val lm = landmarks ?: return
            fun px(p: NormalizedLandmark) = (1f - p.x()) * width
            fun py(p: NormalizedLandmark) = p.y() * height
            for ((a, b) in CONNECTIONS) {
                canvas.drawLine(px(lm[a]), py(lm[a]), px(lm[b]), py(lm[b]), linePaint)
            }
            for (p in lm) canvas.drawCircle(px(p), py(p), 8f, pointPaint)
            label?.let {
                canvas.drawText(it, px(lm[0]) - 80, py(lm[0]) + 70, textPaint)
            }
        }
    }
}
