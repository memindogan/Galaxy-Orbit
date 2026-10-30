/// Data model for a single planet (orbit circle) in the game.
library;
import 'dart:math';

import 'fleet_planet.dart';

/// The 5 collectible orbit-entry power-ups.
enum OrbitPowerUpType {
  aegisShield,
  gravityWell,
  chronoWarp,
  overdriveSurge,
  quantumLeap,
}

class Planet {
  /// Center X position (logical pixels, relative to game area).
  double x;

  /// Center Y position.
  double y;

  /// Orbit radius that the player follows when attached.
  final double radius;

  /// Angular speed in radians per second (positive = counter-clockwise).
  final double rotationSpeed;

  /// Whether this planet moves (ping-pong etc.).
  final bool isMoving;

  /// Movement axis: 0 = horizontal, 1 = vertical.
  final int moveAxis;

  /// Amplitude of movement in logical pixels.
  final double moveAmplitude;

  /// Movement speed multiplier.
  final double moveSpeed;

  /// Base position for oscillation.
  final double baseX;
  final double baseY;

  /// The associated celestial world data from FleetCatalog.
  final FleetPlanet fleetPlanet;

  /// Visual theme / style index (retained for backward compatibility).
  final int planetTheme;

  /// Whether the player has already visited (cleared) this planet.
  bool cleared = false;

  /// Optional power-up orbiting this planet (only collectible on orbit entry!).
  OrbitPowerUpType? powerUp;

  /// Current orbital angle (radians) of the power-up around this planet.
  double powerUpAngle;

  /// Base starting angle of the power-up.
  final double basePowerUpAngle;

  /// Dissolve animation timer (>0 when missed on orbit entry and vanishing).
  double powerUpVanishTimer = 0.0;
  OrbitPowerUpType? vanishedPowerUpType;
  double vanishedPowerUpAngle = 0.0;

  /// Rare rotating arc hazard shield (introduced in Level 7+).
  bool hasHazard;

  /// Current start angle (radians) of the hazard shield arc.
  double hazardAngle;

  /// Base starting angle of the hazard shield.
  final double baseHazardAngle;

  /// Angular sweep width of the hazard arc in radians (~105 degrees).
  final double hazardSweep;

  /// Shatter animation timer (>0 when broken by Aegis Shield).
  double hazardShatterTimer = 0.0;

  Planet({
    required this.x,
    required this.y,
    required this.radius,
    this.rotationSpeed = 3.0,
    this.isMoving = false,
    this.moveAxis = 0,
    this.moveAmplitude = 60.0,
    this.moveSpeed = 1.5,
    int? planetTheme,
    FleetPlanet? fleetPlanet,
    this.powerUp,
    double powerUpAngle = -1.570796, // Default top (-pi/2)
    this.hasHazard = false,
    double hazardAngle = -1.570796,
    this.hazardSweep = 1.8326, // ~105 degrees
  })  : fleetPlanet = fleetPlanet ??
            (planetTheme != null
                ? _resolveThemeToFleetPlanet(planetTheme)
                : FleetCatalog.worlds.first),
        planetTheme = planetTheme ??
            _resolveFleetPlanetToTheme(fleetPlanet ?? FleetCatalog.worlds.first),
        baseX = x,
        baseY = y,
        powerUpAngle = powerUpAngle,
        basePowerUpAngle = powerUpAngle,
        hazardAngle = hazardAngle,
        baseHazardAngle = hazardAngle;

  static FleetPlanet _resolveThemeToFleetPlanet(int theme) {
    switch (theme) {
      case 0:
        return FleetCatalog.getById('terra');
      case 1:
        return FleetCatalog.getById('ember');
      case 2:
        return FleetCatalog.getById('aether');
      case 3:
        return FleetCatalog.getById('titan');
      case 4:
        return FleetCatalog.getById('nova');
      default:
        return FleetCatalog.worlds[theme % FleetCatalog.worlds.length];
    }
  }

  static int _resolveFleetPlanetToTheme(FleetPlanet world) {
    switch (world.id) {
      case 'terra':
        return 0;
      case 'ember':
        return 1;
      case 'aether':
        return 2;
      case 'titan':
        return 3;
      case 'nova':
        return 4;
      case 'chronos':
        return 5;
      case 'gliese':
        return 6;
      case 'nebula9':
        return 7;
      case 'solaris':
        return 8;
      case 'eclipse':
        return 9;
      case 'orion':
        return 10;
      case 'void':
        return 11;
      default:
        return 0;
    }
  }

  /// Update position if the planet is a moving type, plus orbiting power-ups & hazards.
  void update(double totalElapsed, [double dt = 0.0]) {
    if (dt > 0) {
      if (powerUp != null) {
        powerUpAngle += dt * rotationSpeed * 0.85;
      }
      if (hasHazard) {
        hazardAngle -= dt * rotationSpeed * 0.55;
      }
      if (powerUpVanishTimer > 0) {
        powerUpVanishTimer = max(0.0, powerUpVanishTimer - dt);
      }
      if (hazardShatterTimer > 0) {
        hazardShatterTimer = max(0.0, hazardShatterTimer - dt);
      }
    }
    if (!isMoving) return;
    if (moveAxis == 0) {
      x = baseX + sin(totalElapsed * moveSpeed) * moveAmplitude;
    } else {
      y = baseY + sin(totalElapsed * moveSpeed) * moveAmplitude;
    }
  }

  /// Shortest angular distance in radians [0, pi] between two angles.
  static double angularDistance(double a, double b) {
    const twoPi = 2 * pi;
    double diff = (a - b) % twoPi;
    if (diff < 0) diff += twoPi;
    if (diff > pi) diff = twoPi - diff;
    return diff;
  }

  /// Checks whether the player's entry angle is close enough to intercept the orbiting power-up.
  bool isAngleNearPowerUp(double entryAngle, {double toleranceRad = 0.65}) {
    if (powerUp == null) return false;
    return angularDistance(entryAngle, powerUpAngle) <= toleranceRad;
  }

  /// Checks whether the player's entry angle collides with the rotating hazard shield arc.
  bool isAngleInHazard(double entryAngle) {
    if (!hasHazard) return false;
    final centerHazard = hazardAngle + hazardSweep * 0.5;
    return angularDistance(entryAngle, centerHazard) <= (hazardSweep * 0.5);
  }

  /// Distance from this planet's center to a point.
  double distanceTo(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Get current horizontal velocity
  double getVelocityX(double totalElapsed) {
    if (!isMoving || moveAxis != 0) return 0.0;
    return moveAmplitude * moveSpeed * cos(totalElapsed * moveSpeed);
  }

  /// Get current vertical velocity
  double getVelocityY(double totalElapsed) {
    if (!isMoving || moveAxis != 1) return 0.0;
    return moveAmplitude * moveSpeed * cos(totalElapsed * moveSpeed);
  }
}
