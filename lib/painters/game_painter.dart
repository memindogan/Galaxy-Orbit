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

  final Paint _vesselFill = Paint()..style = PaintingStyle.fill;
  final Paint _vesselStroke = Paint()..style = PaintingStyle.stroke;
  final Path _vesselPath = Path();
  final Path _vesselPath2 = Path();

  final Paint _procFill = Paint()..style = PaintingStyle.fill;
  final Paint _procStroke = Paint()..style = PaintingStyle.stroke;
  final Path _procPath = Path();

  GamePainter({
    required this.engine,
    required this.colorBlindMode,
    this.graphicsQuality = GraphicsQuality.high,
    this.reducedMotion = false,
    this.isTurkish = false,
    FleetPlanet? equippedPlanet,
    this.planetImages,
    super.repaint,
  })  : equippedPlanet = equippedPlanet ?? FleetCatalog.worlds.first;

  Color get _playerColor =>
      colorBlindMode ? const Color(0xFFFFD600) : equippedPlanet.companionColor;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Deep Space Background (zero Rect allocation) ───────────────────────
    canvas.drawPaint(_bgPaint);

    // ── Cosmic Nebula Glow ──────────────────────────────────────────────────
    _drawNebula(canvas, size);

    // ── Parallax Stars ──────────────────────────────────────────────────────
    _drawParallaxStars(canvas, size);

    // ── Camera Transform ────────────────────────────────────────────────────
    canvas.save();
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
    final screenTop = engine.cameraY - 180.0;
    final screenBottom = engine.cameraY + size.height + 180.0;
    for (int i = 0; i < planets.length; i++) {
      final p = planets[i];
      if (p.y + p.radius < screenTop || p.y - p.radius > screenBottom) {
        continue; // Cull off-screen planet
      }
      _drawPlanet(canvas, p, i);
    }

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

  // ─── Satellite Thruster Exhaust Ribbon ─────────────────────────────────────
  void _drawTrail(Canvas canvas, PlayerDot player) {
    final trail = player.trail;
    final count = trail.length;
    if (count < 2) return;

    final style = _styleFor(equippedPlanet);

    // 1. Single smooth glowing ribbon path (zero MaskFilter.blur FBO switches)
    _trailPath.reset();
    _trailPath.moveTo(trail[0].x, trail[0].y);
    for (int i = 1; i < count; i++) {
      _trailPath.lineTo(trail[i].x, trail[i].y);
    }

    _trailGlowPaint.strokeWidth = 7.0;
    _trailGlowPaint.color = style.trailGlowColor;
    canvas.drawPath(_trailPath, _trailGlowPaint);

    // 2. Core plasma line segments (cached gradient colors)
    final colors = _getTrailColors(_playerColor);
    for (int i = 0; i < count - 1; i++) {
      final pt1 = trail[i];
      final pt2 = trail[i + 1];
      final progress = i / count;
      final width = (1.0 - progress) * 3.5 + 1.2;

      _trailCorePaint.strokeWidth = width;
      _trailCorePaint.color = colors[i % colors.length];
      canvas.drawLine(Offset(pt1.x, pt1.y), Offset(pt2.x, pt2.y), _trailCorePaint);
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

    // 2. High-tech Satellite Probe Geometry rotated to heading
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);

    _drawCompanionVessel(canvas, equippedPlanet);

    canvas.restore();
  }

  /// Renders a unique bespoke spaceship / moon companion for each of the 12 fleet worlds.
  void _drawCompanionVessel(Canvas canvas, FleetPlanet world) {
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
        oldDelegate.planetImages != planetImages;
  }
}
