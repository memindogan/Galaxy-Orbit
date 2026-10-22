/// Core game engine — owns the physics loop, collision detection,
/// state transitions (orbiting ↔ flying ↔ game-over / level-complete).
///
/// This class is intentionally free of Flutter widgets so it can be
/// unit-tested independently.
library;
import 'dart:math';

import '../models/planet.dart';
import '../models/player_dot.dart';
import 'level_manager.dart';

enum GamePhase { ready, playing, gameOver, levelComplete }

class GameEngine {
  // ─── Configuration ───────────────────────────────────────────────────────
  static const double launchSpeed = 600.0; // px/s
  static const double catchRadius = 18.0; // how close player must be to planet edge to "catch"
  static const int maxRevivesPerRun = 3;
  static const List<int> reviveCosts = [25, 60, 120];

  // ─── State ────────────────────────────────────────────────────────────────
  PlayerDot player = PlayerDot(x: 0, y: 0);
  List<Planet> planets = [];
  int currentPlanetIndex = 0;
  int nextPlanetIndex = 1;
  GamePhase phase = GamePhase.ready;
  int combo = 0;
  int lastSkippedCount = 0;
  int revivesUsed = 0;
  int score = 0;
  int levelStarDust = 0;
  int runStarDust = 0;
  int sectorStarDust = 0;
  int lastBankedSectorStarDust = 0;
  int currentLevel = 1;
  int capturesInLevel = 0;
  int totalCapturesInLevel = 5;
  double totalElapsed = 0;
  double flightTime = 0;
  static const double maxFlightDuration = 2.5; // seconds fail-safe watchdog

  // ─── Screen bounds ────────────────────────────────────────────────────────
  double screenWidth = 0;
  double screenHeight = 0;

  // ─── Camera ───────────────────────────────────────────────────────────────
  double cameraY = 0; // vertical offset for scrolling
  double targetCameraY = 0;
  static const double cameraSmoothSpeed = 8.0;

  late EndlessManager endlessManager;

  /// Callbacks (set by GameScreen)
  void Function()? onHit;
  void Function()? onShoot;
  void Function()? onGameOver;
  void Function(int completedLevel, int bonusStardust)? onLevelComplete;

  int _calcCapturesForLevel(int lvl) => (lvl + 1).clamp(5, 12);

  /// Initialise / reset for endless mode.
  void init(EndlessManager manager, double w, double h) {
    screenWidth = w;
    screenHeight = h;
    endlessManager = manager;
    planets = endlessManager.generateInitialPlanets();
    currentLevel = 1;
    capturesInLevel = 0;
    totalCapturesInLevel = _calcCapturesForLevel(currentLevel);
    currentPlanetIndex = 0;
    nextPlanetIndex = 1;
    combo = 0;
    lastSkippedCount = 0;
    revivesUsed = 0;
    score = 0;
    runStarDust = 0;
    sectorStarDust = 0;
    levelStarDust = 0;
    lastBankedSectorStarDust = 0;
    totalElapsed = 0;
    flightTime = 0;
    cameraY = 0;
    targetCameraY = 0;
    phase = GamePhase.playing;

    planets[0].cleared = true;

    // Place player on first planet.
    final start = planets[0];
    player = PlayerDot(
      x: start.x + start.radius,
      y: start.y,
    );
    player.angle = 0;
    player.isOrbiting = true;

    _updateCamera(instant: true);
  }

  /// Advance to the next level/sector after completing all captures.
  void advanceToNextLevel() {
    currentLevel++;
    capturesInLevel = 0;
    sectorStarDust = 0;
    levelStarDust = 0;
    totalCapturesInLevel = _calcCapturesForLevel(currentLevel);
    phase = GamePhase.playing;
  }

  /// Whether the player is eligible to revive in the current run.
  bool get canRevive => phase == GamePhase.gameOver && revivesUsed < maxRevivesPerRun;

  /// Remaining revive count in the current run.
  int get remainingRevives => max(0, maxRevivesPerRun - revivesUsed);

  /// Stardust cost for the next revive (25 -> 60 -> 120).
  int get nextReviveCost =>
      revivesUsed < reviveCosts.length ? reviveCosts[revivesUsed] : reviveCosts.last;

  /// Places the player safely back into orbit on the last cleared planet.
  bool revivePlayer() {
    if (!canRevive) return false;
    if (planets.isEmpty || currentPlanetIndex < 0 || currentPlanetIndex >= planets.length) {
      return false;
    }

    revivesUsed++;
    combo = 0;
    lastSkippedCount = 0;
    flightTime = 0;

    final planet = planets[currentPlanetIndex];
    planet.update(totalElapsed);

    player.isOrbiting = true;
    player.vx = 0;
    player.vy = 0;
    player.x = planet.x + cos(player.angle) * planet.radius;
    player.y = planet.y + sin(player.angle) * planet.radius;
    player.prevX = player.x;
    player.prevY = player.y;
    player.trail.clear();

    phase = GamePhase.playing;
    _updateCamera(instant: true);
    return true;
  }

  /// Updates screen bounds dynamically on window resize or orientation change without resetting run.
  void updateScreenSize(double w, double h) {
    if (w <= 0 || h <= 0) return;
    screenWidth = w;
    screenHeight = h;
    endlessManager.screenWidth = w;
    endlessManager.screenHeight = h;
  }

  /// Main update tick — called every frame with dt in seconds.
  void update(double dt) {
    if (phase != GamePhase.playing) return;
    if (planets.isEmpty || currentPlanetIndex < 0 || currentPlanetIndex >= planets.length) return;

    totalElapsed += dt;

    // Update moving planets in active window around player.
    final updateStart = max(0, currentPlanetIndex - 2);
    final updateEnd = min(planets.length, currentPlanetIndex + 5);
    for (int i = updateStart; i < updateEnd; i++) {
      planets[i].update(totalElapsed);
    }

    if (player.isOrbiting) {
      flightTime = 0;
      final planet = planets[currentPlanetIndex];
      player.updateOrbiting(
        planet.x,
        planet.y,
        planet.radius,
        planet.rotationSpeed,
        dt,
      );
      player.recordTrail();
    } else {
      // Flying phase.
      flightTime += dt;
      player.updateFlying(dt);
      player.recordTrail();

      _checkCollisions();

      // Out of bounds or maximum flight duration timeout → game over (only if still flying).
      if (!player.isOrbiting && (_isOutOfVisibleBounds() || flightTime >= maxFlightDuration)) {
        phase = GamePhase.gameOver;
        onGameOver?.call();
        return;
      }
    }

    _updateCamera();
  }

  /// Called on user tap.
  void onTap() {
    if (phase != GamePhase.playing) return;
    if (!player.isOrbiting) return;
    if (planets.isEmpty || currentPlanetIndex < 0 || currentPlanetIndex >= planets.length) return;

    final planet = planets[currentPlanetIndex];
    player.launch(
      planet.rotationSpeed,
      launchSpeed,
      planetVx: planet.getVelocityX(totalElapsed),
      planetVy: planet.getVelocityY(totalElapsed),
    );
    onShoot?.call();
  }

  void _checkCollisions() {
    final x1 = player.prevX;
    final y1 = player.prevY;
    final x2 = player.x;
    final y2 = player.y;

    final segDx = x2 - x1;
    final segDy = y2 - y1;
    final segLenSq = segDx * segDx + segDy * segDy;

    // Search window around active player index
    final startIndex = max(0, currentPlanetIndex);
    final endIndex = min(planets.length, currentPlanetIndex + 5);

    for (int i = startIndex; i < endIndex; i++) {
      if (i == currentPlanetIndex) continue;
      final planet = planets[i];
      if (planet.cleared) continue;

      final maxCatch = planet.radius + catchRadius;
      final maxCatchSq = maxCatch * maxCatch;

      // 1D broad-phase cull against bounding box of travel segment
      final minY = min(y1, y2) - maxCatch;
      final maxY = max(y1, y2) + maxCatch;
      if (planet.y < minY || planet.y > maxY) continue;

      // Continuous collision test: shortest distance from planet center to travel segment
      double distSq;
      double catchX = x2;
      double catchY = y2;

      if (segLenSq < 1e-4) {
        final dx = x2 - planet.x;
        final dy = y2 - planet.y;
        distSq = dx * dx + dy * dy;
      } else {
        // Project planet center onto line segment: t = dot(planet - p1, p2 - p1) / lenSq
        final t = (((planet.x - x1) * segDx + (planet.y - y1) * segDy) / segLenSq).clamp(0.0, 1.0);
        final projX = x1 + t * segDx;
        final projY = y1 + t * segDy;
        final dx = projX - planet.x;
        final dy = projY - planet.y;
        distSq = dx * dx + dy * dy;
        catchX = projX;
        catchY = projY;
      }

      if (distSq <= maxCatchSq) {
        player.x = catchX;
        player.y = catchY;
        _attachToPlanet(i);
        return;
      }
    }
  }

  void _attachToPlanet(int index) {
    final planet = planets[index];
    final skippedPlanets = max(0, index - currentPlanetIndex - 1);

    // Mark any bypassed intermediate planets as cleared so they don't remain active targets
    for (int k = currentPlanetIndex + 1; k <= index; k++) {
      planets[k].cleared = true;
    }

    currentPlanetIndex = index;
    lastSkippedCount = skippedPlanets;

    int earned;
    if (skippedPlanets == 0) {
      // Safe play: immediate next planet -> standard reward, resets leap combo streak
      combo = 0;
      score += 10;
      earned = 1;
    } else if (skippedPlanets == 1) {
      // Single Orbit Leap (1 planet skipped): combo streak scales rewards (8 -> 15 -> 25+)
      combo++;
      score += 50 * combo;
      if (combo == 1) {
        earned = 8;
      } else if (combo == 2) {
        earned = 15;
      } else {
        earned = 25 + (combo - 3) * 10;
      }
    } else {
      // Double+ Orbit Leap (2 or more planets skipped): high-mastery bonus
      combo++;
      score += 150 * combo;
      earned = 25 + (combo - 1) * 15;
    }

    runStarDust += earned;
    sectorStarDust += earned;
    levelStarDust = sectorStarDust;
    capturesInLevel++;

    player.angle = atan2(player.y - planet.y, player.x - planet.x);
    player.isOrbiting = true;
    player.vx = 0;
    player.vy = 0;
    player.x = planet.x + cos(player.angle) * planet.radius;
    player.y = planet.y + sin(player.angle) * planet.radius;
    flightTime = 0;

    // Ensure there are always at least 5 upcoming planets ahead of player
    while (planets.length - currentPlanetIndex < 6) {
      planets.add(endlessManager.generateNextPlanet());
    }

    // Prune distant off-screen planets behind player to prevent memory leaks and GC pressure
    if (currentPlanetIndex > 3) {
      final pruneCount = currentPlanetIndex - 3;
      planets.removeRange(0, pruneCount);
      currentPlanetIndex -= pruneCount;
    }

    nextPlanetIndex = currentPlanetIndex + 1;
    onHit?.call();

    // Check if level captures complete — seamlessly advance without pausing
    if (capturesInLevel >= totalCapturesInLevel) {
      final completedLevel = currentLevel;
      final bonus = 15 + (completedLevel - 1) * 2;
      runStarDust += bonus;
      lastBankedSectorStarDust = sectorStarDust + bonus;
      advanceToNextLevel();
      onLevelComplete?.call(completedLevel, bonus);
    }
  }

  bool _isOutOfVisibleBounds() {
    final refCameraY = min(cameraY, targetCameraY);
    final visibleTop = refCameraY - screenHeight * 0.55;
    final visibleBottom = max(cameraY, targetCameraY) + screenHeight * 1.3;
    final margin = 150.0;

    return player.x < -margin ||
        player.x > screenWidth + margin ||
        player.y < visibleTop - margin ||
        player.y > visibleBottom + margin;
  }

  void _updateCamera({bool instant = false}) {
    if (planets.isEmpty || currentPlanetIndex < 0 || currentPlanetIndex >= planets.length) return;
    final planet = planets[currentPlanetIndex];
    targetCameraY = planet.y - screenHeight * 0.75; // Lower the planet visually since we go up

    if (instant) {
      cameraY = targetCameraY;
    }
  }

  /// Smoothly interpolate camera towards target. Frame-rate independent exponential decay.
  void smoothCamera(double dt) {
    if (!player.isOrbiting && currentPlanetIndex >= 0 && currentPlanetIndex + 1 < planets.length) {
      // Dynamic camera anticipation during free flight towards next planet
      final nextPlanet = planets[currentPlanetIndex + 1];
      targetCameraY = ((planets[currentPlanetIndex].y + nextPlanet.y) / 2) - screenHeight * 0.75;
    }

    final diff = targetCameraY - cameraY;
    final factor = 1.0 - exp(-cameraSmoothSpeed * dt);
    cameraY += diff * factor;
  }
}
