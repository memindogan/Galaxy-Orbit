/// CustomPainter that renders the entire in-game universe:
/// deep space parallax stars, 3D cratered planets with atmospheric rim lighting,
/// concentric resonance ripple on next target, capture indicators,
/// satellite probe vessels matching the 12 hangar fleet worlds, and luminous plasma thruster trails.
library;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/theme_constants.dart';
import '../engine/game_engine.dart';
import '../models/cosmic_customization.dart';
import '../models/fleet_planet.dart';
import '../models/planet.dart';
import '../models/player_dot.dart';
import '../providers/settings_provider.dart';

class _ParallaxStarData {
  final double nx;
  final double worldY;
  final double layer;
  final double radius;
  final double twinkleSpeed;

  const _ParallaxStarData({
    required this.nx,
    required this.worldY,
    required this.layer,
    required this.radius,
    required this.twinkleSpeed,
  });
}

/// Pre-computed per-world colors and GPU radial gradient shaders to avoid
/// per-frame Color allocations and expensive multi-pass MaskFilter.blur FBO switches.
class _WorldVisualStyle {
  final bool isRinged;
  final Color clearedBodyColor;
  final Color currentOrbitColor;
  final Color outerRingColor;
  final Color innerRingColor;
  final Color rimColor;
  final Color trailGlowColor;
  final Color guideColor;
  final Paint haloPaint;
  final Paint lowQualityHaloPaint;
  final Paint playerHaloPaint;

  _WorldVisualStyle(FleetPlanet world)
      : isRinged = world.id == 'chronos' ||
            world.id == 'aether' ||
            world.id == 'eclipse' ||
            world.id == 'void',
        clearedBodyColor = world.primaryColor.withValues(alpha: 0.16),
        currentOrbitColor = world.primaryColor.withValues(alpha: 0.58),
        outerRingColor = world.primaryColor.withValues(alpha: 0.55),
        innerRingColor = world.primaryColor.withValues(alpha: 0.35),
        rimColor = world.glowColor.withValues(alpha: 0.75),
        trailGlowColor = world.glowColor.withValues(alpha: 0.32),
        guideColor = world.companionColor.withValues(alpha: 0.20),
        lowQualityHaloPaint = Paint()
          ..color = world.glowColor.withValues(alpha: 0.22),
        haloPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              world.glowColor.withValues(alpha: 0.42),
              world.glowColor.withValues(alpha: 0.16),
              world.glowColor.withValues(alpha: 0.0),
            ],
            stops: const [0.48, 0.76, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.0)),
        playerHaloPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              world.companionColor.withValues(alpha: 0.52),
              world.companionColor.withValues(alpha: 0.18),
              world.companionColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.0));
}

class GamePainter extends CustomPainter {
  final GameEngine engine;
  final bool colorBlindMode;
  final GraphicsQuality graphicsQuality;
  final bool reducedMotion;
  final bool isTurkish;
  final FleetPlanet equippedPlanet;
  final CosmicCustomization equippedCustomization;
  final Map<String, ui.Image>? planetImages;

  // ─── Pre-allocated static resources ────────────────────────────────────────
  static final List<_ParallaxStarData> _staticStars = () {
    final rng = Random(42);
    return List.generate(90, (i) {
      final nx = rng.nextDouble();
      final y = (rng.nextDouble() * 12000) - 6000;
      final layer = rng.nextDouble();
      final radius = 0.5 + layer * 1.6;
      final speed = 1.5 + layer * 2;
      return _ParallaxStarData(
        nx: nx,
        worldY: y,
        layer: layer,
        radius: radius,
        twinkleSpeed: speed,
      );
    });
  }();

  static final Paint _unitLightPaint = Paint()
    ..shader = const RadialGradient(
      colors: [
        Color(0x5CFFFFFF), // alpha 0.36
        Color(0x00FFFFFF),
      ],
      stops: [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: const Offset(-0.32, -0.32), radius: 0.95));

  static final Paint _unitShadowPaint = Paint()
    ..shader = const RadialGradient(
      colors: [
        Colors.transparent,
        Color(0xC2000000), // alpha 0.76
      ],
      stops: [0.35, 1.0],
    ).createShader(Rect.fromCircle(center: const Offset(0.22, 0.22), radius: 1.25));

  static final Paint _unitLimbPaint = Paint()
    ..shader = const RadialGradient(
      colors: [
        Colors.transparent,
        Color(0x73000000), // alpha 0.45
      ],
      stops: [0.72, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.0));

  static final Paint _cbPlayerHaloPaint = Paint()
    ..shader = const RadialGradient(
      colors: [
        Color(0x85FFD600),
        Color(0x2EFFD600),
        Color(0x00FFD600),
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1.0));

  static final List<Color> _whiteAlphaLut = List.generate(
    256,
    (a) => Color((a << 24) | 0x00FFFFFF),
    growable: false,
  );

  static final Map<String, _WorldVisualStyle> _worldStyles = {
    for (final w in FleetCatalog.worlds) w.id: _WorldVisualStyle(w),
  };

  static _WorldVisualStyle _styleFor(FleetPlanet world) =>
      _worldStyles[world.id] ?? (_worldStyles[world.id] = _WorldVisualStyle(world));

  // Pre-allocated geometry constants for vessels & rings
  static const Rect _fullTexSrcRect = Rect.fromLTWH(0, 0, 256, 256);
  static const Rect _ringClipBehind = Rect.fromLTRB(-2.0, -2.0, 2.0, 0.0);
  static const Rect _ringClipFront = Rect.fromLTRB(-2.0, 0.0, 2.0, 2.0);
  static const Rect _outerRingUnitRect = Rect.fromLTWH(-1.4, -0.375, 2.8, 0.75);
  static const Rect _innerRingUnitRect = Rect.fromLTWH(-1.15, -0.3, 2.3, 0.6);
  static const Rect _terraArcRect = Rect.fromLTWH(-5.2, -5.2, 10.4, 10.4);
  static final RRect _aetherWingTopRRect =
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -8.0, 8.0, 3.2), const Radius.circular(1.2));
  static final RRect _aetherWingBotRRect =
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, 4.8, 8.0, 3.2), const Radius.circular(1.2));
  static final RRect _aetherBodyRRect =
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4.0, -3.5, 8.0, 7.0), const Radius.circular(1.5));
  static const Rect _titanOvalRect = Rect.fromLTWH(-1.5, -1.25, 5.0, 2.5);
  static final RRect _orionWingTopRRect =
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -5.5, 9.0, 2.2), const Radius.circular(1.0));
  static final RRect _orionWingBotRRect =
      RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, 3.3, 9.0, 2.2), const Radius.circular(1.0));
  static const Rect _voidOvalRect = Rect.fromLTWH(-5.5, -3.5, 11.0, 7.0);

  // ─── Pre-allocated paints ────────────────────────────────────────────────
  final Paint _bgPaint = Paint()..color = kBackgroundColor;

  final Paint _orbitPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _clearedOrbitPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _nebulaPaint1 = Paint();
  final Paint _nebulaPaint2 = Paint();
  Shader? _cachedNebulaShader1;
  Shader? _cachedNebulaShader2;
  Offset _cachedNebulaCenter1 = Offset.zero;
  Offset _cachedNebulaCenter2 = Offset.zero;
  double _lastNebulaWidth = 0;
  double _lastNebulaHeight = 0;

  final Paint _starPaint = Paint()..style = PaintingStyle.fill;
  final Paint _crossPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6
    ..color = const Color(0x48FFFFFF);
  final Path _starCrossPath = Path();

  final Paint _guidePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Path _guidePath = Path();

  final Paint _clearedBodyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.6;
  final Paint _trailGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _trailCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _texPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _outerRingPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _innerRingPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _cbPlayerRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..color = const Color(0xFFFFD600);
  final Paint _cbMarkerPaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..style = PaintingStyle.fill;

  final Path _trailPath = Path();

  static final Paint _vesselFill = Paint()..style = PaintingStyle.fill;
  static final Paint _vesselStroke = Paint()..style = PaintingStyle.stroke;
  static final Path _vesselPath = Path();
  static final Path _vesselPath2 = Path();

  final Paint _procFill = Paint()..style = PaintingStyle.fill;
  final Paint _procStroke = Paint()..style = PaintingStyle.stroke;
  final Path _procPath = Path();
  final Paint _fxStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _fxFill = Paint()..style = PaintingStyle.fill;
  final Path _fxPath = Path();

  GamePainter({
    required this.engine,
    required this.colorBlindMode,
    this.graphicsQuality = GraphicsQuality.high,
    this.reducedMotion = false,
    this.isTurkish = false,
    FleetPlanet? equippedPlanet,
    CosmicCustomization? equippedCustomization,
    this.planetImages,
    super.repaint,
  })  : equippedPlanet = equippedPlanet ?? FleetCatalog.worlds.first,
        equippedCustomization = equippedCustomization ?? CustomizationCatalog.items.first;

  Color get _playerColor =>
      colorBlindMode ? const Color(0xFFFFD600) : equippedPlanet.companionColor;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Deep Space Background (zero Rect allocation) ───────────────────────
    canvas.drawPaint(_bgPaint);

    // ── Cosmic Nebula Glow ──────────────────────────────────────────────────
    _drawNebula(canvas, size);

    // ── Parallax Stars (with 45% depth-linked FOV zoom) ─────────────────────
    final zoom = engine.cameraZoom;
    final hasZoom = !reducedMotion && (zoom - 1.0).abs() > 0.001;
    if (hasZoom) {
      final starZoom = 1.0 + (zoom - 1.0) * 0.45;
      final scx = size.width * 0.5;
      final scy = size.height * 0.5;
      canvas.save();
      canvas.translate(scx, scy);
      canvas.scale(starZoom);
      canvas.translate(-scx, -scy);
      _drawParallaxStars(canvas, size);
      canvas.restore();
    } else {
      _drawParallaxStars(canvas, size);
    }

    // ── Screen-Space Combo & Overdrive Speed Lines ──────────────────────────
    if (!reducedMotion && (engine.combo >= 2 || engine.overdriveCharges > 0)) {
      _drawSpeedLines(canvas, size);
    }

    // ── Camera Transform (Dynamic FOV Zoom + Tactile Micro-Shake) ───────────
    canvas.save();
    if (!reducedMotion) {
      if (hasZoom) {
        double focalX = size.width * 0.5;
        double focalY = size.height * 0.65;
        if (engine.planets.isNotEmpty &&
            engine.currentPlanetIndex >= 0 &&
            engine.currentPlanetIndex < engine.planets.length) {
          final activePlanet = engine.planets[engine.currentPlanetIndex];
          final rawX = engine.player.isOrbiting ? activePlanet.x : engine.player.x;
          final rawY = (engine.player.isOrbiting ? activePlanet.y : engine.player.y) - engine.cameraY;
          focalX = rawX.clamp(size.width * 0.2, size.width * 0.8);
          focalY = rawY.clamp(size.height * 0.25, size.height * 0.82);
        }
        canvas.translate(focalX, focalY);
        canvas.scale(zoom);
        canvas.translate(-focalX, -focalY);
      }
      if (engine.shakeTimer > 0) {
        canvas.translate(engine.shakeOffsetX, engine.shakeOffsetY);
      }
    }
    canvas.translate(0, -engine.cameraY);

    if (engine.planets.isEmpty) {
      canvas.restore();
      return;
    }

    final planets = engine.planets;
    final player = engine.player;

    // ── Draw Tangent Guidance Line ──────────────────────────────────────────
    _drawAimGuidance(canvas);

    // ── Draw Planets with Frustum Culling ────────────────────────────────────
    final screenTop = engine.cameraY - 220.0;
    final screenBottom = engine.cameraY + size.height + 220.0;
    for (int i = 0; i < planets.length; i++) {
      final p = planets[i];
      if (p.y + p.radius < screenTop || p.y - p.radius > screenBottom) {
        continue; // Cull off-screen planet
      }
      _drawPlanet(canvas, p, i);
    }

    // ── Draw Launch Shockwaves & Catch Ripples ──────────────────────────────
    _drawShockwaves(canvas);

    // ── Draw Satellite Exhaust Trail ────────────────────────────────────────
    _drawTrail(canvas, player);

    // ── Draw Companion Satellite Vessel ─────────────────────────────────────
    _drawPlayer(canvas, player);

    canvas.restore();
  }

  // ─── Nebula Layer (Cached Shaders & Centers) ──────────────────────────────
  void _drawNebula(Canvas canvas, Size size) {
    if (graphicsQuality == GraphicsQuality.low || colorBlindMode) return;

    if (_cachedNebulaShader1 == null || _lastNebulaWidth != size.width || _lastNebulaHeight != size.height) {
      _lastNebulaWidth = size.width;
      _lastNebulaHeight = size.height;
      _cachedNebulaCenter1 = Offset(size.width * 0.8, size.height * 0.25);
      _cachedNebulaCenter2 = Offset(size.width * 0.2, size.height * 0.75);

      _cachedNebulaShader1 = const RadialGradient(
        colors: [
          Color(0x261E1B4B),
          Colors.transparent,
        ],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromCircle(
        center: _cachedNebulaCenter1,
        radius: size.width * 0.6,
      ));

      if (graphicsQuality == GraphicsQuality.high) {
        _cachedNebulaShader2 = const RadialGradient(
          colors: [
            Color(0x2E0F2B48),
            Colors.transparent,
          ],
          stops: [0.0, 1.0],
        ).createShader(Rect.fromCircle(
          center: _cachedNebulaCenter2,
          radius: size.width * 0.7,
        ));
      }
    }

    _nebulaPaint1.shader = _cachedNebulaShader1;
    canvas.drawCircle(
      _cachedNebulaCenter1,
      size.width * 0.6,
      _nebulaPaint1,
    );

    if (graphicsQuality == GraphicsQuality.high && _cachedNebulaShader2 != null) {
      _nebulaPaint2.shader = _cachedNebulaShader2;
      canvas.drawCircle(
        _cachedNebulaCenter2,
        size.width * 0.7,
        _nebulaPaint2,
      );
    }
  }

  // ─── Parallax Stars (Static Pre-computed Array + LUT + Endless Wrap) ─────
  void _drawParallaxStars(Canvas canvas, Size size) {
    final int starCount = switch (graphicsQuality) {
      GraphicsQuality.high => 90,
      GraphicsQuality.medium => 50,
      GraphicsQuality.low => 25,
    };

    final count = min(starCount, _staticStars.length);
    final span = size.height + 30.0;
    if (span <= 30.0) return;

    _starCrossPath.reset();
    bool hasCrosses = false;

    for (int i = 0; i < count; i++) {
      final s = _staticStars[i];
      final x = s.nx * size.width;
      final parallaxFactor = 0.06 + s.layer * 0.25;
      final rawY = (s.worldY - engine.cameraY * parallaxFactor) % span;
      final screenY = (rawY < 0 ? rawY + span : rawY) - 15.0;

      final twinkle = reducedMotion
          ? 0.85
          : 0.75 + 0.25 * sin(engine.totalElapsed * s.twinkleSpeed + i);
      final alpha = ((0.2 + s.layer * 0.7) * twinkle).clamp(0.0, 1.0);
      final aInt = (alpha * 255).toInt().clamp(0, 255);
      _starPaint.color = _whiteAlphaLut[aInt];
      canvas.drawCircle(Offset(x, screenY), s.radius, _starPaint);

      if (s.layer > 0.85 && s.radius > 1.6) {
        hasCrosses = true;
        _starCrossPath.moveTo(x - 3.0, screenY);
        _starCrossPath.lineTo(x + 3.0, screenY);
        _starCrossPath.moveTo(x, screenY - 3.0);
        _starCrossPath.lineTo(x, screenY + 3.0);
      }
    }

    if (hasCrosses) {
      canvas.drawPath(_starCrossPath, _crossPaint);
    }
  }

  // ─── Tangent Aim Guidance ─────────────────────────────────────────────────
  void _drawAimGuidance(Canvas canvas) {
    if (!engine.player.isOrbiting) return;
    if (engine.currentPlanetIndex < 0 || engine.currentPlanetIndex >= engine.planets.length) return;

    final currentPlanet = engine.planets[engine.currentPlanetIndex];
    final player = engine.player;

    // Calculate tangent launch vector
    final sign = currentPlanet.rotationSpeed >= 0 ? 1.0 : -1.0;
    final dirX = -sin(player.angle) * sign;
    final dirY = cos(player.angle) * sign;
    final px = player.x;
    final py = player.y;

    _guidePath.reset();

    if (colorBlindMode) {
      // High-contrast accessibility guide: vivid amber dashed line with terminal directional arrow
      _guidePaint.color = const Color(0xE6FFD600);
      _guidePaint.strokeWidth = 2.0;

      for (int d = 12; d < 110; d += 16) {
        _guidePath.moveTo(px + dirX * d, py + dirY * d);
        _guidePath.lineTo(px + dirX * (d + 9), py + dirY * (d + 9));
      }

      // Draw high-visibility chevron / arrowhead at the tip
      final tipX = px + dirX * 116;
      final tipY = py + dirY * 116;
      final normalX = -dirY;
      final normalY = dirX;
      final baseX = tipX - dirX * 9;
      final baseY = tipY - dirY * 9;
      _guidePath.moveTo(tipX, tipY);
      _guidePath.lineTo(baseX + normalX * 6, baseY + normalY * 6);
      _guidePath.moveTo(tipX, tipY);
      _guidePath.lineTo(baseX - normalX * 6, baseY - normalY * 6);
      canvas.drawPath(_guidePath, _guidePaint);
    } else {
      _guidePaint.color = _styleFor(equippedPlanet).guideColor;
      _guidePaint.strokeWidth = 1.0;

      for (int d = 12; d < 80; d += 14) {
        _guidePath.moveTo(px + dirX * d, py + dirY * d);
        _guidePath.lineTo(px + dirX * (d + 6), py + dirY * (d + 6));
      }
      canvas.drawPath(_guidePath, _guidePaint);
    }
  }

  // ─── Draw Celestial Body ──────────────────────────────────────────────────
  void _drawPlanet(Canvas canvas, Planet planet, int index) {
    final center = Offset(planet.x, planet.y);
    final coreRadius = planet.radius * 0.52;
    final isCurrent = index == engine.currentPlanetIndex;
    final isCleared = planet.cleared && !isCurrent;

    final world = planet.fleetPlanet;
    final style = _styleFor(world);

    // ── Cleared State: Subdued Silhouette ──
    if (isCleared) {
      _clearedOrbitPaint.color = colorBlindMode
          ? const Color(0x1F00E5FF)
          : const Color(0x1F8CEFFF);
      canvas.drawCircle(center, planet.radius, _clearedOrbitPaint);

      _clearedBodyPaint.color = style.clearedBodyColor;
      canvas.drawCircle(center, coreRadius, _clearedBodyPaint);
      return;
    }

    // ── Gravitational Orbit Ring ──
    final isTarget = index == engine.currentPlanetIndex + 1;
    if (colorBlindMode) {
      if (isCurrent) {
        _orbitPaint.color = const Color(0xD9FFD600);
        _orbitPaint.strokeWidth = 2.2;
        canvas.drawCircle(center, planet.radius, _orbitPaint);
      } else if (isTarget) {
        // High-contrast target planet orbit: electric cyan with distinct 4-quadrant cross-markers
        _orbitPaint.color = const Color(0xE600E5FF);
        _orbitPaint.strokeWidth = 2.4;
        canvas.drawCircle(center, planet.radius, _orbitPaint);

        // Draw 4 cardinal catch-target markers on the orbit perimeter
        final r = planet.radius;
        canvas.drawCircle(Offset(center.dx + r, center.dy), 3.0, _cbMarkerPaint);
        canvas.drawCircle(Offset(center.dx, center.dy + r), 3.0, _cbMarkerPaint);
        canvas.drawCircle(Offset(center.dx - r, center.dy), 3.0, _cbMarkerPaint);
        canvas.drawCircle(Offset(center.dx, center.dy - r), 3.0, _cbMarkerPaint);
      } else {
        _orbitPaint.color = const Color(0x5900E5FF);
        _orbitPaint.strokeWidth = 1.2;
        canvas.drawCircle(center, planet.radius, _orbitPaint);
      }
    } else {
      _orbitPaint.strokeWidth = 1.0;
      _orbitPaint.color = isCurrent
          ? style.currentOrbitColor
          : const Color(0x528CEFFF);
      canvas.drawCircle(center, planet.radius, _orbitPaint);
    }

    // ── Atmospheric Outer Halo Glow (Single-pass GPU Radial Shader instead of MaskFilter.blur) ──
    if (graphicsQuality == GraphicsQuality.low) {
      canvas.drawCircle(center, coreRadius + 5.0, style.lowQualityHaloPaint);
    } else {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(coreRadius + 15.0);
      canvas.drawCircle(Offset.zero, 1.0, style.haloPaint);
      canvas.restore();
    }

    // ── Planetary Rings for Ringed Worlds (Chronos, Aether, Eclipse, Void) ──
    if (style.isRinged) {
      _drawPlanetaryRings(canvas, center, coreRadius, style, behind: true);
    }

    // ── 3D Spherical Core (Pre-masked Circular Image Texture or Procedural) ──
    final texImage = planetImages?[world.id];
    if (texImage != null) {
      // Texture is pre-cropped and pre-clipped to a crisp anti-aliased circle at load time!
      final dst = Rect.fromCircle(center: center, radius: coreRadius);
      canvas.drawImageRect(
        texImage,
        _fullTexSrcRect,
        dst,
        _texPaint,
      );
      _draw3DSphericalShading(canvas, center, coreRadius);
    } else {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromCircle(center: center, radius: coreRadius),
        Radius.circular(coreRadius),
      ));
      _drawProceduralSurface(canvas, center, coreRadius, world);
      _draw3DSphericalShading(canvas, center, coreRadius);
      canvas.restore();
    }

    // ── Foreground Portion of Planetary Rings ──
    if (style.isRinged) {
      _drawPlanetaryRings(canvas, center, coreRadius, style, behind: false);
    }

    // ── Atmospheric Sunlit Rim Light Arc ──
    _rimPaint.color = style.rimColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: coreRadius - 0.5),
      -2.4,
      2.0,
      false,
      _rimPaint,
    );

    // ── Gravity Well Expanded Capture Boundary (when active on target) ──
    if (isTarget && engine.gravityWellCharges > 0) {
      final pulse = reducedMotion ? 0.5 : (0.5 + 0.5 * sin(engine.totalElapsed * 6.0));
      _fxStroke.strokeWidth = 1.4;
      _fxStroke.color = const Color(0xFFC084FC).withValues(alpha: 0.28 + 0.22 * pulse);
      canvas.drawCircle(center, planet.radius + engine.effectiveCatchRadius * 0.65, _fxStroke);
    }

    // ── Rotating Hazard Shield Arc & Shatter Effect (Level 7+) ──
    if (planet.hasHazard || planet.hazardShatterTimer > 0) {
      _drawPlanetHazard(canvas, center, planet);
    }

    // ── Orbit-Entry Power-Up Icon & Miss-Vanish Effect ──
    if (planet.powerUp != null || planet.powerUpVanishTimer > 0) {
      _drawPlanetPowerUp(canvas, center, planet);
    }
  }

  // ─── Rotating Hazard Barrier & Shatter Animation (Level 7+) ───────────────
  void _drawPlanetHazard(Canvas canvas, Offset center, Planet planet) {
    final barrierRadius = planet.radius + 5.5;
    final hazardColor = colorBlindMode ? const Color(0xFFFF1744) : const Color(0xFFFF453A);

    if (planet.hasHazard) {
      final arcRect = Rect.fromCircle(center: center, radius: barrierRadius);
      // Outer warning glow
      _fxStroke.strokeWidth = 6.5;
      _fxStroke.color = hazardColor.withValues(alpha: 0.28);
      canvas.drawArc(arcRect, planet.hazardAngle, planet.hazardSweep, false, _fxStroke);

      // Core plasma laser arc
      _fxStroke.strokeWidth = 2.6;
      _fxStroke.color = hazardColor;
      canvas.drawArc(arcRect, planet.hazardAngle, planet.hazardSweep, false, _fxStroke);

      // End-cap nodes on the arc barrier
      final startX = center.dx + cos(planet.hazardAngle) * barrierRadius;
      final startY = center.dy + sin(planet.hazardAngle) * barrierRadius;
      final endAngle = planet.hazardAngle + planet.hazardSweep;
      final endX = center.dx + cos(endAngle) * barrierRadius;
      final endY = center.dy + sin(endAngle) * barrierRadius;
      _fxFill.color = Colors.white;
      canvas.drawCircle(Offset(startX, startY), 2.8, _fxFill);
      canvas.drawCircle(Offset(endX, endY), 2.8, _fxFill);
    } else if (planet.hazardShatterTimer > 0) {
      // Shattering barrier fragments when broken by Aegis Shield
      final t = (1.0 - (planet.hazardShatterTimer / 0.55)).clamp(0.0, 1.0);
      final expandR = barrierRadius + t * 26.0;
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      _fxStroke.strokeWidth = 2.4 * alpha;
      _fxStroke.color = const Color(0xFF34D399).withValues(alpha: alpha);
      final segSweep = planet.hazardSweep / 5.0;
      final rect = Rect.fromCircle(center: center, radius: expandR);
      for (int s = 0; s < 5; s++) {
        final a = planet.hazardAngle + s * (segSweep + 0.08 * t);
        canvas.drawArc(rect, a, segSweep * (1.0 - 0.5 * t), false, _fxStroke);
      }
    }
  }

  // ─── Orbiting Power-Up & Vanish Dissolve Effect (1:1 Concept Sheet Icons) ──
  void _drawPlanetPowerUp(Canvas canvas, Offset center, Planet planet) {
    if (planet.powerUp != null) {
      final type = planet.powerUp!;
      final angle = planet.powerUpAngle;
      final px = center.dx + cos(angle) * planet.radius;
      final py = center.dy + sin(angle) * planet.radius;
      final pos = Offset(px, py);

      final Color color = switch (type) {
        OrbitPowerUpType.aegisShield => const Color(0xFF00F0FF),
        OrbitPowerUpType.gravityWell => const Color(0xFFB388FF),
        OrbitPowerUpType.chronoWarp => const Color(0xFF00E676),
        OrbitPowerUpType.overdriveSurge => const Color(0xFFFFD600),
        OrbitPowerUpType.quantumLeap => const Color(0xFFFF4081),
      };

      final pulse = reducedMotion ? 1.0 : (0.92 + 0.12 * sin(engine.totalElapsed * 7.0));
      // Outer glassmorphic aura
      _fxFill.color = color.withValues(alpha: 0.24);
      canvas.drawCircle(pos, 13.0 * pulse, _fxFill);

      // Dark glassmorphic circular badge
      _fxFill.color = const Color(0xEB071022);
      canvas.drawCircle(pos, 9.8, _fxFill);

      // Glowing neon rim
      _fxStroke.strokeWidth = 1.3;
      _fxStroke.color = color.withValues(alpha: 0.90);
      canvas.drawCircle(pos, 9.8 * pulse, _fxStroke);

      canvas.save();
      canvas.translate(px, py);
      drawPowerUpGlyph(canvas, type, color, 6.2, _fxFill, _fxStroke, _fxPath);
      canvas.restore();
    } else if (planet.powerUpVanishTimer > 0) {
      // Missed on orbit entry -> dissolving particle burst!
      final t = (1.0 - (planet.powerUpVanishTimer / 0.45)).clamp(0.0, 1.0);
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final angle = planet.vanishedPowerUpAngle;
      final px = center.dx + cos(angle) * planet.radius;
      final py = center.dy + sin(angle) * planet.radius;
      _fxFill.color = Colors.white.withValues(alpha: alpha * 0.8);
      for (int i = 0; i < 6; i++) {
        final a = i * (pi / 3.0) + t * 1.2;
        final dist = 4.0 + t * 16.0;
        canvas.drawCircle(
          Offset(px + cos(a) * dist, py + sin(a) * dist),
          2.2 * alpha,
          _fxFill,
        );
      }
    }
  }

  /// Shared 1:1 vector renderer for the 5 Power-Up Mini Icons (used by Canvas & HUD Badges).
  static void drawPowerUpGlyph(
    Canvas canvas,
    OrbitPowerUpType type,
    Color color,
    double r,
    Paint fillPaint,
    Paint strokePaint,
    Path path,
  ) {
    strokePaint.color = color;
    fillPaint.color = color;

    switch (type) {
      case OrbitPowerUpType.aegisShield:
        // 1. Aegis Shield: Crest shield with honeycomb hex core + 4 corner deflection brackets
        path.reset();
        path.moveTo(0, -r * 0.85);
        path.lineTo(r * 0.72, -r * 0.48);
        path.lineTo(r * 0.58, r * 0.35);
        path.lineTo(0, r * 0.88);
        path.lineTo(-r * 0.58, r * 0.35);
        path.lineTo(-r * 0.72, -r * 0.48);
        path.close();
        fillPaint.color = color.withValues(alpha: 0.25);
        canvas.drawPath(path, fillPaint);
        strokePaint.strokeWidth = r * 0.22;
        canvas.drawPath(path, strokePaint);

        // Inner hex cell
        path.reset();
        for (int i = 0; i < 6; i++) {
          final a = i * (pi / 3.0) - pi / 6.0;
          final hx = cos(a) * r * 0.34;
          final hy = sin(a) * r * 0.34;
          if (i == 0) {
            path.moveTo(hx, hy);
          } else {
            path.lineTo(hx, hy);
          }
        }
        path.close();
        strokePaint.strokeWidth = r * 0.14;
        canvas.drawPath(path, strokePaint);

        // 4 outer magnetic corner deflection arcs
        final arcRect = Rect.fromCircle(center: Offset.zero, radius: r * 1.12);
        strokePaint.strokeWidth = r * 0.18;
        canvas.drawArc(arcRect, -2.65, 0.55, false, strokePaint);
        canvas.drawArc(arcRect, -1.05, 0.55, false, strokePaint);
        canvas.drawArc(arcRect, 0.50, 0.55, false, strokePaint);
        canvas.drawArc(arcRect, 2.10, 0.55, false, strokePaint);
        break;

      case OrbitPowerUpType.gravityWell:
        // 2. Gravity Well: Inward-spiraling vortex arcs + bright white/violet singularity core
        strokePaint.strokeWidth = r * 0.18;
        final outerRect = Rect.fromCircle(center: Offset.zero, radius: r * 0.98);
        final midRect = Rect.fromCircle(center: Offset.zero, radius: r * 0.64);
        canvas.drawArc(outerRect, 0.2, 2.3, false, strokePaint);
        canvas.drawArc(outerRect, 3.3, 2.3, false, strokePaint);
        strokePaint.color = color.withValues(alpha: 0.85);
        canvas.drawArc(midRect, 1.1, 2.4, false, strokePaint);
        canvas.drawArc(midRect, 4.2, 2.4, false, strokePaint);

        // Bright singularity core
        fillPaint.color = color;
        canvas.drawCircle(Offset.zero, r * 0.36, fillPaint);
        fillPaint.color = Colors.white;
        canvas.drawCircle(Offset.zero, r * 0.20, fillPaint);
        break;

      case OrbitPowerUpType.chronoWarp:
        // 3. Chrono Warp: Celestial hourglass + tilted orbital ring with time droplets
        strokePaint.strokeWidth = r * 0.20;
        // Top & bottom caps
        canvas.drawLine(Offset(-r * 0.56, -r * 0.86), Offset(r * 0.56, -r * 0.86), strokePaint);
        canvas.drawLine(Offset(-r * 0.56, r * 0.86), Offset(r * 0.56, r * 0.86), strokePaint);

        // Hourglass bulbs
        path.reset();
        path.moveTo(-r * 0.48, -r * 0.84);
        path.lineTo(r * 0.48, -r * 0.84);
        path.lineTo(r * 0.10, 0);
        path.lineTo(r * 0.48, r * 0.84);
        path.lineTo(-r * 0.48, r * 0.84);
        path.lineTo(-r * 0.10, 0);
        path.close();
        fillPaint.color = color.withValues(alpha: 0.22);
        canvas.drawPath(path, fillPaint);
        strokePaint.strokeWidth = r * 0.17;
        canvas.drawPath(path, strokePaint);

        // Tilted orbital ring + suspended droplet
        canvas.save();
        canvas.rotate(-0.45);
        strokePaint.strokeWidth = r * 0.15;
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: r * 2.15, height: r * 0.78),
          strokePaint,
        );
        fillPaint.color = Colors.white;
        canvas.drawCircle(Offset(-r * 0.92, r * 0.14), r * 0.18, fillPaint);
        canvas.drawCircle(Offset(r * 0.88, -r * 0.14), r * 0.15, fillPaint);
        canvas.restore();
        break;

      case OrbitPowerUpType.overdriveSurge:
        // 4. Overdrive Surge: Sharp central lightning bolt + twin side shockwave arcs
        path.reset();
        path.moveTo(r * 0.18, -r * 0.98);
        path.lineTo(-r * 0.48, r * 0.06);
        path.lineTo(r * 0.04, r * 0.06);
        path.lineTo(-r * 0.22, r * 0.98);
        path.lineTo(r * 0.52, -r * 0.08);
        path.lineTo(0, -r * 0.08);
        path.close();
        fillPaint.color = color;
        canvas.drawPath(path, fillPaint);

        // Left & right high-voltage shockwave arcs
        strokePaint.strokeWidth = r * 0.18;
        final waveRect = Rect.fromCircle(center: Offset.zero, radius: r * 0.96);
        canvas.drawArc(waveRect, -0.55, 1.10, false, strokePaint);
        canvas.drawArc(waveRect, pi - 0.55, 1.10, false, strokePaint);
        break;

      case OrbitPowerUpType.quantumLeap:
        // 5. Quantum Leap: Circular wormhole portal ring + streaking rocket ship
        strokePaint.strokeWidth = r * 0.22;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r * 0.82),
          0.55,
          4.8,
          false,
          strokePaint,
        );

        // Streaking rocket ship angled at -35 deg
        canvas.save();
        canvas.rotate(-0.58);
        // Warp trail line
        strokePaint.strokeWidth = r * 0.18;
        canvas.drawLine(Offset(-r * 1.15, 0), Offset(-r * 0.20, 0), strokePaint);

        // Rocket body
        path.reset();
        path.moveTo(r * 1.05, 0);
        path.lineTo(r * 0.20, -r * 0.36);
        path.lineTo(-r * 0.35, -r * 0.24);
        path.lineTo(-r * 0.35, r * 0.24);
        path.lineTo(r * 0.20, r * 0.36);
        path.close();
        fillPaint.color = color;
        canvas.drawPath(path, fillPaint);

        // Cockpit window dot
        fillPaint.color = const Color(0xFF091426);
        canvas.drawCircle(Offset(r * 0.32, 0), r * 0.13, fillPaint);
        canvas.restore();
        break;
    }
  }

  // ─── Planetary Rings (Zero Rect allocation via Unit Scale) ────────────────
  void _drawPlanetaryRings(
    Canvas canvas,
    Offset center,
    double coreRadius,
    _WorldVisualStyle style, {
    required bool behind,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35); // tilt angle
    canvas.scale(coreRadius);

    // Clip to only draw behind or in front of the sphere using const unit rects
    canvas.clipRect(behind ? _ringClipBehind : _ringClipFront);

    _outerRingPaint.color = style.outerRingColor;
    _outerRingPaint.strokeWidth = 2.0 / coreRadius;
    canvas.drawOval(_outerRingUnitRect, _outerRingPaint);

    _innerRingPaint.color = style.innerRingColor;
    _innerRingPaint.strokeWidth = 1.0 / coreRadius;
    canvas.drawOval(_innerRingUnitRect, _innerRingPaint);

    canvas.restore();
  }

  // ─── 3D Spherical Shading (Zero-allocation Unit Shaders) ───────────────────
  void _draw3DSphericalShading(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    canvas.drawCircle(Offset.zero, 1.0, _unitLightPaint);
    canvas.drawCircle(Offset.zero, 1.0, _unitShadowPaint);
    canvas.drawCircle(Offset.zero, 1.0, _unitLimbPaint);
    canvas.restore();
  }

  // ─── Procedural Surface Fallback ──────────────────────────────────────────
  void _drawProceduralSurface(
    Canvas canvas,
    Offset center,
    double radius,
    FleetPlanet world,
  ) {
    _procFill.color = world.primaryColor;
    canvas.drawCircle(center, radius, _procFill);

    if (world.category.toLowerCase().contains('desert') || world.id == 'ember') {
      _procFill.color = const Color(0xFF450A0A).withValues(alpha: 0.65);
      _procStroke.color = world.glowColor.withValues(alpha: 0.55);
      _procStroke.strokeWidth = 1.2;

      final craters = [
        Offset(-radius * 0.32, -radius * 0.28),
        Offset(radius * 0.35, radius * 0.12),
        Offset(-radius * 0.15, radius * 0.38),
        Offset(radius * 0.05, -radius * 0.1),
      ];
      final sizes = [radius * 0.22, radius * 0.28, radius * 0.18, radius * 0.15];

      for (int i = 0; i < craters.length; i++) {
        final pos = center + craters[i];
        final r = sizes[i];
        canvas.drawCircle(pos, r, _procFill);
        canvas.drawArc(
          Rect.fromCircle(center: pos, radius: r),
          -2.6,
          1.8,
          false,
          _procStroke,
        );
      }
    } else if (world.category.toLowerCase().contains('gas') || world.id == 'aether' || world.id == 'eclipse') {
      final bandColors = [
        world.glowColor.withValues(alpha: 0.6),
        world.primaryColor.withValues(alpha: 0.5),
        Colors.white.withValues(alpha: 0.35),
      ];
      _procStroke.strokeWidth = radius * 0.22;
      for (int b = -2; b <= 2; b++) {
        _procStroke.color = bandColors[(b.abs()) % bandColors.length];
        canvas.drawArc(
          Rect.fromCircle(center: center + Offset(0, b * radius * 0.26), radius: radius * 1.05),
          -0.4,
          3.9,
          false,
          _procStroke,
        );
      }
    } else if (world.category.toLowerCase().contains('cryo') || world.id == 'titan') {
      _procStroke.color = world.glowColor.withValues(alpha: 0.55);
      _procStroke.strokeWidth = 1.0;
      _procPath.reset();
      _procPath.moveTo(center.dx - radius * 0.6, center.dy - radius * 0.4);
      _procPath.lineTo(center.dx - radius * 0.1, center.dy);
      _procPath.lineTo(center.dx + radius * 0.5, center.dy - radius * 0.3);
      _procPath.moveTo(center.dx - radius * 0.1, center.dy);
      _procPath.lineTo(center.dx + radius * 0.2, center.dy + radius * 0.5);
      canvas.drawPath(_procPath, _procStroke);
    } else if (world.category.toLowerCase().contains('plasma') || world.id == 'nova' || world.id == 'solaris') {
      _procStroke.color = world.glowColor.withValues(alpha: 0.5);
      _procStroke.strokeWidth = 2.0;
      canvas.drawCircle(center, radius * 0.65, _procStroke);
    } else {
      // Terrestrial or oceanic continents
      _procFill.color = const Color(0xFF22C55E).withValues(alpha: 0.55);
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(-radius * 0.25, -radius * 0.15),
          width: radius * 0.9,
          height: radius * 0.65,
        ),
        _procFill,
      );
      _procStroke.color = Colors.white.withValues(alpha: 0.38);
      _procStroke.strokeWidth = radius * 0.2;
      canvas.drawArc(
        Rect.fromCircle(center: center + Offset(0, -radius * 0.2), radius: radius * 0.7),
        -0.8,
        2.4,
        false,
        _procStroke,
      );
    }
  }

  static final Map<Color, List<Color>> _trailColorsCache = {};

  static List<Color> _getTrailColors(Color playerColor) {
    var list = _trailColorsCache[playerColor];
    if (list != null) return list;
    list = List.generate(20, (i) {
      final progress = i / 20.0;
      final alpha = ((1.0 - progress) * 0.95).clamp(0.0, 1.0);
      return Color.lerp(Colors.white, playerColor, progress * 0.7)!
          .withValues(alpha: alpha);
    });
    _trailColorsCache[playerColor] = list;
    return list;
  }

  // ─── Screen-Space Combo & Overdrive Speed Lines ───────────────────────────
  void _drawSpeedLines(Canvas canvas, Size size) {
    final intensity = ((engine.combo - 1) * 0.18 + (engine.overdriveCharges > 0 ? 0.45 : 0.0))
        .clamp(0.15, 0.85);
    final lineColor = engine.overdriveCharges > 0
        ? const Color(0xFFFBBF24)
        : equippedCustomization.primaryColor;
    _fxStroke.strokeWidth = 1.4;
    _fxStroke.color = lineColor.withValues(alpha: intensity * 0.32);

    const lineCount = 8;
    final h = size.height;
    for (int i = 0; i < lineCount; i++) {
      final isLeft = i.isEven;
      final x = isLeft ? (8.0 + (i * 3.5)) : (size.width - 8.0 - (i * 3.5));
      final phaseOffset = (engine.totalElapsed * 750.0 + i * 190.0) % (h + 140.0);
      final yStart = phaseOffset - 70.0;
      final len = 45.0 + (i % 3) * 24.0;
      canvas.drawLine(Offset(x, yStart), Offset(x, yStart + len), _fxStroke);
    }
  }

  // ─── Launch Shockwaves & Catch Ripples (4 Cosmic Styles) ──────────────────
  void _drawShockwaves(Canvas canvas) {
    final style = equippedCustomization.style;
    final primary = colorBlindMode ? const Color(0xFFFFD600) : equippedCustomization.primaryColor;
    final secondary = colorBlindMode ? const Color(0xFF00E5FF) : equippedCustomization.secondaryColor;

    for (int i = 0; i < engine.shockwaves.length; i++) {
      final sw = engine.shockwaves[i];
      if (!sw.active) continue;

      final t = sw.progress;
      final inv = (1.0 - t).clamp(0.0, 1.0);
      final r = sw.startRadius + (sw.maxRadius - sw.startRadius) * (1.0 - (1.0 - t) * (1.0 - t));
      final center = Offset(sw.x, sw.y);

      if (sw.isShieldBurst) {
        _fxStroke.strokeWidth = 3.2 * inv;
        _fxStroke.color = const Color(0xFF34D399).withValues(alpha: inv * 0.9);
        canvas.drawCircle(center, r, _fxStroke);
        _fxStroke.strokeWidth = 1.5 * inv;
        _fxStroke.color = Colors.white.withValues(alpha: inv * 0.7);
        canvas.drawCircle(center, r * 0.72, _fxStroke);
        continue;
      }

      if (!sw.isLaunch) {
        // Subtle planet catch resonance wave
        _fxStroke.strokeWidth = 1.8 * inv;
        _fxStroke.color = primary.withValues(alpha: inv * 0.45);
        canvas.drawCircle(center, r, _fxStroke);
        continue;
      }

      // Launch Shockwave styled according to equipped CosmicCustomization!
      switch (style) {
        case CustomizationStyle.classic:
          _fxStroke.strokeWidth = 2.4 * inv + 0.5;
          _fxStroke.color = primary.withValues(alpha: inv * 0.75);
          canvas.drawCircle(center, r, _fxStroke);
          _fxStroke.strokeWidth = 1.2 * inv;
          _fxStroke.color = Colors.white.withValues(alpha: inv * 0.55);
          canvas.drawCircle(center, r * 0.62, _fxStroke);
          break;

        case CustomizationStyle.sparkle:
          // Starburst wave + 8 crystal rays
          _fxStroke.strokeWidth = 2.2 * inv;
          _fxStroke.color = primary.withValues(alpha: inv * 0.8);
          canvas.drawCircle(center, r, _fxStroke);
          _fxStroke.strokeWidth = 1.5 * inv;
          _fxStroke.color = secondary.withValues(alpha: inv * 0.75);
          for (int k = 0; k < 8; k++) {
            final a = k * (pi / 4.0) + t * 0.5;
            final r1 = r * 0.45;
            final r2 = r * 1.12;
            canvas.drawLine(
              Offset(center.dx + cos(a) * r1, center.dy + sin(a) * r1),
              Offset(center.dx + cos(a) * r2, center.dy + sin(a) * r2),
              _fxStroke,
            );
          }
          break;

        case CustomizationStyle.dualIon:
          // Twin concentric sonic boom rings
          _fxStroke.strokeWidth = 2.6 * inv;
          _fxStroke.color = primary.withValues(alpha: inv * 0.85);
          canvas.drawCircle(center, r, _fxStroke);
          _fxStroke.strokeWidth = 2.0 * inv;
          _fxStroke.color = secondary.withValues(alpha: inv * 0.75);
          canvas.drawCircle(center, r * 0.74, _fxStroke);
          break;

        case CustomizationStyle.cyberGlitch:
          // Octagonal cyber-grid pulse wave
          _fxPath.reset();
          for (int k = 0; k < 8; k++) {
            final a = k * (pi / 4.0) + pi / 8.0;
            final px = center.dx + cos(a) * r;
            final py = center.dy + sin(a) * r;
            if (k == 0) {
              _fxPath.moveTo(px, py);
            } else {
              _fxPath.lineTo(px, py);
            }
          }
          _fxPath.close();
          _fxStroke.strokeWidth = 2.4 * inv;
          _fxStroke.color = primary.withValues(alpha: inv * 0.85);
          canvas.drawPath(_fxPath, _fxStroke);

          // Digital pixel fragments
          _fxFill.color = secondary.withValues(alpha: inv * 0.8);
          for (int k = 0; k < 4; k++) {
            final a = k * (pi / 2.0) + 0.4;
            final fx = center.dx + cos(a) * (r * 0.82);
            final fy = center.dy + sin(a) * (r * 0.82);
            canvas.drawRect(Rect.fromCenter(center: Offset(fx, fy), width: 4.0 * inv, height: 4.0 * inv), _fxFill);
          }
          break;
      }
    }
  }

  // ─── Satellite Thruster Exhaust Ribbon (4 Cosmic Trail Styles) ─────────────
  void _drawTrail(Canvas canvas, PlayerDot player) {
    final trail = player.trail;
    final count = trail.length;
    if (count < 2) return;

    final worldStyle = _styleFor(equippedPlanet);
    final customStyle = equippedCustomization.style;
    final primaryColor = colorBlindMode
        ? const Color(0xFFFFD600)
        : (customStyle == CustomizationStyle.classic
            ? _playerColor
            : equippedCustomization.primaryColor);
    final secondaryColor = colorBlindMode
        ? const Color(0xFF00E5FF)
        : equippedCustomization.secondaryColor;

    // 1. Base smooth glowing ribbon path
    _trailPath.reset();
    _trailPath.moveTo(trail[0].x, trail[0].y);
    for (int i = 1; i < count; i++) {
      _trailPath.lineTo(trail[i].x, trail[i].y);
    }

    _trailGlowPaint.strokeWidth = customStyle == CustomizationStyle.dualIon ? 9.0 : 7.0;
    _trailGlowPaint.color = customStyle == CustomizationStyle.classic
        ? worldStyle.trailGlowColor
        : primaryColor.withValues(alpha: 0.28);
    canvas.drawPath(_trailPath, _trailGlowPaint);

    // 2. Style-specific core rendering
    switch (customStyle) {
      case CustomizationStyle.classic:
        final colors = _getTrailColors(primaryColor);
        for (int i = 0; i < count - 1; i++) {
          final pt1 = trail[i];
          final pt2 = trail[i + 1];
          final progress = i / count;
          final width = (1.0 - progress) * 3.5 + 1.2;

          _trailCorePaint.strokeWidth = width;
          _trailCorePaint.color = colors[i % colors.length];
          canvas.drawLine(Offset(pt1.x, pt1.y), Offset(pt2.x, pt2.y), _trailCorePaint);
        }
        break;

      case CustomizationStyle.sparkle:
        final colors = _getTrailColors(primaryColor);
        for (int i = 0; i < count - 1; i++) {
          final pt1 = trail[i];
          final pt2 = trail[i + 1];
          final progress = i / count;
          final inv = 1.0 - progress;
          _trailCorePaint.strokeWidth = inv * 3.0 + 1.0;
          _trailCorePaint.color = colors[i % colors.length];
          canvas.drawLine(Offset(pt1.x, pt1.y), Offset(pt2.x, pt2.y), _trailCorePaint);

          // Shimmering 4-pointed star crystals along the wake
          if (i.isEven && i < count - 2) {
            final starSize = (4.2 * inv).clamp(1.2, 4.2);
            _fxStroke.strokeWidth = 1.1;
            _fxStroke.color = (i % 4 == 0 ? Colors.white : secondaryColor).withValues(alpha: inv * 0.9);
            canvas.drawLine(
              Offset(pt1.x - starSize, pt1.y),
              Offset(pt1.x + starSize, pt1.y),
              _fxStroke,
            );
            canvas.drawLine(
              Offset(pt1.x, pt1.y - starSize),
              Offset(pt1.x, pt1.y + starSize),
              _fxStroke,
            );
          }
        }
        break;

      case CustomizationStyle.dualIon:
        // Twin parallel high-velocity racing beams
        for (int i = 0; i < count - 1; i++) {
          final pt1 = trail[i];
          final pt2 = trail[i + 1];
          final dx = pt2.x - pt1.x;
          final dy = pt2.y - pt1.y;
          final len = sqrt(dx * dx + dy * dy);
          final inv = (1.0 - i / count).clamp(0.0, 1.0);
          final sep = 3.2 * inv + 0.8;
          double nx = 0.0;
          double ny = 0.0;
          if (len > 0.001) {
            nx = -dy / len * sep;
            ny = dx / len * sep;
          }

          _trailCorePaint.strokeWidth = inv * 2.2 + 0.8;
          _trailCorePaint.color = primaryColor.withValues(alpha: inv * 0.95);
          canvas.drawLine(
            Offset(pt1.x + nx, pt1.y + ny),
            Offset(pt2.x + nx, pt2.y + ny),
            _trailCorePaint,
          );
          _trailCorePaint.color = secondaryColor.withValues(alpha: inv * 0.95);
          canvas.drawLine(
            Offset(pt1.x - nx, pt1.y - ny),
            Offset(pt2.x - nx, pt2.y - ny),
            _trailCorePaint,
          );
        }
        break;

      case CustomizationStyle.cyberGlitch:
        // Digital neon data blocks & segmented cyber trail
        for (int i = 0; i < count - 1; i++) {
          final pt1 = trail[i];
          final inv = (1.0 - i / count).clamp(0.0, 1.0);
          final jitter = (i % 3 == 0) ? 2.2 : ((i % 3 == 1) ? -2.2 : 0.0);
          final boxSize = (4.8 * inv + 1.4);
          _fxFill.color = (i.isEven ? primaryColor : secondaryColor).withValues(alpha: inv * 0.9);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(pt1.x + jitter, pt1.y - jitter),
              width: boxSize,
              height: boxSize,
            ),
            _fxFill,
          );
        }
        break;
    }
  }

  // ─── Companion Satellite Probe Vessel (12 Unique Vessel Models) ───────────
  void _drawPlayer(Canvas canvas, PlayerDot player) {
    final pos = Offset(player.x, player.y);

    // Compute heading direction
    double heading = 0.0;
    if (player.isOrbiting &&
        engine.currentPlanetIndex >= 0 &&
        engine.currentPlanetIndex < engine.planets.length) {
      final planet = engine.planets[engine.currentPlanetIndex];
      heading = player.angle + (planet.rotationSpeed >= 0 ? pi / 2 : -pi / 2);
    } else {
      heading = atan2(player.vy, player.vx);
    }

    // 1. Outer halo glow matching companion color (Single-pass GPU Radial Shader)
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(15.0);
    canvas.drawCircle(
      Offset.zero,
      1.0,
      colorBlindMode ? _cbPlayerHaloPaint : _styleFor(equippedPlanet).playerHaloPaint,
    );
    canvas.restore();

    if (colorBlindMode) {
      // High-contrast accessibility indicator: distinct sharp amber ring around vessel
      canvas.drawCircle(pos, 15.0, _cbPlayerRingPaint);
    }

    // Active Overdrive Surge golden aura
    if (engine.overdriveCharges > 0) {
      _fxStroke.strokeWidth = 1.8;
      _fxStroke.color = const Color(0xFFFBBF24).withValues(alpha: 0.85);
      canvas.drawCircle(pos, 14.0, _fxStroke);
    }

    // Active Chrono Warp temporal ring
    if (engine.chronoWarpRemaining > 0) {
      _fxStroke.strokeWidth = 1.4;
      _fxStroke.color = const Color(0xFF38BDF8).withValues(alpha: 0.75);
      canvas.drawCircle(pos, 16.5, _fxStroke);
    }

    // Active Aegis Shield forcefield around player
    if (engine.hasAegisShield) {
      _fxFill.color = const Color(0xFF34D399).withValues(alpha: 0.18);
      canvas.drawCircle(pos, 12.5, _fxFill);
      _fxStroke.strokeWidth = 1.8;
      _fxStroke.color = const Color(0xFF34D399).withValues(alpha: 0.92);
      canvas.drawCircle(pos, 12.5, _fxStroke);
    }

    // 2. High-tech Satellite Probe Geometry rotated to heading
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);

    drawCompanionVessel(canvas, equippedPlanet);

    canvas.restore();
  }

  /// Renders a unique bespoke spaceship / moon companion for each of the 12 fleet worlds.
  static void drawCompanionVessel(
    Canvas canvas,
    FleetPlanet world,
  ) {

    switch (world.id) {
      case 'terra':
        // ── Luna (Natural Moon) ──
        _vesselFill.color = const Color(0xFFE2E8F0);
        canvas.drawCircle(Offset.zero, 5.2, _vesselFill);
        _vesselFill.color = const Color(0xFF94A3B8);
        canvas.drawCircle(const Offset(-1.6, -1.4), 1.1, _vesselFill);
        canvas.drawCircle(const Offset(1.8, 0.8), 1.5, _vesselFill);
        canvas.drawCircle(const Offset(-0.4, 2.2), 0.9, _vesselFill);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = Colors.white;
        canvas.drawArc(
          _terraArcRect,
          -2.4,
          2.0,
          false,
          _vesselStroke,
        );
        break;

      case 'ember':
        // ── Scout-7 (Reconnaissance Probe) ──
        _vesselFill.color = const Color(0xFF38BDF8);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 0.8;
        _vesselStroke.color = Colors.white;
        canvas.drawRect(const Rect.fromLTWH(-1.5, -9.0, 3.0, 5.0), _vesselFill);
        canvas.drawRect(const Rect.fromLTWH(-1.5, -9.0, 3.0, 5.0), _vesselStroke);
        canvas.drawRect(const Rect.fromLTWH(-1.5, 4.0, 3.0, 5.0), _vesselFill);
        canvas.drawRect(const Rect.fromLTWH(-1.5, 4.0, 3.0, 5.0), _vesselStroke);

        _vesselPath.reset();
        _vesselPath.moveTo(6.0, 0);
        _vesselPath.lineTo(0, -3.2);
        _vesselPath.lineTo(-5.0, 0);
        _vesselPath.lineTo(0, 3.2);
        _vesselPath.close();

        _vesselFill.color = const Color(0xFF0F172A);
        canvas.drawPath(_vesselPath, _vesselFill);
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = Colors.white;
        canvas.drawPath(_vesselPath, _vesselStroke);

        _vesselStroke.color = const Color(0xFF8CEFFF);
        _vesselStroke.strokeWidth = 1.2;
        canvas.drawLine(const Offset(6.0, 0), const Offset(9.0, 0), _vesselStroke);

        _vesselFill.color = Colors.white;
        canvas.drawCircle(const Offset(9.0, 0), 1.2, _vesselFill);
        canvas.drawCircle(Offset.zero, 2.2, _vesselFill);
        break;

      case 'aether':
        // ── Ion Harvester (Mining Vessel) ──
        _vesselFill.color = const Color(0xFF1E293B);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 0.9;
        _vesselStroke.color = const Color(0xFFC084FC);
        canvas.drawRRect(_aetherWingTopRRect, _vesselFill);
        canvas.drawRRect(_aetherWingTopRRect, _vesselStroke);
        canvas.drawRRect(_aetherWingBotRRect, _vesselFill);
        canvas.drawRRect(_aetherWingBotRRect, _vesselStroke);

        _vesselFill.color = const Color(0xFF0F172A);
        canvas.drawRRect(_aetherBodyRRect, _vesselFill);

        _vesselStroke.color = const Color(0xFFC084FC);
        _vesselStroke.strokeWidth = 1.2;
        canvas.drawLine(const Offset(4.0, -2.5), const Offset(7.5, -2.5), _vesselStroke);
        canvas.drawLine(const Offset(4.0, 2.5), const Offset(7.5, 2.5), _vesselStroke);

        _vesselFill.color = const Color(0xFF8CEFFF);
        canvas.drawCircle(Offset.zero, 2.5, _vesselFill);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(Offset.zero, 1.2, _vesselFill);
        break;

      case 'chronos':
        // ── Vanguard-I (Temporal Observatory) ──
        _vesselPath.reset();
        _vesselPath.moveTo(7.5, 0);
        _vesselPath.lineTo(-4.5, -4.5);
        _vesselPath.lineTo(-2.0, 0);
        _vesselPath.lineTo(-4.5, 4.5);
        _vesselPath.close();

        _vesselFill.color = const Color(0xFF0C4A6E);
        canvas.drawPath(_vesselPath, _vesselFill);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = const Color(0xFF38BDF8);
        canvas.drawPath(_vesselPath, _vesselStroke);

        _vesselStroke.color = const Color(0xFFBAE6FD);
        canvas.drawCircle(const Offset(-1.0, 0), 5.5, _vesselStroke);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(const Offset(-1.0, 0), 2.2, _vesselFill);
        break;

      case 'nova':
        // ── Solaris (Coronal Skimmer) ──
        _vesselPath.reset();
        _vesselPath.moveTo(-1.0, -2.0);
        _vesselPath.lineTo(-4.5, -7.5);
        _vesselPath.lineTo(-3.0, -2.0);
        _vesselPath.moveTo(-1.0, 2.0);
        _vesselPath.lineTo(-4.5, 7.5);
        _vesselPath.lineTo(-3.0, 2.0);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.5;
        _vesselStroke.color = const Color(0xFFFEF08A);
        canvas.drawPath(_vesselPath, _vesselStroke);

        _vesselPath2.reset();
        _vesselPath2.moveTo(8.5, 0);
        _vesselPath2.lineTo(-5.5, -2.0);
        _vesselPath2.lineTo(-4.0, 0);
        _vesselPath2.lineTo(-5.5, 2.0);
        _vesselPath2.close();

        _vesselFill.color = const Color(0xFF451A03);
        canvas.drawPath(_vesselPath2, _vesselFill);
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = const Color(0xFFFBBF24);
        canvas.drawPath(_vesselPath2, _vesselStroke);

        _vesselFill.color = const Color(0xFFFEF08A);
        canvas.drawCircle(Offset.zero, 2.2, _vesselFill);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(Offset.zero, 1.0, _vesselFill);
        break;

      case 'titan':
        // ── Hyperion (Methane Drifter) ──
        _vesselPath.reset();
        _vesselPath.moveTo(7.0, 0);
        _vesselPath.lineTo(-4.5, -8.0);
        _vesselPath.lineTo(-2.0, -2.5);
        _vesselPath.lineTo(-2.0, 2.5);
        _vesselPath.lineTo(-4.5, 8.0);
        _vesselPath.close();

        _vesselFill.color = const Color(0xFF042F2E);
        canvas.drawPath(_vesselPath, _vesselFill);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = const Color(0xFF2DD4BF);
        canvas.drawPath(_vesselPath, _vesselStroke);

        _vesselFill.color = const Color(0xFF99F6E4);
        canvas.drawOval(_titanOvalRect, _vesselFill);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(const Offset(1.0, 0), 1.2, _vesselFill);
        break;

      case 'gliese':
        // ── Deep Probe (Oceanic Surveyor) ──
        _vesselFill.color = const Color(0xFF1E3A8A);
        canvas.drawCircle(Offset.zero, 4.5, _vesselFill);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = const Color(0xFF60A5FA);
        canvas.drawCircle(Offset.zero, 4.5, _vesselStroke);

        _vesselStroke.color = const Color(0xFF93C5FD);
        _vesselStroke.strokeWidth = 1.5;
        canvas.drawLine(const Offset(-2.0, -4.5), const Offset(-4.5, -7.0), _vesselStroke);
        canvas.drawLine(const Offset(-2.0, 4.5), const Offset(-4.5, 7.0), _vesselStroke);

        _vesselFill.color = const Color(0xFF93C5FD);
        canvas.drawCircle(const Offset(3.5, 0), 2.0, _vesselFill);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(const Offset(3.5, 0), 1.0, _vesselFill);
        break;

      case 'nebula9':
        // ── Void Ray (Matter Harvester) ──
        _vesselPath.reset();
        _vesselPath.moveTo(8.5, 0);
        _vesselPath.lineTo(0, -1.8);
        _vesselPath.lineTo(-4.5, 0);
        _vesselPath.lineTo(0, 1.8);
        _vesselPath.close();

        _vesselFill.color = const Color(0xFF701A75);
        canvas.drawPath(_vesselPath, _vesselFill);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = const Color(0xFFF472B6);
        canvas.drawPath(_vesselPath, _vesselStroke);

        _vesselPath2.reset();
        _vesselPath2.moveTo(5.5, -6.0);
        _vesselPath2.lineTo(1.0, -3.5);
        _vesselPath2.lineTo(-3.5, -5.5);
        _vesselPath2.moveTo(5.5, 6.0);
        _vesselPath2.lineTo(1.0, 3.5);
        _vesselPath2.lineTo(-3.5, 5.5);
        _vesselStroke.color = const Color(0xFFFBCFE8);
        _vesselStroke.strokeWidth = 1.3;
        canvas.drawPath(_vesselPath2, _vesselStroke);

        _vesselFill.color = const Color(0xFFF472B6);
        canvas.drawCircle(Offset.zero, 2.2, _vesselFill);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(Offset.zero, 1.0, _vesselFill);
        break;

      case 'solaris':
        // ── Helios (Fusion Collector) ──
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.6;
        _vesselStroke.color = const Color(0xFFFB923C);
        canvas.drawCircle(Offset.zero, 5.2, _vesselStroke);

        _vesselStroke.color = Colors.white;
        _vesselStroke.strokeWidth = 0.8;
        canvas.drawLine(const Offset(-4.0, 0), const Offset(4.0, 0), _vesselStroke);
        canvas.drawLine(const Offset(0, -4.0), const Offset(0, 4.0), _vesselStroke);

        _vesselFill.color = const Color(0xFFFED7AA);
        canvas.drawCircle(Offset.zero, 2.5, _vesselFill);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(Offset.zero, 1.2, _vesselFill);
        break;

      case 'eclipse':
        // ── Umbra (Shadow Drone) ──
        _vesselPath.reset();
        _vesselPath.moveTo(7.0, 0);
        _vesselPath.lineTo(0, -4.0);
        _vesselPath.lineTo(-5.0, 0);
        _vesselPath.lineTo(0, 4.0);
        _vesselPath.close();

        _vesselFill.color = const Color(0xFF2E1065);
        canvas.drawPath(_vesselPath, _vesselFill);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.0;
        _vesselStroke.color = const Color(0xFFA78BFA);
        canvas.drawPath(_vesselPath, _vesselStroke);

        _vesselStroke.color = const Color(0xFFDDD6FE);
        canvas.drawLine(const Offset(-2.0, -2.0), const Offset(4.0, 0), _vesselStroke);
        canvas.drawLine(const Offset(-2.0, 2.0), const Offset(4.0, 0), _vesselStroke);

        _vesselFill.color = Colors.white;
        canvas.drawCircle(Offset.zero, 1.8, _vesselFill);
        break;

      case 'orion':
        // ── Rigel-X (Quantum Relay) ──
        _vesselFill.color = const Color(0xFF064E3B);
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 0.8;
        _vesselStroke.color = const Color(0xFF34D399);
        canvas.drawRRect(_orionWingTopRRect, _vesselFill);
        canvas.drawRRect(_orionWingTopRRect, _vesselStroke);
        canvas.drawRRect(_orionWingBotRRect, _vesselFill);
        canvas.drawRRect(_orionWingBotRRect, _vesselStroke);

        _vesselFill.color = const Color(0xFFA7F3D0);
        canvas.drawRect(const Rect.fromLTWH(-1.5, -3.3, 3.0, 6.6), _vesselFill);
        _vesselFill.color = Colors.white;
        canvas.drawCircle(Offset.zero, 1.8, _vesselFill);
        break;

      case 'void':
      default:
        // ── Infinity (Singularity Probe) ──
        _vesselStroke.style = PaintingStyle.stroke;
        _vesselStroke.strokeWidth = 1.4;
        _vesselStroke.color = const Color(0xFFE879F9);
        canvas.drawOval(_voidOvalRect, _vesselStroke);

        _vesselFill.color = Colors.black;
        canvas.drawCircle(Offset.zero, 2.4, _vesselFill);
        _vesselStroke.strokeWidth = 0.9;
        _vesselStroke.color = Colors.white;
        canvas.drawCircle(Offset.zero, 2.4, _vesselStroke);
        _vesselFill.color = const Color(0xFFF5D0FE);
        canvas.drawCircle(Offset.zero, 1.0, _vesselFill);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.colorBlindMode != colorBlindMode ||
        oldDelegate.graphicsQuality != graphicsQuality ||
        oldDelegate.reducedMotion != reducedMotion ||
        oldDelegate.isTurkish != isTurkish ||
        oldDelegate.equippedPlanet != equippedPlanet ||
        oldDelegate.equippedCustomization != equippedCustomization ||
        oldDelegate.planetImages != planetImages;
  }
}
