/// Main menu — Galaxy Orbit (Figma: "Main menu" frame, 390×844).
///
/// Every foreground element is positioned with the exact coordinates of the
/// Figma export inside a 390×844 design frame, which is then scaled to the
/// device with [FittedBox]. The space background is full-bleed underneath.
///
/// Layers (bottom → top):
///  1. Galaxy background image (slow Ken-Burns drift)
///  2. Twinkling star field
///  3. Readability gradient
///  4. Design frame: settings chip, Stardust wallet, title, Terra + Luna
///     orbit system, PLAY gravity-wave button, Hangar button.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/theme_constants.dart';
import '../models/fleet_planet.dart';
import '../providers/game_state_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/figma_icons.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
import 'settings_modal.dart';

/// All menu animations share one 60 s clock so every loop is seamless.
const double _kLoopSeconds = 60;

/// Terra / Luna geometry (Figma coordinates).
const Offset _kPlanetCenter = Offset(195, 434);
const double _kPlanetRadius = 123.2;
const double _kOrbitRadius = 139.65;
const double _kMoonRadius = 11.2;
const double _kMoonPeriod = 15; // seconds per orbit (4 loops / clock)

/// PLAY button geometry (Figma coordinates).
const Offset _kPlayCenter = Offset(195, 650);
const double _kPulsePeriod = 2.4; // seconds (25 loops / clock)

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _openGame() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SettingsModal(),
    );
  }

  void _openHangar() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HangarScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final equippedPlanet = context.select<GameStateProvider, FleetPlanet>(
      (g) => g.equippedPlanet,
    );
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          // 0. Solid Deep Space Base Canvas (prevents window bleed / subpixel gaps)
          const Positioned.fill(
            child: ColoredBox(color: kBackgroundColor),
          ),

          // 1. Galaxy background with a slow, seamless drift.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, child) {
                final drift = settings.reducedMotion ? 0.0 : sin(_clock.value * 2 * pi);
                return Transform.scale(
                  scale: 1.08 + 0.025 * drift,
                  alignment: const Alignment(0.6, -0.4),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/images/menu_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Twinkling stars.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _TwinklePainter(_clock)),
            ),
          ),

          // 3. Readability gradient (keeps lower UI calm).
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kBackgroundColor.withValues(alpha: 0.10),
                      Colors.transparent,
                      kBackgroundColor.withValues(alpha: 0.55),
                      kBackgroundColor.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.35, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 4. Figma design frame, scaled to fit the device.
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: kDesignWidth,
                    height: kDesignHeight,
                    child: _buildFrame(equippedPlanet, settings),
                  ),
                ),
              ),
            ),
          ),

          // 5. Top Bar: Settings (üst sol) & Stardust (üst sağ) ekran köşelerine daha yakın hizalı
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ayarlar butonu (sol üst köşe)
                    _Pressable(
                      onTap: _openSettings,
                      semanticLabel: settings.strings.settingsSemantic,
                      child: Container(
                        key: const Key('menu_settings_button'),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kChipSurface.withValues(alpha: 0.12),
                          border: Border.all(
                            color: kBorderSoft.withValues(alpha: 0.20),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: FigmaIcon.gear(size: 18),
                      ),
                    ),

                    // Stardust cüzdan hapı (sağ üst köşe)
                    Selector<GameStateProvider, int>(
                      selector: (_, g) => g.totalStarDust,
                      builder: (_, dust, _) => _WalletPill(amount: dust),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrame(FleetPlanet equippedPlanet, SettingsProvider settings) {
    return Stack(
      clipBehavior: Clip.none,
      children: [

        // ── Title: GALAXY ───────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 105,
          child: Center(
            child: Text(
              'GALAXY',
              style: GoogleFonts.inter(
                color: kTitleSoft,
                fontSize: 25,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: kAccentColor.withValues(alpha: 0.45),
                    blurRadius: 22,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Title: ORBIT (fits glyph box) ──────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 155,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 54,
              child: FittedBox(
                child: Text(
                  'ORBIT',
                  style: GoogleFonts.orbitron(
                    color: kTextColor,
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: kAccentColor.withValues(alpha: 0.40),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Tagline ────────────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 222,
          child: Center(
            child: Text(
              settings.strings.menuTagline,
              style: GoogleFonts.inter(
                color: kTextMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.4,
              ),
            ),
          ),
        ),

        // ── Equipped planet (center 195,434  r 123.2) ──────────────────────────
        Positioned(
          left: _kPlanetCenter.dx - _kPlanetRadius,
          top: _kPlanetCenter.dy - _kPlanetRadius,
          width: _kPlanetRadius * 2,
          height: _kPlanetRadius * 2,
          child: _MenuPlanet(planet: equippedPlanet),
        ),

        // ── Orbit ring + companion (animated) ─────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _OrbitSystemPainter(_clock, planet: equippedPlanet),
            ),
          ),
        ),

        // ── Planet caption ─────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 550,
          child: Center(
            child: Text(
              '${equippedPlanet.name.toUpperCase()}  •  ${equippedPlanet.companionName.toUpperCase()} ${settings.strings.companion}',
              style: GoogleFonts.inter(
                color: kTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),

        // ── PLAY gravity-wave button (center 195,640) ──────────────────────
        Positioned(
          left: _kPlayCenter.dx - 70,
          top: 640 - 70,
          width: 140,
          height: 140,
          child: _PlayButton(clock: _clock, onTap: _openGame, label: settings.strings.play),
        ),

        // ── Continue line (mesafe / seviye) ────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 728,
          child: Center(
            child: Selector<GameStateProvider, int>(
              selector: (_, g) => g.bestDistance,
              builder: (_, best, _) => Text(
                best > 0
                    ? settings.strings.journeyContinue(best)
                    : settings.strings.journeyBegin,
                style: GoogleFonts.inter(
                  color: kTextMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),

        // ── Hangar / Celestial Market (kenarlara daha yakın, orantılı x30 w330 y768) ───
        Positioned(
          left: 30,
          top: 768,
          width: 330,
          height: 48,
          child: _Pressable(
            onTap: _openHangar,
            semanticLabel: settings.strings.hangarTitle,
            child: Container(
              key: const Key('menu_hangar_button'),
              decoration: BoxDecoration(
                color: kSurfaceColor.withValues(alpha: 0.63),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderSoft.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  FigmaIcon.orbit(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      settings.strings.hangarTitle,
                      style: GoogleFonts.inter(
                        color: kTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  FigmaIcon.chevron(),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Widgets
// ═════════════════════════════════════════════════════════════════════════════

/// Scales its child down slightly while pressed (micro-interaction).
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  final int amount;
  const _WalletPill({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('menu_wallet_pill'),
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: kPillSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: kBorderSoft.withValues(alpha: 0.20),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FigmaIcon.stardust(),
          const SizedBox(width: 8),
          Text(
            formatThousands(amount),
            style: GoogleFonts.inter(
              color: kTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats 1240 → "1,240".
String formatThousands(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Equipped celestial body: textured sphere with atmosphere glow and day/night shading.
class _MenuPlanet extends StatelessWidget {
  final FleetPlanet planet;
  const _MenuPlanet({required this.planet});

  /// The source image has the sphere spanning ~888 of its 1024 px.
  static const double _textureScale = 1024 / 888;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: planet.glowColor.withValues(alpha: 0.38),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: _textureScale,
              child: Image.asset(
                planet.assetPath,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
            // Terminator shadow: lit from upper-left.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.45, -0.5),
                  radius: 1.25,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Thin atmospheric rim.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: planet.primaryColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PLAY button: filled core, glowing ring, static halo and an expanding
/// "gravity wave" pulse.
class _PlayButton extends StatelessWidget {
  final Animation<double> clock;
  final VoidCallback onTap;
  final String label;

  const _PlayButton({required this.clock, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: CustomPaint(
        key: const Key('menu_play_button'),
        painter: _PlayRingsPainter(clock),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              color: kTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Painters
// ═════════════════════════════════════════════════════════════════════════════

class _PlayRingsPainter extends CustomPainter {
  final Animation<double> clock;
  _PlayRingsPainter(this.clock) : super(repaint: clock);

  final Paint _corePaint = Paint();
  final Paint _wavePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _staticHaloPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = kAccentColor.withValues(alpha: 0.21);
  final Paint _ringGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = kAccentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = clock.value * _kLoopSeconds;
    final p = (t % _kPulsePeriod) / _kPulsePeriod; // 0 → 1
    final breath = 0.5 + 0.5 * sin(p * 2 * pi);

    // Inner core (r 40, #8CEFFF @ 8%).
    _corePaint.color = kAccentColor.withValues(alpha: 0.082);
    canvas.drawCircle(c, 40, _corePaint);

    // Expanding gravity wave.
    _wavePaint.color = kAccentColor.withValues(alpha: 0.35 * (1 - p));
    canvas.drawCircle(
      c,
      48.5 + 21 * Curves.easeOut.transform(p),
      _wavePaint,
    );

    // Static outer halo (r 57.5 @ 21%).
    canvas.drawCircle(c, 57.5, _staticHaloPaint);

    // Main ring glow (Figma drop-shadow blur 11) — breathes with the pulse.
    _ringGlowPaint.color = kAccentColor.withValues(alpha: 0.30 + 0.30 * breath);
    canvas.drawCircle(c, 48.5, _ringGlowPaint);

    // Main ring (r 48.5).
    canvas.drawCircle(c, 48.5, _ringPaint);
  }

  @override
  bool shouldRepaint(covariant _PlayRingsPainter old) => false;
}

/// Orbit ring around equipped planet + companion gliding along it with a comet tail.
class _OrbitSystemPainter extends CustomPainter {
  final Animation<double> clock;
  final FleetPlanet planet;

  _OrbitSystemPainter(this.clock, {required this.planet})
      : super(repaint: clock);

  /// Figma places companion at (309.8, 364) → starting angle on the ring.
  static final double _startAngle = atan2(364 - 434.0, 309.8 - 195.0);
  static const double _tailSweep = 0.95; // radians

  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7;
  final Paint _nebulaGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 9
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
  final Paint _tailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final Paint _dotPaint = Paint();
  final Paint _moonGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
  final Paint _moonPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _kLoopSeconds;
    // Counter-clockwise on screen (angle decreases).
    final angle = _startAngle - 2 * pi * (t / _kMoonPeriod);
    final ringRect =
        Rect.fromCircle(center: _kPlanetCenter, radius: _kOrbitRadius);

    // Orbit ring (#8CEFFF @ 38%, 0.7 px).
    _ringPaint.color = planet.primaryColor.withValues(alpha: 0.38);
    canvas.drawCircle(_kPlanetCenter, _kOrbitRadius, _ringPaint);

    // Nebula glow under the tail.
    _nebulaGlowPaint.color = planet.glowColor.withValues(alpha: 0.18);
    canvas.drawArc(
      ringRect,
      angle,
      _tailSweep,
      false,
      _nebulaGlowPaint,
    );

    // Dynamic tail fading away from companion.
    _tailPaint.shader = SweepGradient(
      startAngle: 0,
      endAngle: _tailSweep,
      colors: [
        planet.primaryColor.withValues(alpha: 0.9),
        planet.primaryColor.withValues(alpha: 0.0),
      ],
      transform: GradientRotation(angle),
    ).createShader(ringRect);

    canvas.drawArc(
      ringRect,
      angle,
      _tailSweep,
      false,
      _tailPaint,
    );

    // Dotted dust trail beyond the tail.
    for (int i = 0; i < 5; i++) {
      final a = angle + _tailSweep + 0.08 + i * 0.07;
      _dotPaint.color = planet.primaryColor.withValues(alpha: 0.6 - i * 0.12);
      canvas.drawCircle(
        _kPlanetCenter + Offset(cos(a), sin(a)) * _kOrbitRadius,
        1,
        _dotPaint,
      );
    }

    // Companion sphere.
    final moon = _kPlanetCenter + Offset(cos(angle), sin(angle)) * _kOrbitRadius;
    _moonGlowPaint.color = planet.companionColor.withValues(alpha: 0.35);
    canvas.drawCircle(
      moon,
      _kMoonRadius + 4,
      _moonGlowPaint,
    );
    final moonRect = Rect.fromCircle(center: moon, radius: _kMoonRadius);
    _moonPaint.shader = RadialGradient(
      center: const Alignment(-0.4, -0.45),
      radius: 1.1,
      colors: [planet.companionColor, planet.glowColor],
    ).createShader(moonRect);
    canvas.drawCircle(
      moon,
      _kMoonRadius,
      _moonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitSystemPainter old) =>
      old.planet != planet;
}

class _Star {
  final double x, y, radius, phase;
  final int cycles; // whole cycles per 60 s loop → seamless
  const _Star(this.x, this.y, this.radius, this.phase, this.cycles);
}

class _TwinklePainter extends CustomPainter {
  final Animation<double> clock;
  _TwinklePainter(this.clock) : super(repaint: clock);

  final Paint _paint = Paint();

  static final List<_Star> _stars = List.generate(70, (i) {
    final r = Random(1000 + i);
    return _Star(
      r.nextDouble(),
      r.nextDouble(),
      0.4 + r.nextDouble() * 1.1,
      r.nextDouble() * 2 * pi,
      3 + r.nextInt(10),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final v = clock.value;
    for (final s in _stars) {
      final tw = 0.5 + 0.5 * sin(v * 2 * pi * s.cycles + s.phase);
      _paint.color = Colors.white.withValues(alpha: 0.08 + 0.55 * tw);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter old) => false;
}
