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
  double _lastNebulaWidth = 0;
  double _lastNebulaHeight = 0;

  final Paint _starPaint = Paint()..style = PaintingStyle.fill;
  final Paint _crossPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;

  final Paint _guidePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _clearedBodyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _haloGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
  final Paint _playerHaloPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
  final Paint _trailGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
  final Paint _trailCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _texPaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _outerRingPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0;
  final Paint _innerRingPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;

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
      colorBlindMode ? kPlayerColorCB : equippedPlanet.companionColor;
  Color get _planetAccentColor =>
      colorBlindMode ? kPlanetColorCB : kAccentColor;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Deep Space Background ──────────────────────────────────────────────
    canvas.drawRect(Offset.zero & size, _bgPaint);

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

  // ─── Nebula Layer (Cached Shaders) ────────────────────────────────────────
  void _drawNebula(Canvas canvas, Size size) {
    if (graphicsQuality == GraphicsQuality.low) return;

    if (_cachedNebulaShader1 == null || _lastNebulaWidth != size.width || _lastNebulaHeight != size.height) {
      _lastNebulaWidth = size.width;
      _lastNebulaHeight = size.height;

      _cachedNebulaShader1 = RadialGradient(
        colors: [
          const Color(0xFF1E1B4B).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.8, size.height * 0.25),
        radius: size.width * 0.6,
      ));

      if (graphicsQuality == GraphicsQuality.high) {
        _cachedNebulaShader2 = RadialGradient(
          colors: [
            const Color(0xFF0F2B48).withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.2, size.height * 0.75),
          radius: size.width * 0.7,
        ));
      }
    }

    _nebulaPaint1.shader = _cachedNebulaShader1;
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.25),
      size.width * 0.6,
      _nebulaPaint1,
    );

    if (graphicsQuality == GraphicsQuality.high && _cachedNebulaShader2 != null) {
      _nebulaPaint2.shader = _cachedNebulaShader2;
      canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.75),
        size.width * 0.7,
        _nebulaPaint2,
      );
    }
  }

  // ─── Parallax Stars (Static Pre-computed Array) ───────────────────────────
  void _drawParallaxStars(Canvas canvas, Size size) {
    final int starCount = switch (graphicsQuality) {
      GraphicsQuality.high => 90,
      GraphicsQuality.medium => 50,
      GraphicsQuality.low => 25,
    };

    final count = min(starCount, _staticStars.length);
    for (int i = 0; i < count; i++) {
      final s = _staticStars[i];
      final x = s.nx * size.width;
      final parallaxFactor = 0.06 + s.layer * 0.25;
      final screenY = s.worldY - engine.cameraY * parallaxFactor;

      if (screenY > -15 && screenY < size.height + 15) {
        final twinkle = reducedMotion
            ? 0.85
            : 0.75 + 0.25 * sin(engine.totalElapsed * s.twinkleSpeed + i);
        final alpha = ((0.2 + s.layer * 0.7) * twinkle).clamp(0.0, 1.0);
        _starPaint.color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, screenY), s.radius, _starPaint);

        if (s.layer > 0.85 && s.radius > 1.6) {
          _crossPaint.color = Colors.white.withValues(alpha: alpha * 0.35);
          canvas.drawLine(
            Offset(x - 3, screenY),
            Offset(x + 3, screenY),
            _crossPaint,
          );
          canvas.drawLine(
            Offset(x, screenY - 3),
            Offset(x, screenY + 3),
            _crossPaint,
          );
        }
      }
    }
  }

  // ─── Tangent Aim Guidance ─────────────────────────────────────────────────
  void _drawAimGuidance(Canvas canvas) {
    if (!engine.player.isOrbiting) return;
    if (engine.currentPlanetIndex >= engine.planets.length) return;

    final currentPlanet = engine.planets[engine.currentPlanetIndex];
    final player = engine.player;

    // Calculate tangent launch vector
    final sign = currentPlanet.rotationSpeed >= 0 ? 1.0 : -1.0;
    final dirX = -sin(player.angle) * sign;
    final dirY = cos(player.angle) * sign;

    _guidePaint.color = _playerColor.withValues(alpha: 0.2);

    final start = Offset(player.x, player.y);
    for (int d = 12; d < 80; d += 14) {
      final p1 = start + Offset(dirX * d, dirY * d);
      final p2 = start + Offset(dirX * (d + 6), dirY * (d + 6));
      canvas.drawLine(p1, p2, _guidePaint);
    }
  }

  // ─── Draw Celestial Body ──────────────────────────────────────────────────
  void _drawPlanet(Canvas canvas, Planet planet, int index) {
    final center = Offset(planet.x, planet.y);
    final coreRadius = planet.radius * 0.52;
    final isCurrent = index == engine.currentPlanetIndex;
    final isCleared = planet.cleared && !isCurrent;

    final world = planet.fleetPlanet;

    // ── Cleared State: Subdued Silhouette ──
    if (isCleared) {
      _clearedOrbitPaint.color = _planetAccentColor.withValues(alpha: 0.12);
      canvas.drawCircle(center, planet.radius, _clearedOrbitPaint);

      _clearedBodyPaint.color = world.primaryColor.withValues(alpha: 0.16);
      canvas.drawCircle(center, coreRadius, _clearedBodyPaint);
      return;
    }

    // ── Gravitational Orbit Ring ──
    _orbitPaint.color = isCurrent
        ? world.primaryColor.withValues(alpha: 0.58)
        : _planetAccentColor.withValues(alpha: 0.32);
    canvas.drawCircle(center, planet.radius, _orbitPaint);

    // ── Atmospheric Outer Halo Glow ──
    _haloGlowPaint.color = world.glowColor.withValues(alpha: 0.36);
    canvas.drawCircle(center, coreRadius + 6.0, _haloGlowPaint);

    // ── Planetary Rings for Ringed Worlds (e.g. Chronos, Zenith, Aether, Eclipse) ──
    final isRinged = world.id == 'chronos' || world.id == 'aether' || world.id == 'eclipse' || world.id == 'void';
    if (isRinged) {
      _drawPlanetaryRings(canvas, center, coreRadius, world.primaryColor, behind: true);
    }

    // ── 3D Spherical Core (Image Texture or Procedural) ──
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      Rect.fromCircle(center: center, radius: coreRadius),
      Radius.circular(coreRadius),
    ));

    final imgKey = _getImageKeyForWorld(world);
    final texImage = planetImages?[imgKey];

    if (texImage != null) {
      final src = Rect.fromLTWH(0, 0, texImage.width.toDouble(), texImage.height.toDouble());
      final dst = Rect.fromCircle(center: center, radius: coreRadius);
      _texPaint.colorFilter = (world.id != 'terra' && world.id != 'ember' && world.id != 'aether')
          ? ColorFilter.mode(world.primaryColor.withValues(alpha: 0.4), BlendMode.color)
          : null;
      canvas.drawImageRect(
        texImage,
        src,
        dst,
        _texPaint,
      );
    } else {
      _drawProceduralSurface(canvas, center, coreRadius, world);
    }

    // ── 3D Day/Night Specular & Terminator Shading ──
    _draw3DSphericalShading(canvas, center, coreRadius);

    canvas.restore();

    // ── Foreground Portion of Planetary Rings ──
    if (isRinged) {
      _drawPlanetaryRings(canvas, center, coreRadius, world.primaryColor, behind: false);
    }

    // ── Atmospheric Sunlit Rim Light Arc ──
    _rimPaint.color = world.glowColor.withValues(alpha: 0.75);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: coreRadius - 0.5),
      -2.4,
      2.0,
      false,
      _rimPaint,
    );
  }

  // ─── Planetary Rings ──────────────────────────────────────────────────────
  void _drawPlanetaryRings(
    Canvas canvas,
    Offset center,
    double coreRadius,
    Color ringColor, {
    required bool behind,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35); // tilt angle

    // Clip to only draw behind or in front of the sphere
    if (behind) {
      canvas.clipRect(Rect.fromLTRB(-coreRadius * 2, -coreRadius * 2, coreRadius * 2, 0));
    } else {
      canvas.clipRect(Rect.fromLTRB(-coreRadius * 2, 0, coreRadius * 2, coreRadius * 2));
    }

    _outerRingPaint.color = ringColor.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: coreRadius * 2.8, height: coreRadius * 0.75),
      _outerRingPaint,
    );

    _innerRingPaint.color = ringColor.withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: coreRadius * 2.3, height: coreRadius * 0.6),
      _innerRingPaint,
    );

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
    canvas.drawCircle(center, radius, Paint()..color = world.primaryColor);

    if (world.category.toLowerCase().contains('desert') || world.id == 'ember') {
      final craterShadow = Paint()..color = const Color(0xFF450A0A).withValues(alpha: 0.65);
      final craterRim = Paint()
        ..color = world.glowColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

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
        canvas.drawCircle(pos, r, craterShadow);
        canvas.drawArc(
          Rect.fromCircle(center: pos, radius: r),
          -2.6,
          1.8,
          false,
          craterRim,
        );
      }
    } else if (world.category.toLowerCase().contains('gas') || world.id == 'aether' || world.id == 'eclipse') {
      final bandColors = [
        world.glowColor.withValues(alpha: 0.6),
        world.primaryColor.withValues(alpha: 0.5),
        Colors.white.withValues(alpha: 0.35),
      ];
      for (int b = -2; b <= 2; b++) {
        final bandPaint = Paint()
          ..color = bandColors[(b.abs()) % bandColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.22;
        canvas.drawArc(
          Rect.fromCircle(center: center + Offset(0, b * radius * 0.26), radius: radius * 1.05),
          -0.4,
          3.9,
          false,
          bandPaint,
        );
      }
    } else if (world.category.toLowerCase().contains('cryo') || world.id == 'titan') {
      final icePaint = Paint()
        ..color = world.glowColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final p = Path()
        ..moveTo(center.dx - radius * 0.6, center.dy - radius * 0.4)
        ..lineTo(center.dx - radius * 0.1, center.dy)
        ..lineTo(center.dx + radius * 0.5, center.dy - radius * 0.3)
        ..moveTo(center.dx - radius * 0.1, center.dy)
        ..lineTo(center.dx + radius * 0.2, center.dy + radius * 0.5);
      canvas.drawPath(p, icePaint);
    } else if (world.category.toLowerCase().contains('plasma') || world.id == 'nova' || world.id == 'solaris') {
      final flarePaint = Paint()
        ..color = world.glowColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, radius * 0.65, flarePaint);
    } else {
      // Terrestrial or oceanic continents
      final landPaint = Paint()..color = const Color(0xFF22C55E).withValues(alpha: 0.55);
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(-radius * 0.25, -radius * 0.15),
          width: radius * 0.9,
          height: radius * 0.65,
        ),
        landPaint,
      );
      final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.38);
      canvas.drawArc(
        Rect.fromCircle(center: center + Offset(0, -radius * 0.2), radius: radius * 0.7),
        -0.8,
        2.4,
        false,
        cloudPaint..style = PaintingStyle.stroke..strokeWidth = radius * 0.2,
      );
    }
  }

  // ─── Satellite Thruster Exhaust Ribbon ─────────────────────────────────────
  void _drawTrail(Canvas canvas, PlayerDot player) {
    final trail = player.trail;
    final count = trail.length;
    if (count < 2) return;

    // 1. Single smooth glowing ribbon path (1 drawPath call instead of 20 blur calls)
    final path = Path();
    path.moveTo(trail[0].x, trail[0].y);
    for (int i = 1; i < count; i++) {
      path.lineTo(trail[i].x, trail[i].y);
    }

    _trailGlowPaint.strokeWidth = 6.0;
    _trailGlowPaint.color = equippedPlanet.glowColor.withValues(alpha: 0.35);
    canvas.drawPath(path, _trailGlowPaint);

    // 2. Core plasma line segments (fast linear alpha falloff without blur)
    for (int i = 0; i < count - 1; i++) {
      final p1 = Offset(trail[i].x, trail[i].y);
      final p2 = Offset(trail[i + 1].x, trail[i + 1].y);
      final progress = i / count;
      final alpha = ((1.0 - progress) * 0.95).clamp(0.0, 1.0);
      final width = (1.0 - progress) * 3.5 + 1.2;

      _trailCorePaint.strokeWidth = width;
      _trailCorePaint.color = Color.lerp(
        Colors.white,
        _playerColor,
        progress * 0.7,
      )!.withValues(alpha: alpha);
      canvas.drawLine(p1, p2, _trailCorePaint);
    }
  }

  // ─── Companion Satellite Probe Vessel (12 Unique Vessel Models) ───────────
  void _drawPlayer(Canvas canvas, PlayerDot player) {
    final pos = Offset(player.x, player.y);

    // Compute heading direction
    double heading = 0.0;
    if (player.isOrbiting && engine.currentPlanetIndex < engine.planets.length) {
      final planet = engine.planets[engine.currentPlanetIndex];
      heading = player.angle + (planet.rotationSpeed >= 0 ? pi / 2 : -pi / 2);
    } else {
      heading = atan2(player.vy, player.vx);
    }

    // 1. Outer halo glow matching companion color
    _playerHaloPaint.color = _playerColor.withValues(alpha: 0.45);
    canvas.drawCircle(pos, 13.0, _playerHaloPaint);

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
        // Pearly cratered lunar sphere
        canvas.drawCircle(Offset.zero, 5.2, Paint()..color = const Color(0xFFE2E8F0));
        canvas.drawCircle(const Offset(-1.6, -1.4), 1.1, Paint()..color = const Color(0xFF94A3B8));
        canvas.drawCircle(const Offset(1.8, 0.8), 1.5, Paint()..color = const Color(0xFF94A3B8));
        canvas.drawCircle(const Offset(-0.4, 2.2), 0.9, Paint()..color = const Color(0xFF94A3B8));
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: 5.2),
          -2.4,
          2.0,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Colors.white,
        );
        break;

      case 'ember':
        // ── Scout-7 (Reconnaissance Probe) ──
        // Stealth swept wings, antenna pin, diamond hull
        final wingPaint = Paint()..color = const Color(0xFF38BDF8);
        final wingBorder = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white;
        canvas.drawRect(const Rect.fromLTWH(-1.5, -9.0, 3.0, 5.0), wingPaint);
        canvas.drawRect(const Rect.fromLTWH(-1.5, -9.0, 3.0, 5.0), wingBorder);
        canvas.drawRect(const Rect.fromLTWH(-1.5, 4.0, 3.0, 5.0), wingPaint);
        canvas.drawRect(const Rect.fromLTWH(-1.5, 4.0, 3.0, 5.0), wingBorder);

        final hull = Path()
          ..moveTo(6.0, 0)
          ..lineTo(0, -3.2)
          ..lineTo(-5.0, 0)
          ..lineTo(0, 3.2)
          ..close();
        canvas.drawPath(hull, Paint()..color = const Color(0xFF0F172A));
        canvas.drawPath(hull, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.white);

        canvas.drawLine(const Offset(6.0, 0), const Offset(9.0, 0), Paint()..color = const Color(0xFF8CEFFF)..strokeWidth = 1.2);
        canvas.drawCircle(const Offset(9.0, 0), 1.2, Paint()..color = Colors.white);
        canvas.drawCircle(Offset.zero, 2.2, Paint()..color = Colors.white);
        break;

      case 'aether':
        // ── Ion Harvester (Mining Vessel) ──
        // Heavy twin side engine nacelles, extraction prongs forward
        final nacellePaint = Paint()..color = const Color(0xFF1E293B);
        final nacelleBorder = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9..color = const Color(0xFFC084FC);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -8.0, 8.0, 3.2), const Radius.circular(1.2)), nacellePaint);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -8.0, 8.0, 3.2), const Radius.circular(1.2)), nacelleBorder);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, 4.8, 8.0, 3.2), const Radius.circular(1.2)), nacellePaint);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, 4.8, 8.0, 3.2), const Radius.circular(1.2)), nacelleBorder);

        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.0, -3.5, 8.0, 7.0), const Radius.circular(1.5)), Paint()..color = const Color(0xFF0F172A));
        canvas.drawLine(const Offset(4.0, -2.5), const Offset(7.5, -2.5), Paint()..color = const Color(0xFFC084FC)..strokeWidth = 1.2);
        canvas.drawLine(const Offset(4.0, 2.5), const Offset(7.5, 2.5), Paint()..color = const Color(0xFFC084FC)..strokeWidth = 1.2);
        canvas.drawCircle(Offset.zero, 2.5, Paint()..color = const Color(0xFF8CEFFF));
        canvas.drawCircle(Offset.zero, 1.2, Paint()..color = Colors.white);
        break;

      case 'chronos':
        // ── Vanguard-I (Temporal Observatory) ──
        // Delta prism hull with rotating temporal gyro ring
        final p = Path()
          ..moveTo(7.5, 0)
          ..lineTo(-4.5, -4.5)
          ..lineTo(-2.0, 0)
          ..lineTo(-4.5, 4.5)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF0C4A6E));
        canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFF38BDF8));
        canvas.drawCircle(const Offset(-1.0, 0), 5.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFFBAE6FD));
        canvas.drawCircle(const Offset(-1.0, 0), 2.2, Paint()..color = Colors.white);
        break;

      case 'nova':
        // ── Solaris (Coronal Skimmer) ──
        // Needle heat-shield hull with twin golden radiator fins
        final fins = Path()
          ..moveTo(-1.0, -2.0)
          ..lineTo(-4.5, -7.5)
          ..lineTo(-3.0, -2.0)
          ..moveTo(-1.0, 2.0)
          ..lineTo(-4.5, 7.5)
          ..lineTo(-3.0, 2.0);
        canvas.drawPath(fins, Paint()..color = const Color(0xFFFEF08A)..style = PaintingStyle.stroke..strokeWidth = 1.5);

        final p = Path()
          ..moveTo(8.5, 0)
          ..lineTo(-5.5, -2.0)
          ..lineTo(-4.0, 0)
          ..lineTo(-5.5, 2.0)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF451A03));
        canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFFFBBF24));
        canvas.drawCircle(Offset.zero, 2.2, Paint()..color = const Color(0xFFFEF08A));
        canvas.drawCircle(Offset.zero, 1.0, Paint()..color = Colors.white);
        break;

      case 'titan':
        // ── Hyperion (Methane Drifter) ──
        // Cryo delta glider with frosted canopy
        final p = Path()
          ..moveTo(7.0, 0)
          ..lineTo(-4.5, -8.0)
          ..lineTo(-2.0, -2.5)
          ..lineTo(-2.0, 2.5)
          ..lineTo(-4.5, 8.0)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF042F2E));
        canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFF2DD4BF));
        canvas.drawOval(Rect.fromCenter(center: const Offset(1.0, 0), width: 5.0, height: 2.5), Paint()..color = const Color(0xFF99F6E4));
        canvas.drawCircle(const Offset(1.0, 0), 1.2, Paint()..color = Colors.white);
        break;

      case 'gliese':
        // ── Deep Probe (Oceanic Surveyor) ──
        // Bathysphere spherical hull with stabilizer fins and observation dome
        canvas.drawCircle(Offset.zero, 4.5, Paint()..color = const Color(0xFF1E3A8A));
        canvas.drawCircle(Offset.zero, 4.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFF60A5FA));
        canvas.drawLine(const Offset(-2.0, -4.5), const Offset(-4.5, -7.0), Paint()..color = const Color(0xFF93C5FD)..strokeWidth = 1.5);
        canvas.drawLine(const Offset(-2.0, 4.5), const Offset(-4.5, 7.0), Paint()..color = const Color(0xFF93C5FD)..strokeWidth = 1.5);
        canvas.drawCircle(const Offset(3.5, 0), 2.0, Paint()..color = const Color(0xFF93C5FD));
        canvas.drawCircle(const Offset(3.5, 0), 1.0, Paint()..color = Colors.white);
        break;

      case 'nebula9':
        // ── Void Ray (Matter Harvester) ──
        // Crystalline dark matter trident
        final p = Path()
          ..moveTo(8.5, 0)
          ..lineTo(0, -1.8)
          ..lineTo(-4.5, 0)
          ..lineTo(0, 1.8)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF701A75));
        canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFFF472B6));

        final p2 = Path()
          ..moveTo(5.5, -6.0)
          ..lineTo(1.0, -3.5)
          ..lineTo(-3.5, -5.5)
          ..moveTo(5.5, 6.0)
          ..lineTo(1.0, 3.5)
          ..lineTo(-3.5, 5.5);
        canvas.drawPath(p2, Paint()..color = const Color(0xFFFBCFE8)..style = PaintingStyle.stroke..strokeWidth = 1.3);
        canvas.drawCircle(Offset.zero, 2.2, Paint()..color = const Color(0xFFF472B6));
        canvas.drawCircle(Offset.zero, 1.0, Paint()..color = Colors.white);
        break;

      case 'solaris':
        // ── Helios (Fusion Collector) ──
        // Toroidal magnetic containment ring vessel
        canvas.drawCircle(Offset.zero, 5.2, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = const Color(0xFFFB923C));
        canvas.drawLine(const Offset(-4.0, 0), const Offset(4.0, 0), Paint()..color = Colors.white..strokeWidth = 0.8);
        canvas.drawLine(const Offset(0, -4.0), const Offset(0, 4.0), Paint()..color = Colors.white..strokeWidth = 0.8);
        canvas.drawCircle(Offset.zero, 2.5, Paint()..color = const Color(0xFFFED7AA));
        canvas.drawCircle(Offset.zero, 1.2, Paint()..color = Colors.white);
        break;

      case 'eclipse':
        // ── Umbra (Shadow Drone) ──
        // Diamond faceted stealth drone with violet conduit lines
        final p = Path()
          ..moveTo(7.0, 0)
          ..lineTo(0, -4.0)
          ..lineTo(-5.0, 0)
          ..lineTo(0, 4.0)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFF2E1065));
        canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFFA78BFA));
        canvas.drawLine(const Offset(-2.0, -2.0), const Offset(4.0, 0), Paint()..color = const Color(0xFFDDD6FE)..strokeWidth = 1.0);
        canvas.drawLine(const Offset(-2.0, 2.0), const Offset(4.0, 0), Paint()..color = const Color(0xFFDDD6FE)..strokeWidth = 1.0);
        canvas.drawCircle(Offset.zero, 1.8, Paint()..color = Colors.white);
        break;

      case 'orion':
        // ── Rigel-X (Quantum Relay) ──
        // Twin-boom catamaran vessel with quantum emitter bridge
        final boomPaint = Paint()..color = const Color(0xFF064E3B);
        final boomBorder = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = const Color(0xFF34D399);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -5.5, 9.0, 2.2), const Radius.circular(1.0)), boomPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -5.5, 9.0, 2.2), const Radius.circular(1.0)), boomBorder);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, 3.3, 9.0, 2.2), const Radius.circular(1.0)), boomPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, 3.3, 9.0, 2.2), const Radius.circular(1.0)), boomBorder);

        canvas.drawRect(const Rect.fromLTWH(-1.5, -3.3, 3.0, 6.6), Paint()..color = const Color(0xFFA7F3D0));
        canvas.drawCircle(Offset.zero, 1.8, Paint()..color = Colors.white);
        break;

      case 'void':
      default:
        // ── Infinity (Singularity Probe) ──
        // Warp ring with miniature singularity black hole core
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 11.0, height: 7.0),
          Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = const Color(0xFFE879F9),
        );
        canvas.drawCircle(Offset.zero, 2.4, Paint()..color = Colors.black);
        canvas.drawCircle(Offset.zero, 2.4, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9..color = Colors.white);
        canvas.drawCircle(Offset.zero, 1.0, Paint()..color = const Color(0xFFF5D0FE));
        break;
    }
  }

  // ─── Theme Helpers ────────────────────────────────────────────────────────
  String _getImageKeyForWorld(FleetPlanet world) {
    if (world.assetPath.contains('ember')) return 'ember';
    if (world.assetPath.contains('aether')) return 'aether';
    return 'terra';
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
