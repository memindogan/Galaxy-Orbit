/// Generates and manages level data for all endless sectors.
///
/// Ensures the starting planet always matches the player's equipped hangar world,
/// and subsequent planets are dynamically chosen from the full FleetCatalog (all 12 celestial worlds).
library;
import 'dart:math';

import '../models/fleet_planet.dart';
import '../models/planet.dart';

class EndlessManager {
  final double screenWidth;
  final double screenHeight;
  final Random rng = Random();
  double nextY;
  int planetCounter = 0;
  FleetPlanet startingPlanet;
  FleetPlanet? lastPlanet;

  EndlessManager({
    required this.screenWidth,
    required this.screenHeight,
    FleetPlanet? startingPlanet,
  })  : startingPlanet = startingPlanet ?? FleetCatalog.worlds.first,
        nextY = screenHeight * 0.7;

  /// Generate a brand new initial layout of planets with the equipped world as the starting point.
  List<Planet> generateInitialPlanets({FleetPlanet? equipped}) {
    if (equipped != null) {
      startingPlanet = equipped;
    }
    planetCounter = 0;
    nextY = screenHeight * 0.7;
    lastPlanet = null;
    final planets = <Planet>[];
    for (int i = 0; i < 5; i++) {
      planets.add(generateNextPlanet());
    }
    return planets;
  }

  /// Generate the next planet for the endless vertical layout
  Planet generateNextPlanet() {
    planetCounter++;
    final levelEquiv = planetCounter ~/ 3; // Difficulty scales every 3 planets

    final baseRadius = (65.0 - levelEquiv * 0.5).clamp(35.0, 65.0);
    final baseSpeed = 2.5 + levelEquiv * 0.08;
    final allowMoving = planetCounter >= 10;
    
    // Spacing between planets along the ascent
    final spacingY = screenHeight * 0.35 + rng.nextDouble() * 50; 

    final radius = baseRadius + rng.nextDouble() * 15 - 7;
    final centerX = screenWidth * 0.2 + rng.nextDouble() * screenWidth * 0.6;
    final centerY = nextY;
    nextY -= spacingY;

    final speed = baseSpeed * (planetCounter.isEven ? 1.0 : -1.0);
    
    bool isMoving = false;
    int moveAxis = 0;
    double moveAmplitude = 0;
    double moveSpeed = 0;

    if (allowMoving) {
      final moveChance = (0.4 + levelEquiv * 0.01).clamp(0.0, 0.8);
      if (rng.nextDouble() < moveChance) {
        isMoving = true;
        moveAxis = (levelEquiv > 15 && rng.nextBool()) ? 1 : 0;
        moveAmplitude = 30.0 + rng.nextDouble() * (30.0 + levelEquiv * 0.5);
        moveSpeed = 1.0 + rng.nextDouble() * 0.5 + levelEquiv * 0.02;
      }
    }

    // Select celestial world from FleetCatalog
    FleetPlanet world;
    if (planetCounter == 1) {
      // The initial starting planet is the player's equipped fleet world!
      world = startingPlanet;
    } else {
      // Pick dynamically from all 12 celestial worlds, avoiding direct duplicates
      final pool = FleetCatalog.worlds.where((w) => w.id != lastPlanet?.id).toList();
      world = pool[rng.nextInt(pool.length)];
    }
    lastPlanet = world;

    return Planet(
      x: centerX,
      y: centerY,
      radius: radius.clamp(30.0, 90.0),
      rotationSpeed: speed,
      isMoving: isMoving,
      moveAxis: moveAxis,
      moveAmplitude: moveAmplitude,
      moveSpeed: moveSpeed,
      fleetPlanet: world,
    );
  }
}
