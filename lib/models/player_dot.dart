/// Data model representing the player's orbiting dot.
library;
import 'dart:math';

class PlayerDot {
  /// Current world-space X position.
  double x;

  /// Current world-space Y position.
  double y;

  /// Previous world-space position (used for continuous raycasted collision detection).
  double prevX;
  double prevY;

  /// Current velocity X (pixels per second) — used when flying.
  double vx = 0;

  /// Current velocity Y (pixels per second) — used when flying.
  double vy = 0;

  /// Current angle on the orbit (radians).
  double angle = 0;

  /// Whether the player is attached to an orbit or flying free.
  bool isOrbiting = true;

  /// Trail positions (most recent first).
  final List<TrailPoint> trail = [];

  PlayerDot({required this.x, required this.y})
      : prevX = x,
        prevY = y;

  /// Update position while orbiting around a center point.
  void updateOrbiting(double centerX, double centerY, double orbitRadius,
      double rotationSpeed, double dt) {
    prevX = x;
    prevY = y;
    angle += rotationSpeed * dt;
    x = centerX + cos(angle) * orbitRadius;
    y = centerY + sin(angle) * orbitRadius;
  }

  /// Update position while flying free (linear motion).
  void updateFlying(double dt) {
    prevX = x;
    prevY = y;
    x += vx * dt;
    y += vy * dt;
  }

  /// Launch the dot along the tangent direction of its current orbit.
  /// Tangent of circular motion at angle θ on (cx,cy,r):
  ///   direction = (-sin(θ), cos(θ)) * sign(rotationSpeed)
  void launch(double rotationSpeed, double launchSpeed, {double planetVx = 0.0, double planetVy = 0.0}) {
    prevX = x;
    prevY = y;
    final sign = rotationSpeed >= 0 ? 1.0 : -1.0;
    vx = -sin(angle) * sign * launchSpeed + planetVx;
    vy = cos(angle) * sign * launchSpeed + planetVy;
    isOrbiting = false;
  }

  /// Record current position in the trail buffer recycling existing points.
  void recordTrail() {
    if (trail.length < 20) {
      trail.insert(0, TrailPoint(x, y));
    } else {
      final recycled = trail.removeLast();
      recycled.x = x;
      recycled.y = y;
      trail.insert(0, recycled);
    }
  }
}

/// A single point in the player's trail.
class TrailPoint {
  double x;
  double y;
  TrailPoint(this.x, this.y);
}
