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

  // ─── State ────────────────────────────────────────────────────────────────
  PlayerDot player = PlayerDot(x: 0, y: 0);
  List<Planet> planets = [];
  int currentPlanetIndex = 0;
  int nextPlanetIndex = 1;
  GamePhase phase = GamePhase.ready;
  int combo = 0;
  int score = 0;
  int levelStarDust = 0;
  int runStarDust = 0;
  int sectorStarDust = 0;
  int currentLevel = 1;
  int capturesInLevel = 0;
  int totalCapturesInLevel = 5;
  double totalElapsed = 0;

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
    score = 0;
    runStarDust = 0;
    sectorStarDust = 0;
    levelStarDust = 0;
    totalElapsed = 0;
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
    totalCapturesInLevel = _calcCapturesForLevel(currentLevel);
    phase = GamePhase.playing;
  }

  /// Main update tick — called every frame with dt in seconds.
  void update(double dt) {
    if (phase != GamePhase.playing) return;

    totalElapsed += dt;

    // Update moving planets.
    for (final p in planets) {
      p.update(totalElapsed);
    }

    if (player.isOrbiting) {
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
      player.updateFlying(dt);
      player.recordTrail();

      _checkCollisions();

      // Out of bounds → game over.
      if (_isOutOfVisibleBounds()) {
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
    final px = player.x;
    final py = player.y;

    // Narrow search window around the active player index
    final startIndex = max(0, currentPlanetIndex);
    final endIndex = min(planets.length, currentPlanetIndex + 4);

    for (int i = startIndex; i < endIndex; i++) {
      if (i == currentPlanetIndex) continue;
      final planet = planets[i];
      if (planet.cleared) continue;

      final maxCatch = planet.radius + catchRadius;
      final dy = py - planet.y;
      if (dy.abs() > maxCatch) continue; // 1D broad-phase cull

      final dx = px - planet.x;
      final distSq = dx * dx + dy * dy;
      final maxCatchSq = maxCatch * maxCatch;

      if (distSq <= maxCatchSq) {
        _attachToPlanet(i);
        return;
      }
    }
  }

  void _attachToPlanet(int index) {
    final planet = planets[index];
    planet.cleared = true;
    currentPlanetIndex = index;
    combo++;
    score += 10 * combo;
    final earned = 5 * combo;
    runStarDust += earned;
    sectorStarDust += earned;
    levelStarDust = runStarDust;
    capturesInLevel++;

    player.angle = atan2(player.y - planet.y, player.x - planet.x);
    player.isOrbiting = true;
    player.vx = 0;
    player.vy = 0;
    player.x = planet.x + cos(player.angle) * planet.radius;
    player.y = planet.y + sin(player.angle) * planet.radius;

    // If we are close to the end of the list, generate more planets
    if (currentPlanetIndex >= planets.length - 3) {
      planets.add(endlessManager.generateNextPlanet());
    }

    nextPlanetIndex = currentPlanetIndex + 1;
    onHit?.call();

    // Check if level captures complete — seamlessly advance without pausing
    if (capturesInLevel >= totalCapturesInLevel) {
      final completedLevel = currentLevel;
      final bonus = 100 + completedLevel * 20;
      runStarDust += bonus;
      levelStarDust = runStarDust;
      advanceToNextLevel();
      onLevelComplete?.call(completedLevel, bonus);
    }
  }

  bool _isOutOfVisibleBounds() {
    final visibleTop = cameraY - screenHeight * 0.3;
    final visibleBottom = cameraY + screenHeight * 1.3;
    final margin = 150.0;

    return player.x < -margin ||
        player.x > screenWidth + margin ||
        player.y < visibleTop - margin ||
        player.y > visibleBottom + margin;
  }

  void _updateCamera({bool instant = false}) {
    final planet = planets[currentPlanetIndex];
    targetCameraY = planet.y - screenHeight * 0.75; // Lower the planet visually since we go up

    if (instant) {
      cameraY = targetCameraY;
    }
  }

  /// Smoothly interpolate camera towards target. Frame-rate independent exponential decay.
  void smoothCamera(double dt) {
    if (!player.isOrbiting && currentPlanetIndex + 1 < planets.length) {
      // Dynamic camera anticipation during free flight towards next planet
      final nextPlanet = planets[currentPlanetIndex + 1];
      targetCameraY = ((planets[currentPlanetIndex].y + nextPlanet.y) / 2) - screenHeight * 0.75;
    }

    final diff = targetCameraY - cameraY;
    final factor = 1.0 - exp(-cameraSmoothSpeed * dt);
    cameraY += diff * factor;
  }
}
