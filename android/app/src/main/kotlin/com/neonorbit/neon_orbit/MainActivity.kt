package com.neonorbit.neon_orbit

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VIBRATION_CHANNEL = "com.neonorbit.neon_orbit/vibration"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.defaultFocusHighlightEnabled = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                val modes = currentDisplay?.supportedModes
                val maxMode = modes?.maxByOrNull { it.refreshRate }
                if (maxMode != null && maxMode.refreshRate > 60f) {
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    window.attributes = params
                }
            } catch (e: Exception) {
                // Safely ignore if vendor display mode selection fails
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBRATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    val duration = (call.argument<Int>("duration") ?: 40).toLong()
                    val amplitude = call.argument<Int>("amplitude") ?: -1
                    triggerVibration(duration, amplitude)
                    result.success(true)
                }
                "hasVibrator" -> {
                    val vibrator = getVibrator()
                    result.success(vibrator?.hasVibrator() == true)
                }
                "cancel" -> {
                    try {
                        getVibrator()?.cancel()
                    } catch (e: Exception) {
                        // ignore
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getVibrator(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun triggerVibration(durationMs: Long, amplitude: Int) {
        try {
            val vibrator = getVibrator() ?: return
            if (!vibrator.hasVibrator()) return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val clampedAmp = if (amplitude in 1..255) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
                val effect = if (vibrator.hasAmplitudeControl() && clampedAmp != VibrationEffect.DEFAULT_AMPLITUDE) {
                    VibrationEffect.createOneShot(durationMs, clampedAmp)
                } else {
                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                }
                try {
                    val attributes = AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .build()
                    vibrator.vibrate(effect, attributes)
                } catch (e: Exception) {
                    vibrator.vibrate(effect)
                }
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        } catch (e: Exception) {
            // Safely ignore to prevent crashes
        }
    }
}
