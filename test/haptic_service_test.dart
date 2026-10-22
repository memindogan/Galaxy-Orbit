import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_orbit/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticService Tests', () {
    final List<MethodCall> log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.neonorbit.neon_orbit/vibration'),
        (MethodCall methodCall) async {
          log.add(methodCall);
          return true;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.neonorbit.neon_orbit/vibration'),
        null,
      );
    });

    test('HapticService.lightImpact completes without throwing', () async {
      await expectLater(HapticService.lightImpact(), completes);
    });

    test('HapticService.mediumImpact completes without throwing', () async {
      await expectLater(HapticService.mediumImpact(), completes);
    });

    test('HapticService.heavyImpact completes without throwing', () async {
      await expectLater(HapticService.heavyImpact(), completes);
    });

    test('HapticService.selectionClick completes without throwing', () async {
      await expectLater(HapticService.selectionClick(), completes);
    });

    test('HapticService.vibrate completes without throwing', () async {
      await expectLater(HapticService.vibrate(durationMs: 50, amplitude: 200), completes);
    });
  });
}
