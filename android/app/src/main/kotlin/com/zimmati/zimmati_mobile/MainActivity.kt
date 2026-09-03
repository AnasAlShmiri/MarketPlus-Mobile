package com.zimmati.zimmati_mobile

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val feedbackChannel = "zimmati/feedback"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, feedbackChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanSuccess" -> {
                        playScanSuccessTone()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playScanSuccessTone() {
        val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 90)
        tone.startTone(ToneGenerator.TONE_PROP_BEEP, 130)
        Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 220)
    }
}
