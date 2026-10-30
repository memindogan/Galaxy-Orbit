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

enum GameMode { endless, timeAttack }

/// Pre-allocated shockwave ring data for launch waves, catch ripples, and shield bursts.
class ShockwaveRing {
  bool active = false;
  double x = 0;
  double y = 0;
  double startRadius = 6.0;
  double maxRadius = 60.0;
  double elapsed = 0;
  double duration = 0.45;
  double angle = 0;
  bool isLaunch = true;
  bool isShieldBurst = false;

  double get progress => duration > 0 ? (elapsed / duration).clamp(0.0, 1.0) : 1.0;
}

class GameEngine {
  // ─── Configuration ───────────────────────────────────────────────────────
  static const double launchSpeed = 600.0; // px/s
  static const double catchRadius = 18.0; // how close player must be to planet edge to "catch"
  static const int maxRevivesPerRun = 3;
  static const List<int> reviveCosts = [25, 60, 120];
  static const double initialTimeAttackSeconds = 30.0;

  // ─── State ────────────────────────────────────────────────────────────────
  GameMode mode = GameMode.endless;
  PlayerDot player = PlayerDot(x: 0, y: 0);
  List<Planet> planets = [];
  int currentPlanetIndex = 0;
  int nextPlanetIndex = 1;
  GamePhase phase = GamePhase.ready;
  int combo = 0;
  int maxCombo = 0;
  int totalCaptures = 0;
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

  // ─── Time Attack State ────────────────────────────────────────────────────
  double timeRemaining = initialTimeAttackSeconds;
  double lastTimeBonus = 0;
  double timeBonusDisplayTimer = 0;
  bool isTimeUpGameOver = false;

  // ─── Active Power-Up States ───────────────────────────────────────────────
  bool hasAegisShield = false;
  int gravityWellCharges = 0;
  double chronoWarpRemaining = 0.0;
  int overdriveCharges = 0;

  // ─── Visual Juice & Camera Feel (Zero-GC Pre-allocated Pool) ──────────────
  final List<ShockwaveRing> shockwaves = List.generate(8, (_) => ShockwaveRing());
  double cameraZoom = 1.0;
  double cameraZoomPunch = 0.0;
  double hitStopTimer = 0.0;
  double shakeTimer = 0.0;
  double shakeIntensity = 0.0;
  double shakeOffsetX = 0.0;
  double shakeOffsetY = 0.0;

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
  void Function(OrbitPowerUpType powerUp)? onPowerUpCollected;
  void Function(bool brokeHazard)? onShieldUsed;

  int _calcCapturesForLevel(int lvl) => (lvl + 1).clamp(5, 12);

  /// Effective catch radius including Gravity Well power-up bonus (+65%).
  double get effectiveCatchRadius =>
      gravityWellCharges > 0 ? catchRadius * 1.65 : catchRadius;

  /// Spawns a shockwave in the pre-allocated ring pool without heap allocations.
  void spawnShockwave(
    double x,
    double y, {
    double startR = 6.0,
    double maxR = 62.0,
    double duration = 0.45,
    double angle = 0.0,
    bool isLaunch = true,
    bool isShieldBurst = false,
  }) {
    ShockwaveRing? slot;
    for (int i = 0; i < shockwaves.length; i++) {
      if (!shockwaves[i].active) {
        slot = shockwaves[i];
        break;
      }
    }
    slot ??= shockwaves.first;
    slot.active = true;
    slot.x = x;
    slot.y = y;
    slot.startRadius = startR;
    slot.maxRadius = maxR;
    slot.elapsed = 0.0;
    slot.duration = duration;
    slot.angle = angle;
    slot.isLaunch = isLaunch;
    slot.isShieldBurst = isShieldBurst;
  }

  /// Triggers a brief decaying micro-shake for tactile impact.
  void triggerCameraShake(double intensity, {double duration = 0.18}) {
    shakeIntensity = max(shakeIntensity, intensity);
    shakeTimer = max(shakeTimer, duration);
  }

  /// Triggers a brief (~50-65ms) micro hit-stop / time dilation for epic impacts
  /// (Orbit Leap, Barrier Shatter, Quantum Leap) without interrupting standard captures.
  void triggerHitStop([double duration = 0.055]) {
    hitStopTimer = max(hitStopTimer, duration);
  }

  /// Initialise / reset for endless or time-attack mode.
  void init(EndlessManager manager, double w, double h, {GameMode gameMode = GameMode.endless}) {
    mode = gameMode;
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
    maxCombo = 0;
    totalCaptures = 0;
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
    cameraZoom = 1.0;
    cameraZoomPunch = 0.0;
    hitStopTimer = 0.0;
    shakeTimer = 0.0;
    shakeIntensity = 0.0;
    shakeOffsetX = 0.0;
    shakeOffsetY = 0.0;
    for (int i = 0; i < shockwaves.length; i++) {
      shockwaves[i].active = false;
    }

    timeRemaining = initialTimeAttackSeconds;
    lastTimeBonus = 0;
    timeBonusDisplayTimer = 0;
    isTimeUpGameOver = false;

    hasAegisShield = false;
    gravityWellCharges = 0;
    chronoWarpRemaining = 0.0;
    overdriveCharges = 0;

    phase = GamePhase.playing;

    planets[0].cleared = true;
    planets[0].powerUp = null;
    planets[0].hasHazard = false;

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

    if (mode == GameMode.timeAttack && timeRemaining < 12.0) {
      timeRemaining = 12.0;
    }
    isTimeUpGameOver = false;

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

    // Update shockwave rings in-place (zero allocation)
    for (int i = 0; i < shockwaves.length; i++) {
      final sw = shockwaves[i];
      if (sw.active) {
        sw.elapsed += dt;
        if (sw.elapsed >= sw.duration) {
          sw.active = false;
        }
      }
    }

    // Chrono Warp slows down orbital & planetary motion by 45% without making flight sluggish
    double orbitTimeScale = 1.0;
    if (chronoWarpRemaining > 0) {
      chronoWarpRemaining = max(0.0, chronoWarpRemaining - dt);
      orbitTimeScale = 0.55;
    }

    // Epic-moment micro hit-stop / time dilation (~50-65ms on Orbit Leap, Barrier Break, Quantum Leap)
    if (hitStopTimer > 0) {
      hitStopTimer = max(0.0, hitStopTimer - dt);
      orbitTimeScale *= 0.06;
    }

    final scaledDt = dt * orbitTimeScale;
    totalElapsed += scaledDt;

    // Time Attack countdown (pauses briefly during micro hit-stop so epic impacts never penalize timer)
    if (timeBonusDisplayTimer > 0) {
      timeBonusDisplayTimer = max(0.0, timeBonusDisplayTimer - dt);
    }
    if (mode == GameMode.timeAttack) {
      final timerDt = hitStopTimer > 0 ? dt * 0.06 : dt;
      timeRemaining = max(0.0, timeRemaining - timerDt);
      if (timeRemaining <= 0.0) {
        isTimeUpGameOver = true;
        phase = GamePhase.gameOver;
        onGameOver?.call();
        return;
      }
    }

    // Update moving planets & rotating power-ups/hazards in active window around player.
    final updateStart = max(0, currentPlanetIndex - 2);
    final updateEnd = min(planets.length, currentPlanetIndex + 5);
    for (int i = updateStart; i < updateEnd; i++) {
      planets[i].update(totalElapsed, scaledDt);
    }

    if (player.isOrbiting) {
      flightTime = 0;
      final planet = planets[currentPlanetIndex];
      player.updateOrbiting(
        planet.x,
        planet.y,
        planet.radius,
        planet.rotationSpeed,
        scaledDt,
      );
      player.recordTrail();
    } else {
      // Flying phase.
      flightTime += dt;
      player.updateFlying(dt);
      player.recordTrail();

      _checkCollisions();

      // Out of bounds or maximum flight duration timeout → game over (unless saved by Aegis Shield).
      if (!player.isOrbiting && (_isOutOfVisibleBounds() || flightTime >= maxFlightDuration)) {
        if (hasAegisShield) {
          hasAegisShield = false;
          final rescueIndex = min(planets.length - 1, currentPlanetIndex + 1);
          final rescuePlanet = planets[rescueIndex];
          player.x = rescuePlanet.x;
          player.y = rescuePlanet.y + rescuePlanet.radius;
          spawnShockwave(
            rescuePlanet.x,
            rescuePlanet.y,
            startR: rescuePlanet.radius * 0.65,
            maxR: rescuePlanet.radius * 1.85,
            duration: 0.50,
            isLaunch: false,
            isShieldBurst: true,
          );
          triggerCameraShake(5.5);
          onShieldUsed?.call(false);
          _attachToPlanet(rescueIndex);
          _updateCamera();
          return;
        }
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
    spawnShockwave(
      player.x,
      player.y,
      startR: 6.0,
      maxR: 64.0,
      duration: 0.42,
      angle: atan2(player.vy, player.vx),
      isLaunch: true,
    );
    // Immediate launch FOV kick so every transition visibly zooms out right on tap
    cameraZoomPunch = -0.055;
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
    final activeCatchRadius = effectiveCatchRadius;

    for (int i = startIndex; i < endIndex; i++) {
      if (i == currentPlanetIndex) continue;
      final planet = planets[i];
      if (planet.cleared) continue;

      final maxCatch = planet.radius + activeCatchRadius;
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
        // Check rotating hazard shield on target planet (Level 7+)
        if (planet.hasHazard) {
          double entryAngle = atan2(catchY - planet.y, catchX - planet.x);
          if (distSq < 1.0) {
            final appDx = x1 - planet.x;
            final appDy = y1 - planet.y;
            if (appDx * appDx + appDy * appDy > 1.0) {
              entryAngle = atan2(appDy, appDx);
            }
          }
          if (planet.isAngleInHazard(entryAngle)) {
            if (hasAegisShield) {
              // Aegis Shield shatters the hazard barrier and lets player latch onto the planet!
              hasAegisShield = false;
              planet.hasHazard = false;
              planet.hazardShatterTimer = 0.55;
              spawnShockwave(
                planet.x,
                planet.y,
                startR: planet.radius * 0.85,
                maxR: planet.radius * 1.90,
                duration: 0.50,
                isLaunch: false,
                isShieldBurst: true,
              );
              triggerCameraShake(6.5);
              triggerHitStop(0.060);
              cameraZoomPunch = 0.11;
              onShieldUsed?.call(true);
            } else {
              // Hit hazard without shield -> Game Over
              triggerCameraShake(8.5);
              phase = GamePhase.gameOver;
              onGameOver?.call();
              return;
            }
          }
        }

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
    final isSyntheticCenterTeleport = (player.x == planet.x && player.y == planet.y);

    // Consume 1 charge of Gravity Well if active
    if (gravityWellCharges > 0) {
      gravityWellCharges--;
    }

    // Mark any bypassed intermediate planets as cleared so they don't remain active targets
    for (int k = currentPlanetIndex + 1; k <= index; k++) {
      planets[k].cleared = true;
    }

    currentPlanetIndex = index;
    lastSkippedCount = skippedPlanets;

    final bool isOverdrive = overdriveCharges > 0;
    if (overdriveCharges > 0) {
      overdriveCharges--;
    }
    final int rewardMult = isOverdrive ? 2 : 1;

    int earned;
    if (skippedPlanets == 0) {
      if (isOverdrive) {
        combo += 2;
        score += (25 * combo) * rewardMult;
        earned = 4 * rewardMult;
      } else {
        // Safe play: immediate next planet -> standard reward, resets leap combo streak
        combo = 0;
        score += 10;
        earned = 1;
      }
    } else if (skippedPlanets == 1) {
      // Single Orbit Leap (1 planet skipped): combo streak scales rewards (8 -> 15 -> 25+)
      combo += isOverdrive ? 2 : 1;
      score += (50 * combo) * rewardMult;
      if (combo == 1) {
        earned = 8;
      } else if (combo == 2) {
        earned = 15;
      } else {
        earned = (25 + (combo - 3) * 10) * rewardMult;
      }
    } else {
      // Double+ Orbit Leap (2 or more planets skipped): high-mastery bonus
      combo += isOverdrive ? 2 : 1;
      score += (150 * combo) * rewardMult;
      earned = (25 + (combo - 1) * 15) * rewardMult;
    }

    runStarDust += earned;
    sectorStarDust += earned;
    levelStarDust = sectorStarDust;
    capturesInLevel++;
    totalCaptures++;
    if (combo > maxCombo) {
      maxCombo = combo;
    }

    player.angle = atan2(player.y - planet.y, player.x - planet.x);
    player.isOrbiting = true;
    player.vx = 0;
    player.vy = 0;
    player.x = planet.x + cos(player.angle) * planet.radius;
    player.y = planet.y + sin(player.angle) * planet.radius;
    flightTime = 0;

    // Catch resonance shockwave on the captured planet
    spawnShockwave(
      planet.x,
      planet.y,
      startR: planet.radius * 0.85,
      maxR: planet.radius * 1.42,
      duration: 0.38,
      isLaunch: false,
    );
    // Landing Zoom-In Punch on EVERY capture (stronger on Orbit Leaps)
    cameraZoomPunch = max(cameraZoomPunch, skippedPlanets > 0 ? 0.095 : 0.055);
    if (skippedPlanets > 0) {
      triggerCameraShake(skippedPlanets >= 2 ? 5.0 : 2.8);
      // 50-65ms micro hit-stop / time dilation exclusively on Orbit Leaps
      triggerHitStop(skippedPlanets >= 2 ? 0.065 : 0.052);
    }

    // ─── Entry-Only Power-Up Check ───────────────────────────────────────────
    bool collectedPowerUpOnEntry = false;
    OrbitPowerUpType? collectedType;
    if (planet.powerUp != null) {
      if (!isSyntheticCenterTeleport && planet.isAngleNearPowerUp(player.angle)) {
        // Collected on orbit entry!
        collectedType = planet.powerUp!;
        planet.powerUp = null;
        collectedPowerUpOnEntry = true;
        _activatePowerUp(collectedType);
      } else if (!isSyntheticCenterTeleport) {
        // Missed the power-up angle on entry -> immediately vanishes!
        planet.vanishedPowerUpType = planet.powerUp;
        planet.vanishedPowerUpAngle = planet.powerUpAngle;
        planet.powerUpVanishTimer = 0.45;
        planet.powerUp = null;
      }
    }

    // ─── Time Attack Time Bonus ──────────────────────────────────────────────
    if (mode == GameMode.timeAttack) {
      double bonusSec = 2.0;
      if (skippedPlanets >= 1) {
        bonusSec = 5.0;
      } else if (collectedPowerUpOnEntry) {
        bonusSec = 3.0;
      }
      timeRemaining = (timeRemaining + bonusSec).clamp(0.0, 99.0);
      lastTimeBonus = bonusSec;
      timeBonusDisplayTimer = 1.1;
    }

    // Ensure there are always at least 5 upcoming planets ahead of player
    while (planets.length - currentPlanetIndex < 6) {
      planets.add(endlessManager.generateNextPlanet());
    }

    // If Quantum Leap was collected, warp through the next 2 planets immediately!
    if (collectedType == OrbitPowerUpType.quantumLeap) {
      _executeQuantumLeap();
    }

    // Prune distant off-screen planets behind player to prevent memory leaks and GC pressure
    if (currentPlanetIndex > 3) {
      final pruneCount = currentPlanetIndex - 3;
      planets.removeRange(0, pruneCount);
      currentPlanetIndex -= pruneCount;
    }

    nextPlanetIndex = currentPlanetIndex + 1;
    if (collectedType != null) {
      onPowerUpCollected?.call(collectedType);
    }
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

  void _activatePowerUp(OrbitPowerUpType type) {
    switch (type) {
      case OrbitPowerUpType.aegisShield:
        hasAegisShield = true;
        break;
      case OrbitPowerUpType.gravityWell:
        gravityWellCharges = 3;
        break;
      case OrbitPowerUpType.chronoWarp:
        chronoWarpRemaining = 6.0;
        break;
      case OrbitPowerUpType.overdriveSurge:
        overdriveCharges = 4;
        break;
      case OrbitPowerUpType.quantumLeap:
        // Handled in _executeQuantumLeap() right after upcoming planets are generated
        break;
    }
  }

  void _executeQuantumLeap() {
    while (planets.length - currentPlanetIndex < 6) {
      planets.add(endlessManager.generateNextPlanet());
    }
    final targetIdx = min(planets.length - 1, currentPlanetIndex + 2);
    for (int k = currentPlanetIndex + 1; k <= targetIdx; k++) {
      planets[k].cleared = true;
      planets[k].hasHazard = false;
      planets[k].powerUp = null;
      spawnShockwave(
        planets[k].x,
        planets[k].y,
        startR: planets[k].radius * 0.5,
        maxR: planets[k].radius * 1.75,
        duration: 0.48,
        isLaunch: false,
        isShieldBurst: true,
      );
    }
    currentPlanetIndex = targetIdx;
    final dest = planets[currentPlanetIndex];
    dest.update(totalElapsed);
    combo += 2;
    score += 250;
    runStarDust += 15;
    sectorStarDust += 15;
    levelStarDust = sectorStarDust;
    capturesInLevel += 2;
    totalCaptures += 2;
    if (combo > maxCombo) {
      maxCombo = combo;
    }

    player.angle = -pi * 0.5;
    player.isOrbiting = true;
    player.vx = 0;
    player.vy = 0;
    player.x = dest.x + cos(player.angle) * dest.radius;
    player.y = dest.y + sin(player.angle) * dest.radius;
    triggerCameraShake(6.5);
    triggerHitStop(0.060);
    cameraZoomPunch = 0.11;
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

  /// Smoothly interpolate camera towards target and update FOV zoom & micro-shake.
  void smoothCamera(double dt) {
    if (!player.isOrbiting && currentPlanetIndex >= 0 && currentPlanetIndex + 1 < planets.length) {
      // Dynamic camera anticipation during free flight towards next planet
      final nextPlanet = planets[currentPlanetIndex + 1];
      targetCameraY = ((planets[currentPlanetIndex].y + nextPlanet.y) / 2) - screenHeight * 0.75;
    }

    final diff = targetCameraY - cameraY;
    final factor = 1.0 - exp(-cameraSmoothSpeed * dt);
    cameraY += diff * factor;

    // Decay launch/landing zoom impulse
    if (cameraZoomPunch.abs() > 0.0005) {
      cameraZoomPunch *= exp(-10.5 * dt);
    } else {
      cameraZoomPunch = 0.0;
    }

    // Dynamic FOV zoom:
    // - During flight: rapidly pulls out to 0.885 (and down to 0.84 on longer multi-planet leaps)
    // - On orbit catch: springs in with cameraZoomPunch overshoot (1.055..1.11) and settles to 1.0
    final baseZoom = player.isOrbiting
        ? 1.0
        : (0.885 - flightTime * 0.09).clamp(0.84, 0.885);
    final targetZoom = (baseZoom + cameraZoomPunch).clamp(0.80, 1.14);
    final zoomLerpSpeed = player.isOrbiting ? 15.0 : 19.0;
    cameraZoom += (targetZoom - cameraZoom) * (1.0 - exp(-zoomLerpSpeed * dt));

    // Update decaying tactile micro-shake
    if (shakeTimer > 0) {
      shakeTimer = max(0.0, shakeTimer - dt);
      final currentMag = shakeIntensity * (shakeTimer / 0.18).clamp(0.0, 1.0);
      shakeOffsetX = sin(totalElapsed * 95.0) * currentMag;
      shakeOffsetY = cos(totalElapsed * 115.0) * currentMag;
      if (shakeTimer <= 0) {
        shakeIntensity = 0.0;
        shakeOffsetX = 0.0;
        shakeOffsetY = 0.0;
      }
    } else {
      shakeOffsetX = 0.0;
      shakeOffsetY = 0.0;
    }
  }
}
