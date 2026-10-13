import 'package:flutter_test/flutter_test.dart';
import 'package:neon_orbit/engine/game_engine.dart';
import 'package:neon_orbit/engine/level_manager.dart';
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
  });
}

