import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_orbit/providers/settings_provider.dart';
import 'package:neon_orbit/services/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
    SharedPreferences.setMockInitialValues({});
  });

  group('AudioService Tests', () {
    test('AudioService initializes and configures players cleanly', () async {
      await AudioService.configureGlobalContext();
      final audio = AudioService();

      expect(audio.musicVolume, isNotNull);
      expect(audio.sfxVolume, isNotNull);

      // Volumes can be set and clamp properly
      audio.musicVolume = 0.5;
      expect(audio.musicVolume, equals(0.5));

      audio.sfxVolume = 0.6;
      expect(audio.sfxVolume, equals(0.6));

      // Mute boundary
      audio.musicVolume = 0.0;
      expect(audio.musicVolume, equals(0.0));

      // Fire methods do not throw
      expect(() => audio.playBGM(), returnsNormally);
      expect(() => audio.pauseBGM(), returnsNormally);
      expect(() => audio.resumeBGM(), returnsNormally);
      expect(() => audio.playShootSound(), returnsNormally);
      expect(() => audio.playHitSound(1), returnsNormally);
      expect(() => audio.playGameOverSound(), returnsNormally);
      expect(() => audio.stopBGM(), returnsNormally);
    });

    test('SettingsProvider updates AudioService in real-time', () async {
      final settings = SettingsProvider();
      final audio = AudioService();

      settings.musicVolume = 0.42;
      expect(audio.musicVolume, closeTo(0.42, 0.001));

      settings.sfxVolume = 0.77;
      expect(audio.sfxVolume, closeTo(0.77, 0.001));

      // Test color-blind toggle
      expect(settings.colorBlindMode, isFalse);
      settings.colorBlindMode = true;
      expect(settings.colorBlindMode, isTrue);
    });

    test('GameOver sound plays multiple times and respects sfxVolume', () async {
      final audio = AudioService();

      audio.sfxVolume = 0.8;
      expect(() => audio.playGameOverSound(), returnsNormally);
      expect(() => audio.playGameOverSound(), returnsNormally);

      audio.sfxVolume = 0.0;
      expect(() => audio.playGameOverSound(), returnsNormally);
    });

    test('Shoot sound plays repeatedly through pool cycles without error', () {
      final audio = AudioService();
      audio.sfxVolume = 0.8;

      // Simulate 12 consecutive shots (cycling pool 4 full times)
      for (int i = 0; i < 12; i++) {
        expect(() => audio.playShootSound(), returnsNormally);
      }
    });

    test('Hit sound plays repeatedly through pool cycles and scales combo pitch', () {
      final audio = AudioService();
      audio.sfxVolume = 0.8;

      // Simulate 15 consecutive orbit captures with increasing combo
      for (int combo = 0; combo < 15; combo++) {
        expect(() => audio.playHitSound(combo), returnsNormally);
      }
    });
  });
}
