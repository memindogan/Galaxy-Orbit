import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service providing unified, robust tactile feedback across mobile platforms.
///
/// On Android, Flutter's default [HapticFeedback] relies solely on
/// `View.performHapticFeedback`, which is silently suppressed if the user
/// has system touch sounds/haptics disabled, or on devices equipped with
/// basic ERM vibration motors.
///
/// [HapticService] communicates with the native Android [Vibrator] system
/// service configured with `AudioAttributes.USAGE_GAME`, guaranteeing crisp,
/// perceptible tactile responses for arcade gameplay regardless of system UI settings.
class HapticService {
  static const MethodChannel _channel =
      MethodChannel('com.neonorbit.neon_orbit/vibration');

  /// Quick tactile pulse for shooting / releasing the orb (~25ms).
  static Future<void> lightImpact() async {
    await _vibrate(
      durationMs: 25,
      amplitude: 140,
      fallback: HapticFeedback.lightImpact,
    );
  }

  /// Medium tactile pulse for latching / entering orbit (~45ms).
  static Future<void> mediumImpact() async {
    await _vibrate(
      durationMs: 45,
      amplitude: 200,
      fallback: HapticFeedback.mediumImpact,
    );
  }

  /// Strong tactile pulse for crash / orbit loss / level complete (~90ms).
  static Future<void> heavyImpact() async {
    await _vibrate(
      durationMs: 90,
      amplitude: 255,
      fallback: HapticFeedback.heavyImpact,
    );
  }

  /// Short crisp click for UI buttons / selections (~15ms).
  static Future<void> selectionClick() async {
    await _vibrate(
      durationMs: 15,
      amplitude: 100,
      fallback: HapticFeedback.selectionClick,
    );
  }

  /// Custom duration and amplitude vibration.
  static Future<void> vibrate({
    int durationMs = 60,
    int amplitude = 180,
  }) async {
    await _vibrate(
      durationMs: durationMs,
      amplitude: amplitude,
      fallback: HapticFeedback.vibrate,
    );
  }

  static Future<void> _vibrate({
    required int durationMs,
    required int amplitude,
    required Future<void> Function() fallback,
  }) async {
    if (kIsWeb) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('vibrate', {
          'duration': durationMs,
          'amplitude': amplitude,
        });
      } else {
        await fallback();
      }
    } catch (_) {
      try {
        await fallback();
      } catch (_) {}
    }
  }
}
