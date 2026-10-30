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

    // Verify RETRY button triggers rocket animation and then restarts the game
    final retryBtn = find.text('RETRY');
    await tester.tap(retryBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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

  testWidgets('GameScreen successfully triggers OrbitLostModal across multiple sessions without stale callback crashes', (WidgetTester tester) async {
    final gameState = GameStateProvider();
    final settings = SettingsProvider();

    // Session 1: Open GameScreen
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<GameStateProvider>.value(value: gameState),
        ],
        child: const MaterialApp(
          home: GameScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Session 1: Dispose GameScreen (navigate away)
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<GameStateProvider>.value(value: gameState),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Text('Menu')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Session 2: Reopen GameScreen
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<GameStateProvider>.value(value: gameState),
        ],
        child: const MaterialApp(
          home: GameScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Trigger Game Over in Session 2
    final eng = gameState.engine;
    eng.player.isOrbiting = false;
    eng.player.vx = -1500.0;
    eng.player.vy = 0.0;

    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (eng.phase == GamePhase.gameOver) break;
    }

    expect(eng.phase, equals(GamePhase.gameOver));

    // Pump modal entrance animation
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Modal must be visible and properly mounted in Session 2 without any crash
    expect(find.byType(OrbitLostModal), findsOneWidget);
    expect(find.text('ORBIT LOST'), findsOneWidget);
  });

  testWidgets('OrbitLostModal Revive button spends Stardust and resumes orbit', (WidgetTester tester) async {
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
    // Give player 50 Stardust in current sector before missing
    eng.sectorStarDust = 50;
    eng.runStarDust = 50;
    eng.player.isOrbiting = false;
    eng.player.vx = -1500.0;
    eng.player.vy = 0.0;

    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (eng.phase == GamePhase.gameOver) break;
    }

    expect(eng.phase, equals(GamePhase.gameOver));
    expect(gameState.totalStarDust, equals(50));
    expect(gameState.canAffordRevive, isTrue);

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('REVIVE ORBIT (3/3)'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);

    await tester.tap(find.byKey(const Key('revive_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Player should be back in orbit with 25 Stardust deducted and 2 revives remaining
    expect(eng.phase, equals(GamePhase.playing));
    expect(eng.player.isOrbiting, isTrue);
    expect(gameState.totalStarDust, equals(25));
    expect(gameState.remainingRevives, equals(2));
    expect(gameState.nextReviveCost, equals(60));
  });

  testWidgets('OrbitLostModal conditional animations: NEW HIGH badge and Heartbeat state', (WidgetTester tester) async {
    // 1. Not a new high score & cannot afford revive -> NEW HIGH hidden, heartbeat inactive
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OrbitLostModal(
              score: 1200,
              level: 3,
              highScore: 5000,
              runStarDust: 10,
              totalWalletStarDust: 5,
              orbitsCompleted: 8,
              bestCombo: 2,
              isNewHighScore: false,
              canRevive: true,
              canAffordRevive: false,
              reviveCost: 25,
              remainingRevives: 3,
              onRetry: () {},
              onMenu: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const Key('new_high_badge')), findsNothing);
    expect(find.byKey(const ValueKey<bool>(false)), findsOneWidget);
    expect(find.text('8 Orbits'), findsOneWidget);
    expect(find.text('x2 Combo'), findsOneWidget);

    // 2. New high score & can afford revive -> NEW HIGH visible & shimmering, heartbeat active
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OrbitLostModal(
              score: 6400,
              level: 5,
              highScore: 6400,
              runStarDust: 45,
              totalWalletStarDust: 200,
              orbitsCompleted: 12,
              bestCombo: 5,
              isNewHighScore: true,
              canRevive: true,
              canAffordRevive: true,
              reviveCost: 25,
              remainingRevives: 2,
              onRevive: () {},
              onRetry: () {},
              onMenu: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const Key('new_high_badge')), findsOneWidget);
    expect(find.text('NEW HIGH!'), findsOneWidget);
    expect(find.byKey(const ValueKey<bool>(true)), findsOneWidget);
    expect(find.text('12 Orbits'), findsOneWidget);
    expect(find.text('x5 Combo'), findsOneWidget);
  });
}
