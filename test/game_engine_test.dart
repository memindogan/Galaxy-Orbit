import 'package:flutter_test/flutter_test.dart';
import 'package:neon_orbit/engine/game_engine.dart';
import 'package:neon_orbit/engine/level_manager.dart';
import 'package:neon_orbit/models/cosmic_customization.dart';
import 'package:neon_orbit/models/fleet_planet.dart';
import 'package:neon_orbit/models/planet.dart';
import 'package:neon_orbit/models/player_dot.dart';

void main() {
  group('GameEngine Tests', () {
    test('init initializes planets and player correctly', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      expect(engine.planets.isNotEmpty, isTrue);
      expect(engine.phase, equals(GamePhase.playing));
      expect(engine.player.isOrbiting, isTrue);
      expect(engine.score, equals(0));
      expect(engine.combo, equals(0));
    });

    test('PlayerDot launch adds planet momentum correctly', () {
      final dot = PlayerDot(x: 100, y: 100);
      dot.angle = 0; // facing right on orbit
      // launch with rotationSpeed > 0, launchSpeed = 600, planetVx = 50, planetVy = -20
      dot.launch(3.0, 600.0, planetVx: 50.0, planetVy: -20.0);

      expect(dot.isOrbiting, isFalse);
      // Tangent for theta=0 is vy = cos(0)*1*600 = 600 - 20 = 580; vx = -sin(0) + 50 = 50
      expect(dot.vx, closeTo(50.0, 0.01));
      expect(dot.vy, closeTo(580.0, 0.01));
    });

    test('Planet movement updates position along configured axis', () {
      final planet = Planet(
        x: 200,
        y: 300,
        radius: 40,
        isMoving: true,
        moveAxis: 0,
        moveAmplitude: 50,
        moveSpeed: 1.0,
      );

      expect(planet.x, equals(200.0));
      planet.update(1.570796); // pi / 2
      expect(planet.x, closeTo(250.0, 0.5));
      expect(planet.y, equals(300.0));
    });

    test('Level capture tracking and advanceToNextLevel updates correctly', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      expect(engine.currentLevel, equals(1));
      expect(engine.capturesInLevel, equals(0));
      expect(engine.totalCapturesInLevel, equals(5));

      engine.advanceToNextLevel();
      expect(engine.currentLevel, equals(2));
      expect(engine.capturesInLevel, equals(0));
      expect(engine.totalCapturesInLevel, equals(5)); // (2+1).clamp(5, 12) = 5
    });

    test('Planets generate diverse FleetCatalog worlds from EndlessManager', () {
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      final p1 = manager.generateNextPlanet(); // starts on default (Terra)
      final p2 = manager.generateNextPlanet();
      final p3 = manager.generateNextPlanet();

      expect(p1.fleetPlanet.id, equals('terra'));
      expect(p1.planetTheme, equals(0));
      expect(p2.fleetPlanet.id, isNot(equals(p1.fleetPlanet.id)));
      expect(p3.fleetPlanet.id, isNot(equals(p2.fleetPlanet.id)));
    });

    test('Starting planet matches equipped FleetPlanet from EndlessManager', () {
      final ember = FleetCatalog.getById('ember');
      final manager = EndlessManager(
        screenWidth: 400,
        screenHeight: 800,
        startingPlanet: ember,
      );
      final p1 = manager.generateNextPlanet();
      expect(p1.fleetPlanet.id, equals('ember'));
      expect(p1.planetTheme, equals(1));

      final p2 = manager.generateNextPlanet();
      expect(p2.fleetPlanet.id, isNot(equals('ember')));
    });

    test('PlayerDot recordTrail recycles TrailPoint objects and caps size at 20', () {
      final dot = PlayerDot(x: 10, y: 20);
      for (int i = 0; i < 50; i++) {
        dot.x = i.toDouble();
        dot.y = (i * 2).toDouble();
        dot.recordTrail();
      }

      expect(dot.trail.length, equals(20));
      // Most recent position should be at index 0
      expect(dot.trail.first.x, equals(49.0));
      expect(dot.trail.first.y, equals(98.0));
      // Oldest retained position should be i = 30
      expect(dot.trail.last.x, equals(30.0));
      expect(dot.trail.last.y, equals(60.0));
    });

    test('smoothCamera smoothly converges towards target without frame-rate dependency', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      final initialCameraY = engine.cameraY;
      engine.targetCameraY = initialCameraY - 200;

      // Advance smooth camera across 10 frames
      for (int i = 0; i < 10; i++) {
        engine.smoothCamera(1 / 60);
      }

      // Camera should have smoothly moved towards targetCameraY
      expect(engine.cameraY, lessThan(initialCameraY));
      expect(engine.cameraY, greaterThan(engine.targetCameraY));
    });

    test('GameEngine prunes off-screen planets to maintain bounded memory', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // Simulate capturing 25 consecutive planets
      for (int i = 0; i < 25; i++) {
        final targetIndex = engine.currentPlanetIndex + 1;
        final planet = engine.planets[targetIndex];
        engine.player.x = planet.x;
        engine.player.y = planet.y;
        engine.player.isOrbiting = false;
        engine.update(1 / 60);
      }

      // Planets list must stay bounded (at most ~8 planets in memory)
      expect(engine.planets.length, lessThanOrEqualTo(10));
      expect(engine.currentPlanetIndex, lessThanOrEqualTo(4));
    });

    test('Continuous Collision Detection catches fast-moving projectile that skips over planet in 1 tick', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // Target planet at index 1
      final target = engine.planets[1];
      
      // Position player below target and moving upwards rapidly
      engine.player.x = target.x;
      engine.player.y = target.y + 80; // Below planet
      engine.player.vx = 0;
      engine.player.vy = -600; // Moving fast upwards
      engine.player.isOrbiting = false;

      // Update engine with a single large tick (0.3s) where displacement is 180px
      // Without CCD, player jumps from y+80 to y-100 and misses the radius (which is ~40-60px)
      engine.update(0.3);

      // CCD should have detected segment intersection and attached to target planet
      expect(engine.player.isOrbiting, isTrue);
      expect(engine.currentPlanetIndex, equals(1));
    });

    test('EndlessManager generates planets strictly within horizontal screen margins', () {
      final manager = EndlessManager(screenWidth: 360, screenHeight: 740);
      manager.generateInitialPlanets();

      for (int i = 0; i < 50; i++) {
        final p = manager.generateNextPlanet();
        final maxExtent = p.moveAxis == 0 && p.isMoving ? p.moveAmplitude : 0.0;
        expect(p.x - p.radius - maxExtent, greaterThanOrEqualTo(10.0));
        expect(p.x + p.radius + maxExtent, lessThanOrEqualTo(350.0));
      }
    });

    test('Early levels (1-3) enforce gentle onboarding: centered corridor, slow speed, static planets', () {
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      final initial = manager.generateInitialPlanets();

      // First planet is centered horizontally
      expect(initial[0].x, closeTo(200.0, 0.01));

      // Planets 1..6 (Level 1) stay within 36%-64% corridor (144..256) and have slow speed (<= 1.8 rad/s)
      final p6 = manager.generateNextPlanet(); // 6th planet
      final level1Planets = [...initial, p6];
      for (final p in level1Planets) {
        expect(p.x, greaterThanOrEqualTo(400 * 0.36 - 0.01));
        expect(p.x, lessThanOrEqualTo(400 * 0.64 + 0.01));
        expect(p.rotationSpeed.abs(), lessThanOrEqualTo(1.80));
        expect(p.isMoving, isFalse);
      }

      // Planets 7..27 (Levels 2-5) also remain 100% static (no moving obstacles in first 5 levels)
      Planet? lastLevel5Planet;
      for (int i = 7; i <= 27; i++) {
        final p = manager.generateNextPlanet();
        expect(p.isMoving, isFalse);
        expect(p.rotationSpeed.abs(), lessThanOrEqualTo(2.31));
        lastLevel5Planet = p;
      }

      // Planet 28 (start of Level 6) continues smoothly from ~2.30 rad/s (no sudden jump to 2.5+)
      final p28 = manager.generateNextPlanet();
      expect(p28.rotationSpeed.abs(), closeTo(lastLevel5Planet!.rotationSpeed.abs(), 0.05));
    });

    test('Orbit Leap combo and Stardust economy rewards safe vs risk-taking play', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // 1. Safe capture (immediate next planet, index 1): +1 Stardust, +10 score, combo = 0
      final p1 = engine.planets[1];
      engine.player.x = p1.x;
      engine.player.y = p1.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.combo, equals(0));
      expect(engine.score, equals(10));
      expect(engine.runStarDust, equals(1));

      // 2. Single Orbit Leap (skip 1 planet -> land on currentPlanetIndex + 2):
      // combo = 1, +8 Stardust, +50 score
      final leap1Target = engine.planets[engine.currentPlanetIndex + 2];
      engine.player.x = leap1Target.x;
      engine.player.y = leap1Target.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.combo, equals(1));
      expect(engine.lastSkippedCount, equals(1));
      expect(engine.score, equals(10 + 50));
      expect(engine.runStarDust, equals(1 + 8));

      // 3. Second consecutive Single Orbit Leap:
      // combo = 2, +15 Stardust, +100 score
      final leap2Target = engine.planets[engine.currentPlanetIndex + 2];
      engine.player.x = leap2Target.x;
      engine.player.y = leap2Target.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.combo, equals(2));
      expect(engine.score, equals(60 + 100));
      expect(engine.runStarDust, equals(9 + 15));

      // 4. Safe capture after leaps resets combo to 0 and awards +1 Stardust
      final safeTarget = engine.planets[engine.currentPlanetIndex + 1];
      engine.player.x = safeTarget.x;
      engine.player.y = safeTarget.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.combo, equals(0));
      expect(engine.runStarDust, equals(24 + 1));

      // 5. Double Orbit Leap (skip 2 planets -> land on currentPlanetIndex + 3)
      // Completes 5th capture of Level 1 (+15 level bonus):
      // Double leap gives +25 Stardust, +150 score, plus +15 level bonus = +40 Stardust
      final doubleLeapTarget = engine.planets[engine.currentPlanetIndex + 3];
      engine.player.x = doubleLeapTarget.x;
      engine.player.y = doubleLeapTarget.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.combo, equals(1));
      expect(engine.lastSkippedCount, equals(2));
      expect(engine.currentLevel, equals(2));
      expect(engine.runStarDust, equals(25 + 25 + 15));
    });

    test('Revive system enforces 3-use cap with 25 -> 60 -> 120 Stardust costs and restores orbit', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // Simulate missing a shot (game over)
      engine.phase = GamePhase.gameOver;
      engine.player.isOrbiting = false;
      engine.combo = 2;

      // 1st Revive: costs 25, 3 remaining before use
      expect(engine.canRevive, isTrue);
      expect(engine.remainingRevives, equals(3));
      expect(engine.nextReviveCost, equals(25));
      expect(engine.revivePlayer(), isTrue);
      expect(engine.phase, equals(GamePhase.playing));
      expect(engine.player.isOrbiting, isTrue);
      expect(engine.combo, equals(0));
      expect(engine.remainingRevives, equals(2));

      // 2nd Revive: costs 60
      engine.phase = GamePhase.gameOver;
      expect(engine.canRevive, isTrue);
      expect(engine.nextReviveCost, equals(60));
      expect(engine.revivePlayer(), isTrue);
      expect(engine.remainingRevives, equals(1));

      // 3rd Revive: costs 120
      engine.phase = GamePhase.gameOver;
      expect(engine.canRevive, isTrue);
      expect(engine.nextReviveCost, equals(120));
      expect(engine.revivePlayer(), isTrue);
      expect(engine.remainingRevives, equals(0));

      // 4th attempt: blocked (max 3 per run)
      engine.phase = GamePhase.gameOver;
      expect(engine.canRevive, isFalse);
      expect(engine.revivePlayer(), isFalse);
    });

    test('FleetCatalog prices and 12 unique planet assetPaths match progression curve', () {
      expect(FleetCatalog.getById('terra').price, equals(0));
      expect(FleetCatalog.getById('ember').price, equals(300));
      expect(FleetCatalog.getById('aether').price, equals(600));
      expect(FleetCatalog.getById('chronos').price, equals(1000));
      expect(FleetCatalog.getById('nova').price, equals(1500));
      expect(FleetCatalog.getById('titan').price, equals(2200));
      expect(FleetCatalog.getById('gliese').price, equals(3000));
      expect(FleetCatalog.getById('void').price, equals(9000));

      final uniqueAssetPaths = FleetCatalog.worlds.map((w) => w.assetPath).toSet();
      expect(uniqueAssetPaths.length, equals(12));
      for (final world in FleetCatalog.worlds) {
        expect(world.assetPath, equals('assets/images/planet_${world.id}.jpg'));
      }
    });

    test('Entry-only Power-Up rule: collects when entering near power-up angle, vanishes if missed on entry', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // 1. Place Gravity Well power-up on planet[1] at angle 0.0 (right side)
      final p1 = engine.planets[1];
      p1.powerUp = OrbitPowerUpType.gravityWell;
      p1.powerUpAngle = 0.0;

      // Enter orbit on the opposite side (angle = pi, left side) -> should miss and vanish!
      engine.player.x = p1.x - p1.radius;
      engine.player.y = p1.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.currentPlanetIndex, equals(1));
      expect(engine.gravityWellCharges, equals(0));
      expect(p1.powerUp, isNull);
      expect(p1.powerUpVanishTimer, greaterThan(0.4));

      // 2. Place Gravity Well power-up on planet[2] at angle 0.0 (right side)
      final p2 = engine.planets[2];
      p2.powerUp = OrbitPowerUpType.gravityWell;
      p2.powerUpAngle = 0.0;

      // Enter orbit right on the power-up angle (angle = 0.0) -> collects!
      engine.player.x = p2.x + p2.radius;
      engine.player.y = p2.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.currentPlanetIndex, equals(2));
      expect(engine.gravityWellCharges, equals(3));
      expect(engine.effectiveCatchRadius, closeTo(GameEngine.catchRadius * 1.65, 0.01));
      expect(p2.powerUp, isNull);
    });

    test('Aegis Shield saves from space miss and shatters Level 7+ hazard barrier on entry', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // 1. Grant Aegis Shield and fly off-screen -> rescues back to nearest planet
      engine.hasAegisShield = true;
      engine.player.isOrbiting = false;
      engine.player.x = -200; // off-screen left (< -150 margin)
      engine.player.y = engine.planets[0].y;
      engine.update(1 / 60);

      expect(engine.phase, equals(GamePhase.playing));
      expect(engine.player.isOrbiting, isTrue);
      expect(engine.hasAegisShield, isFalse);

      // 2. Hitting a hazard barrier WITH Aegis Shield shatters the hazard and attaches safely
      final target = engine.planets[engine.currentPlanetIndex + 1];
      target.hasHazard = true;
      target.hazardAngle = -0.3;
      target.powerUp = null;

      engine.hasAegisShield = true;
      engine.player.x = target.x + target.radius; // angle 0.0 (inside hazard [-0.3, +1.53])
      engine.player.y = target.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.phase, equals(GamePhase.playing));
      expect(target.hasHazard, isFalse);
      expect(target.hazardShatterTimer, greaterThan(0.5));
      expect(engine.hasAegisShield, isFalse);

      // 3. Hitting a hazard barrier WITHOUT Aegis Shield triggers Game Over
      final pNext = engine.planets[engine.currentPlanetIndex + 1];
      pNext.hasHazard = true;
      pNext.hazardAngle = -0.3;
      pNext.powerUp = null;

      engine.player.x = pNext.x + pNext.radius; // angle 0.0 (inside hazard)
      engine.player.y = pNext.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.phase, equals(GamePhase.gameOver));
    });

    test('Chrono Warp, Overdrive Surge, and Quantum Leap power-ups apply exact mechanics', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // Collect Chrono Warp on planet[1]
      final p1 = engine.planets[1];
      p1.hasHazard = false;
      p1.powerUp = OrbitPowerUpType.chronoWarp;
      p1.powerUpAngle = 0.0;
      engine.player.x = p1.x + p1.radius;
      engine.player.y = p1.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.chronoWarpRemaining, closeTo(6.0, 0.1));

      // Collect Overdrive Surge on planet[2]
      final p2 = engine.planets[2];
      p2.hasHazard = false;
      p2.powerUp = OrbitPowerUpType.overdriveSurge;
      p2.powerUpAngle = 0.0;
      engine.player.x = p2.x + p2.radius;
      engine.player.y = p2.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.overdriveCharges, equals(4));

      // Collect Quantum Leap on planet[3] -> warps +2 planets ahead to original planet[5]!
      final p3 = engine.planets[3];
      final expectedDestPlanet = engine.planets[5];
      p3.hasHazard = false;
      p3.powerUp = OrbitPowerUpType.quantumLeap;
      p3.powerUpAngle = 0.0;
      final scoreBeforeLeap = engine.score;
      engine.player.x = p3.x + p3.radius;
      engine.player.y = p3.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);

      expect(engine.planets[engine.currentPlanetIndex], same(expectedDestPlanet));
      expect(engine.score, greaterThanOrEqualTo(scoreBeforeLeap + 250));
    });

    test('Time Attack mode initializes 30s timer, awards time bonuses, and ends when time expires', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800, gameMode: GameMode.timeAttack);

      expect(engine.mode, equals(GameMode.timeAttack));
      expect(engine.timeRemaining, equals(30.0));

      // Advance 5 seconds while orbiting
      engine.update(5.0);
      expect(engine.timeRemaining, closeTo(25.0, 0.05));

      // Capture next planet -> +2.0s bonus
      final p1 = engine.planets[1];
      engine.player.x = p1.x;
      engine.player.y = p1.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);
      expect(engine.timeRemaining, greaterThan(26.8));

      // Drain remaining time -> triggers Time Up Game Over
      engine.update(30.0);
      expect(engine.phase, equals(GamePhase.gameOver));
      expect(engine.isTimeUpGameOver, isTrue);
    });

    test('CustomizationCatalog provides 4 trail & launch wave bundles with fixed 500 Stardust unlock price', () {
      expect(CustomizationCatalog.items.length, equals(4));
      expect(CustomizationCatalog.getById('classic').price, equals(0));
      expect(CustomizationCatalog.getById('sparkle').price, equals(500));
      expect(CustomizationCatalog.getById('dual_ion').price, equals(500));
      expect(CustomizationCatalog.getById('cyber_glitch').price, equals(500));
    });

    test('Dynamic Camera Zoom works on every transition and Micro Hit-Stop triggers only on epic moments', () {
      final engine = GameEngine();
      final manager = EndlessManager(screenWidth: 400, screenHeight: 800);
      engine.init(manager, 400, 800);

      // 1. Launch -> camera zooms out noticeably during flight
      engine.onTap();
      for (int i = 0; i < 6; i++) {
        engine.smoothCamera(1 / 60);
      }
      expect(engine.cameraZoom, lessThan(0.92));

      // 2. Standard capture (skippedPlanets == 0) -> triggers zoom-in punch (> 1.0), NO hit-stop (0.0)
      final p1 = engine.planets[1];
      engine.player.x = p1.x;
      engine.player.y = p1.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);
      expect(engine.hitStopTimer, equals(0.0));
      expect(engine.cameraZoomPunch, greaterThanOrEqualTo(0.05));

      // 3. Orbit Leap (skip 1 planet -> land on currentPlanetIndex + 2) -> triggers ~52ms micro hit-stop!
      final pLeap = engine.planets[engine.currentPlanetIndex + 2];
      engine.player.x = pLeap.x;
      engine.player.y = pLeap.y;
      engine.player.isOrbiting = false;
      engine.update(1 / 60);
      expect(engine.hitStopTimer, greaterThan(0.045));
      expect(engine.cameraZoomPunch, greaterThanOrEqualTo(0.09));
    });
  });
}

