import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neon_orbit/engine/game_engine.dart';
import 'package:neon_orbit/providers/game_state_provider.dart';
import 'package:neon_orbit/providers/settings_provider.dart';
import 'package:neon_orbit/screens/game_screen.dart';
import 'package:neon_orbit/screens/game_modals.dart';

void main() {
  testWidgets('GameScreen correctly displays full-screen OrbitLostModal when game over triggers', (WidgetTester tester) async {
    final gameState = GameStateProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<GameStateProvider>.value(value: gameState),
        ],
        child: const MaterialApp(
          home: GameScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Force player to launch out of bounds
    final eng = gameState.engine;
    eng.player.isOrbiting = false;
    eng.player.vx = -1200.0;
    eng.player.vy = 0.0;

    // Pump frames so physics tick detects out of bounds
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (eng.phase == GamePhase.gameOver) break;
    }

    expect(eng.phase, equals(GamePhase.gameOver));

    // Pump modal entrance animation
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Verify OrbitLostModal exists and has full-screen dimensions (800x600 in test)
    final modalFinder = find.byType(OrbitLostModal);
    expect(modalFinder, findsOneWidget);

    final modalBox = tester.getRect(modalFinder);
    expect(modalBox.width, equals(800.0));
    expect(modalBox.height, equals(600.0));

    // Verify modal contents
    expect(find.text('ORBIT LOST'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('MENU'), findsOneWidget);

    // Verify RETRY button restarts the game
    final retryBtn = find.text('RETRY');
    await tester.tap(retryBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(eng.phase, equals(GamePhase.playing));
    expect(eng.player.isOrbiting, isTrue);
  });

  testWidgets('GameScreen seamlessly displays floating level complete banner without pausing gameplay', (WidgetTester tester) async {
    final gameState = GameStateProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<GameStateProvider>.value(value: gameState),
        ],
        child: const MaterialApp(
          home: GameScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final eng = gameState.engine;
    expect(eng.phase, equals(GamePhase.playing));
    expect(eng.currentLevel, equals(1));

    // Simulate completing all captures for level 1
    eng.capturesInLevel = eng.totalCapturesInLevel - 1;
    // Trigger attach to next planet which completes the level
    eng.onLevelComplete?.call(1, 120);

    // Verify game continues playing uninterrupted without pausing
    expect(eng.phase, equals(GamePhase.playing));
    expect(find.byType(LevelCompleteModal), findsNothing);

    // Pump banner entrance animation
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    // Banner is visible at the top
    final bannerFinder = find.byKey(const Key('level_complete_banner'));
    expect(bannerFinder, findsOneWidget);
    expect(find.text('LEVEL 1 COMPLETED'), findsOneWidget);
    expect(find.text('+120'), findsOneWidget);

    // Advance past banner display timer (2200ms) + fade out (320ms)
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 400));

    // Banner fades away seamlessly
    final fadeWidget = tester.widget<FadeTransition>(
      find.byKey(const Key('level_complete_banner')),
    );
    expect(fadeWidget.opacity.value, equals(0.0));
    // Game is still actively playing throughout
    expect(eng.phase, equals(GamePhase.playing));
  });
}
