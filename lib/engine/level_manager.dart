/// Generates and manages level data for all endless sectors.
///
/// Ensures the starting planet always matches the player's equipped hangar world,
/// and subsequent planets are dynamically chosen from the full FleetCatalog (all 12 celestial worlds).
library;
import 'dart:math';

import '../models/fleet_planet.dart';
import '../models/planet.dart';

class EndlessManager {
  double screenWidth;
  double screenHeight;
  final Random rng = Random();
  double nextY;
  int planetCounter = 0;
  FleetPlanet startingPlanet;
  FleetPlanet? lastPlanet;
  bool _lastHadPowerUp = false;
  bool _lastHadHazard = false;

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
    _lastHadPowerUp = false;
    _lastHadHazard = false;
    final planets = <Planet>[];
    for (int i = 0; i < 5; i++) {
      planets.add(generateNextPlanet());
    }
    return planets;
  }

  /// Generate the next planet for the endless vertical layout.
  ///
  /// Uses a continuous, smooth onboarding curve across the first 5 levels (planets 1..27)
  /// followed by a gradual post-intro ramp-up from Level 6+ (planets 28+) without any
  /// sudden difficulty cliff:
  /// - Levels 1–5 (planets 1..27): zero moving planets, calm speeds, progressive corridor & spacing
  /// - Level 6+ (planets 28+): moving planets introduced gently (starting at 15% chance)
  ///   while speed, spacing, and radius continue scaling smoothly from where Level 5 left off.
  Planet generateNextPlanet() {
    planetCounter++;

    // Determine progression phase:
    // Planets 1..6   -> Level 1 (5 captures, starts on planet 1)
    // Planets 7..11  -> Level 2 (5 captures)
    // Planets 12..16 -> Level 3 (5 captures)
    // Planets 17..21 -> Level 4 (5 captures)
    // Planets 22..27 -> Level 5 (6 captures)
    // Planets 28+    -> Level 6+ (Gradual endless scaling, 1 step per 4 planets)
    final double postIntroSteps = max(0.0, (planetCounter - 27) / 4.0);

    // 1. Planet Radius (Continuous smooth reduction, no sudden drop after Level 5)
    double radius;
    if (planetCounter == 1) {
      radius = 65.0;
    } else if (planetCounter <= 6) {
      // Level 1: consistently large targets (63 - 68 px)
      radius = 63.0 + rng.nextDouble() * 5.0;
    } else if (planetCounter <= 27) {
      // Levels 2–5: smooth linear interpolation from base 63 px down to 55 px
      final progress = (planetCounter - 6) / 21.0; // 0.0 -> 1.0
      final baseR = 63.0 - progress * 8.0;
      radius = (baseR + rng.nextDouble() * 8.0 - 4.0).clamp(50.0, 68.0);
    } else {
      // Level 6+: continues seamlessly from 55 px, shrinking by 0.5 px per step down to 35 px
      final baseRadius = (55.0 - postIntroSteps * 0.5).clamp(35.0, 55.0);
      radius = (baseRadius + rng.nextDouble() * 12.0 - 6.0).clamp(32.0, 62.0);
    }

    // 2. Orbital Rotation Speed (Calm start, continuous ramp without jumping to 2.5)
    double baseSpeed;
    if (planetCounter <= 6) {
      // Level 1: 1.55 -> 1.70 rad/s
      baseSpeed = 1.55 + (planetCounter - 1) * 0.03;
    } else if (planetCounter <= 11) {
      // Level 2: 1.72 -> 1.85 rad/s
      baseSpeed = 1.70 + (planetCounter - 6) * 0.03;
    } else if (planetCounter <= 16) {
      // Level 3: 1.88 -> 2.00 rad/s
      baseSpeed = 1.85 + (planetCounter - 11) * 0.03;
    } else if (planetCounter <= 21) {
      // Level 4: 2.03 -> 2.15 rad/s
      baseSpeed = 2.00 + (planetCounter - 16) * 0.03;
    } else if (planetCounter <= 27) {
      // Level 5: 2.17 -> 2.30 rad/s
      baseSpeed = 2.15 + (planetCounter - 21) * 0.025;
    } else {
      // Level 6+: continues smoothly from 2.30 rad/s (+0.05 per 4 planets)
      baseSpeed = (2.30 + postIntroSteps * 0.05).clamp(2.30, 4.00);
    }
    final speed = baseSpeed * (planetCounter.isEven ? 1.0 : -1.0);

    // 3. Vertical Spacing (Gradually expands across Levels 1–5 and continues smoothly in 6+)
    double spacingY;
    if (planetCounter <= 6) {
      spacingY = max(185.0, screenHeight * 0.23) + rng.nextDouble() * 18.0;
    } else if (planetCounter <= 11) {
      spacingY = max(195.0, screenHeight * 0.25) + rng.nextDouble() * 22.0;
    } else if (planetCounter <= 16) {
      spacingY = max(205.0, screenHeight * 0.27) + rng.nextDouble() * 26.0;
    } else if (planetCounter <= 21) {
      spacingY = max(215.0, screenHeight * 0.29) + rng.nextDouble() * 30.0;
    } else if (planetCounter <= 27) {
      spacingY = max(225.0, screenHeight * 0.31) + rng.nextDouble() * 35.0;
    } else {
      // Level 6+: smoothly grows from 0.31 up to 0.35 over the next several levels
      final factor = (0.31 + postIntroSteps * 0.008).clamp(0.31, 0.35);
      final minPx = (225.0 + postIntroSteps * 4.0).clamp(225.0, 245.0);
      final jitter = (35.0 + postIntroSteps * 2.5).clamp(35.0, 50.0);
      spacingY = max(minPx, screenHeight * factor) + rng.nextDouble() * jitter;
    }

    final centerY = nextY;
    nextY -= spacingY;

    // 4. Moving Planets (Strictly disabled throughout Levels 1–5; introduced gently in Level 6+)
    final allowMoving = planetCounter >= 28;
    bool isMoving = false;
    int moveAxis = 0;
    double moveAmplitude = 0;
    double moveSpeed = 0;

    if (allowMoving) {
      // Starts at 15% chance in Level 6 and gradually rises (+4% per 4 planets, capped at 70%)
      final moveChance = (0.15 + postIntroSteps * 0.04).clamp(0.15, 0.70);
      if (rng.nextDouble() < moveChance) {
        isMoving = true;
        moveAxis = (postIntroSteps > 10 && rng.nextBool()) ? 1 : 0;
        final maxPossibleAmp = ((screenWidth - 2 * 24.0 - 2 * radius) / 2).clamp(15.0, 55.0);
        final baseAmp = (16.0 + postIntroSteps * 1.5).clamp(16.0, 30.0);
        moveAmplitude = (baseAmp + rng.nextDouble() * 14.0).clamp(15.0, maxPossibleAmp);
        moveSpeed = (0.75 + postIntroSteps * 0.04 + rng.nextDouble() * 0.25).clamp(0.75, 1.80);
      }
    }

    // 5. Horizontal Placement (Smoothly widens from center across Levels 1–8)
    final safeMargin = 20.0;
    final motionMargin = isMoving && moveAxis == 0 ? moveAmplitude : 0.0;
    final hardMinX = safeMargin + radius + motionMargin;
    final hardMaxX = screenWidth - safeMargin - radius - motionMargin;

    // Corridor fraction of screenWidth: [corridorMinFrac, corridorMaxFrac]
    double corridorMinFrac;
    double corridorMaxFrac;
    if (planetCounter == 1) {
      corridorMinFrac = 0.50;
      corridorMaxFrac = 0.50;
    } else if (planetCounter <= 6) {
      // Level 1: tight central corridor (36% - 64%)
      corridorMinFrac = 0.36;
      corridorMaxFrac = 0.64;
    } else if (planetCounter <= 11) {
      // Level 2: (30% - 70%)
      corridorMinFrac = 0.30;
      corridorMaxFrac = 0.70;
    } else if (planetCounter <= 16) {
      // Level 3: (24% - 76%)
      corridorMinFrac = 0.24;
      corridorMaxFrac = 0.76;
    } else if (planetCounter <= 21) {
      // Level 4: (18% - 82%)
      corridorMinFrac = 0.18;
      corridorMaxFrac = 0.82;
    } else if (planetCounter <= 27) {
      // Level 5: (12% - 88%)
      corridorMinFrac = 0.12;
      corridorMaxFrac = 0.88;
    } else {
      // Level 6+: smoothly opens the remaining 12% margin down to 0% over the next few levels
      final marginFrac = (0.12 - postIntroSteps * 0.025).clamp(0.0, 0.12);
      corridorMinFrac = marginFrac;
      corridorMaxFrac = 1.0 - marginFrac;
    }

    final minX = max(hardMinX, screenWidth * corridorMinFrac);
    final maxX = min(hardMaxX, screenWidth * corridorMaxFrac);

    final double centerX = minX >= maxX
        ? screenWidth * 0.5
        : (minX + rng.nextDouble() * (maxX - minX)).clamp(hardMinX, max(hardMinX, hardMaxX)).toDouble();

    // Select celestial world from FleetCatalog (zero-allocation)
    FleetPlanet world;
    if (planetCounter == 1) {
      world = startingPlanet;
    } else {
      final total = FleetCatalog.worlds.length;
      var chosen = FleetCatalog.worlds[rng.nextInt(total)];
      if (chosen.id == lastPlanet?.id && total > 1) {
        final offset = 1 + rng.nextInt(total - 1);
        final lastIdx = FleetCatalog.worlds.indexOf(lastPlanet!);
        chosen = FleetCatalog.worlds[((lastIdx < 0 ? 0 : lastIdx) + offset) % total];
      }
      world = chosen;
    }
    lastPlanet = world;

    // 6. Orbit-Entry Power-Ups (Introduced from planet 4+, never on consecutive planets)
    OrbitPowerUpType? powerUp;
    double powerUpAngle = -pi * 0.5;
    if (planetCounter >= 4 && !_lastHadPowerUp && rng.nextDouble() < 0.22) {
      const types = OrbitPowerUpType.values;
      powerUp = types[rng.nextInt(types.length)];
      powerUpAngle = -pi * 0.5 + (rng.nextDouble() - 0.5) * 0.4;
      _lastHadPowerUp = true;
    } else {
      _lastHadPowerUp = false;
    }

    // 7. Rare Hazard Shields (Strictly Level 7+ -> planetCounter >= 35, very rare 14% chance, never consecutive)
    bool hasHazard = false;
    double hazardAngle = -pi * 0.65;
    if (planetCounter >= 35 && !_lastHadHazard && rng.nextDouble() < 0.14) {
      hasHazard = true;
      hazardAngle = -pi * 0.65 + (rng.nextDouble() - 0.5) * 0.3;
      _lastHadHazard = true;
    } else {
      _lastHadHazard = false;
    }

    return Planet(
      x: centerX,
      y: centerY,
      radius: radius,
      rotationSpeed: speed,
      isMoving: isMoving,
      moveAxis: moveAxis,
      moveAmplitude: moveAmplitude,
      moveSpeed: moveSpeed,
      fleetPlanet: world,
      powerUp: powerUp,
      powerUpAngle: powerUpAngle,
      hasHazard: hasHazard,
      hazardAngle: hazardAngle,
    );
  }
}
