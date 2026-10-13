/// Data model for a single planet (orbit circle) in the game.
library;
import 'dart:math';

import 'fleet_planet.dart';

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
  })  : fleetPlanet = fleetPlanet ??
            (planetTheme != null
                ? _resolveThemeToFleetPlanet(planetTheme)
                : FleetCatalog.worlds.first),
        planetTheme = planetTheme ??
            _resolveFleetPlanetToTheme(fleetPlanet ?? FleetCatalog.worlds.first),
        baseX = x,
        baseY = y;

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

  /// Update position if the planet is a moving type.
  void update(double totalElapsed) {
    if (!isMoving) return;
    if (moveAxis == 0) {
      x = baseX + sin(totalElapsed * moveSpeed) * moveAmplitude;
    } else {
      y = baseY + sin(totalElapsed * moveSpeed) * moveAmplitude;
    }
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
