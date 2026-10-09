package com.senyas.senyas

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var engineHandler: SenyasEngineHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engineHandler = SenyasEngineHandler(this)
        engineHandler?.attach(flutterEngine)
    }

    override fun onDestroy() {
        engineHandler?.detach()
        super.onDestroy()
    }
}
