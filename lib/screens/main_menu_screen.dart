/// Main menu — Galaxy Orbit (Figma: "Main menu" frame, 390×844).
///
/// Features:
///  1. Deep space background with subtle stars and atmospheric drift
///  2. Top Bar: Frosted Settings chip (left) & Stardust Wallet pill (right)
///  3. Hero Title: "GALAXY" & glowing "ORBIT" with tagline "ONE TAP. INFINITE POSSIBILITY"
///  4. Celestial Stage:
///     - Telemetry header: "SOL SYSTEM / 03" & "● SYNCED" badge
///     - 3D rotating textured world with atmospheric rim glow
///     - Inclined neon orbit ring with revolving satellite companion
///     - Capsule caption: "• TERRA • LUNA COMPANION"
///  5. Gravity-Wave PLAY Button with concentric pulse waves and play triangle glyph
///  6. Progress summary: "Continue your journey • Best distance: Level 14"
///  7. Floating Hangar / Celestial Market glass card with spaceship icon & unlocked pill
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/theme_constants.dart';
import '../l10n/app_strings.dart';
import '../models/fleet_planet.dart';
import '../providers/game_state_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/figma_icons.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
import 'settings_modal.dart';

/// All menu animations share one 60 s clock so every loop is seamless.
const double _kLoopSeconds = 60;

/// Terra / Luna geometry (Figma coordinates).
const Offset _kPlanetCenter = Offset(195, 415);
const double _kPlanetRadius = 118.0;
const double _kOrbitRadius = 142.0;
const double _kMoonRadius = 10.5;
const double _kMoonPeriod = 15; // seconds per orbit

/// PLAY button geometry (Figma coordinates).
const Offset _kPlayCenter = Offset(195, 638);
const double _kPulsePeriod = 2.4; // seconds

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  late final AnimationController _gearController;
  late final Animation<double> _gearRotation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioService().playBGM();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _gearRotation = Tween<double>(begin: 0.0, end: pi / 3).animate(
      CurvedAnimation(parent: _gearController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (state == AppLifecycleState.paused) {
      if (_clock.isAnimating) _clock.stop();
      if (isCurrentRoute) {
        AudioService().pauseBGM();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_clock.isAnimating) _clock.repeat();
      if (isCurrentRoute) {
        AudioService().resumeBGM();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gearController.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _openGame() {
    if (context.read<SettingsProvider>().vibrationEnabled) {
      HapticService.mediumImpact();
    }
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
    _gearController.forward(from: 0.0);
    if (context.read<SettingsProvider>().vibrationEnabled) {
      HapticService.selectionClick();
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SettingsModal(),
    );
  }

  void _openHangar() {
    if (context.read<SettingsProvider>().vibrationEnabled) {
      HapticService.selectionClick();
    }
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
    final strings = context.select<SettingsProvider, AppStrings>(
      (s) => s.strings,
    );
    final reducedMotion = context.select<SettingsProvider, bool>(
      (s) => s.reducedMotion,
    );
    final unlockedCount = context.select<GameStateProvider, int>(
      (g) => g.unlockedPlanetIds.length,
    );

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          // 0. Base canvas
          const Positioned.fill(
            child: ColoredBox(color: kBackgroundColor),
          ),

          // 1. Galaxy background with a slow drift
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, child) {
                  final drift = reducedMotion ? 0.0 : sin(_clock.value * 2 * pi);
                  return Transform.scale(
                    scale: 1.08 + 0.025 * drift,
                    alignment: const Alignment(0.6, -0.4),
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/images/menu_bg.jpg',
                  fit: BoxFit.cover,
                  cacheWidth: 780,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),

          // 2. Twinkling stars
          Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(
                child: CustomPaint(painter: _TwinklePainter(_clock)),
              ),
            ),
          ),

          // 3. Readability gradient
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
                      kBackgroundColor.withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.35, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 4. Main Design Frame (390x844 responsive)
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: kDesignWidth,
                    height: kDesignHeight,
                    child: _buildFrame(equippedPlanet, strings, unlockedCount),
                  ),
                ),
              ),
            ),
          ),

          // 5. Top Bar: Settings & Stardust Wallet Pill
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Settings button
                    _Pressable(
                      onTap: _openSettings,
                      semanticLabel: strings.settingsSemantic,
                      child: Container(
                        key: const Key('menu_settings_button'),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: const Color(0xD90C1626),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 1,
                              color: Color(0x268CEFFF),
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          shadows: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _gearRotation,
                          builder: (context, child) => Transform.rotate(
                            angle: _gearRotation.value,
                            child: child,
                          ),
                          child: FigmaIcon.gear(size: 18, color: const Color(0xFFF0F7FF)),
                        ),
                      ),
                    ),

                    // Stardust Wallet Pill
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

  Widget _buildFrame(FleetPlanet equippedPlanet, AppStrings strings, int unlockedCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Title: GALAXY ───────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 98,
          child: Center(
            child: Text(
              'GALAXY',
              style: GoogleFonts.inter(
                color: kTitleSoft,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 4.0,
                shadows: [
                  Shadow(
                    color: kAccentColor.withValues(alpha: 0.45),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Title: ORBIT ───────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 142,
          child: Center(
            child: SizedBox(
              width: 220,
              height: 56,
              child: FittedBox(
                child: Text(
                  'ORBIT',
                  style: GoogleFonts.orbitron(
                    color: const Color(0xFF8CEFFF),
                    fontSize: 58,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    height: 1.0,
                    shadows: const [
                      Shadow(
                        color: Color(0x668CEFFF),
                        blurRadius: 24,
                      ),
                      Shadow(
                        color: Color(0x4038BDF8),
                        blurRadius: 36,
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
          top: 210,
          child: Center(
            child: Text(
              strings.menuTagline,
              style: GoogleFonts.inter(
                color: kTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.4,
              ),
            ),
          ),
        ),

        // ── Telemetry Labels above Planet ──────────────────────────────────
        Positioned(
          left: 24,
          top: 275,
          child: Text(
            'SOL SYSTEM / 03',
            style: GoogleFonts.inter(
              color: const Color(0xFF647B9B),
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Positioned(
          right: 24,
          top: 275,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF8CEFFF),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x808CEFFF),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'SYNCED',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8CEFFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        // ── Equipped 3D Planet Body ─────────────────────────────────────────
        Positioned(
          left: _kPlanetCenter.dx - _kPlanetRadius,
          top: _kPlanetCenter.dy - _kPlanetRadius,
          width: _kPlanetRadius * 2,
          height: _kPlanetRadius * 2,
          child: _MenuPlanet(planet: equippedPlanet),
        ),

        // ── Inclined Orbit Ring + Companion System ─────────────────────────
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OrbitSystemPainter(_clock, planet: equippedPlanet),
              ),
            ),
          ),
        ),

        // ── Planet Caption Capsule (• TERRA • LUNA COMPANION) ───────────────
        Positioned(
          left: 0,
          right: 0,
          top: 546,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: ShapeDecoration(
                color: const Color(0xD90C1626),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 1,
                    color: Color(0x268CEFFF),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x30000000),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF8CEFFF),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x608CEFFF),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${equippedPlanet.name.toUpperCase()}  •  ${equippedPlanet.companionName.toUpperCase()} ${strings.companion}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB8D9ED),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── PLAY gravity-wave button (center 195,638) ───────────────────────
        Positioned(
          left: _kPlayCenter.dx - 70,
          top: _kPlayCenter.dy - 70,
          width: 140,
          height: 140,
          child: RepaintBoundary(
            child: _PlayButton(clock: _clock, onTap: _openGame, label: strings.play),
          ),
        ),

        // ── Continue line (distance / level) ────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 720,
          child: Center(
            child: Selector<GameStateProvider, int>(
              selector: (_, g) => g.bestDistance,
              builder: (_, best, _) => Text(
                best > 0
                    ? strings.journeyContinue(best)
                    : strings.journeyBegin,
                style: GoogleFonts.inter(
                  color: const Color(0xFF7F91AB),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),

        // ── Hangar / Celestial Market Glass Card (x24 w342 y754) ────────────
        Positioned(
          left: 24,
          top: 754,
          width: 342,
          height: 56,
          child: _Pressable(
            onTap: _openHangar,
            semanticLabel: strings.hangarTitle,
            child: Container(
              key: const Key('menu_hangar_button'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: ShapeDecoration(
                color: const Color(0xD90C1626),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 1,
                    color: Color(0x268CEFFF),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                children: [
                  FigmaIcon.rocket(size: 22, color: const Color(0xFF8CEFFF)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      strings.hangarTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFFF0F7FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101B2C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF1E3250),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$unlockedCount / ${FleetCatalog.worlds.length} UNLOCKED',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF8CEFFF),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FigmaIcon.chevron(size: 14, color: const Color(0xFF8CEFFF)),
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
// Sub-components: Pressable, Wallet Pill, Planet, Play Button & Orbit Painter
// ═════════════════════════════════════════════════════════════════════════════

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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: ShapeDecoration(
        color: const Color(0xFF101B2C),
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x268CEFFF),
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x80FFD166),
                  blurRadius: 10,
                ),
              ],
            ),
            child: FigmaIcon.stardust(size: 15),
          ),
          const SizedBox(width: 8),
          Text(
            formatThousands(amount),
            style: GoogleFonts.orbitron(
              color: const Color(0xFFF0F7FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Stardust',
            style: GoogleFonts.inter(
              color: const Color(0xFF9BACCA),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

String formatThousands(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _MenuPlanet extends StatelessWidget {
  final FleetPlanet planet;
  const _MenuPlanet({required this.planet});

  static const double _textureScale = 1024 / 888;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: planet.glowColor.withValues(alpha: 0.45),
            blurRadius: 36,
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
                cacheWidth: 512,
                cacheHeight: 512,
                gaplessPlayback: true,
              ),
            ),
            // Terminator shading: lit from upper-left
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
            // Atmospheric rim
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: planet.primaryColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play Triangle Icon
              CustomPaint(
                size: const Size(20, 22),
                painter: _PlayTrianglePainter(),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFF0F7FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, 2)
      ..lineTo(size.width - 2, size.height / 2)
      ..lineTo(2, size.height - 2)
      ..close();

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF8CEFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF8CEFFF);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
    ..color = kAccentColor.withValues(alpha: 0.20);
  final Paint _ringGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = const Color(0xFF8CEFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = clock.value * _kLoopSeconds;
    final p = (t % _kPulsePeriod) / _kPulsePeriod;
    final breath = 0.5 + 0.5 * sin(p * 2 * pi);

    // Inner core (r 48, dark cyan radial gradient)
    _corePaint.shader = const RadialGradient(
      colors: [
        Color(0x250C1626),
        Color(0x9504101E),
      ],
    ).createShader(Rect.fromCircle(center: c, radius: 48));
    canvas.drawCircle(c, 48, _corePaint);

    // Expanding gravity waves (2 rings)
    for (int i = 0; i < 2; i++) {
      final waveP = (p + i * 0.45) % 1.0;
      _wavePaint.color = const Color(0xFF8CEFFF).withValues(alpha: 0.35 * (1 - waveP));
      canvas.drawCircle(
        c,
        48.0 + 26.0 * Curves.easeOut.transform(waveP),
        _wavePaint,
      );
    }

    // Static outer halo (r 62)
    canvas.drawCircle(c, 62, _staticHaloPaint);

    // Main ring glow
    _ringGlowPaint.color = const Color(0xFF8CEFFF).withValues(alpha: 0.35 + 0.35 * breath);
    canvas.drawCircle(c, 48.0, _ringGlowPaint);

    // Main ring stroke
    canvas.drawCircle(c, 48.0, _ringPaint);
  }

  @override
  bool shouldRepaint(covariant _PlayRingsPainter old) => false;
}

/// Orbit ring around equipped planet + companion gliding along it with a comet tail.
class _OrbitSystemPainter extends CustomPainter {
  final Animation<double> clock;
  final FleetPlanet planet;

  _OrbitSystemPainter(this.clock, {required this.planet}) : super(repaint: clock);

  static final double _startAngle = atan2(364 - 434.0, 309.8 - 195.0);
  static const double _tailSweep = 0.95;

  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;
  final Paint _nebulaGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
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
  Shader? _cachedMoonShader;
  Shader? _cachedTailShader;
  FleetPlanet? _cachedPlanet;
  static const Rect _unitOrbitRect =
      Rect.fromLTWH(-_kOrbitRadius, -_kOrbitRadius, _kOrbitRadius * 2, _kOrbitRadius * 2);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _kLoopSeconds;
    final angle = _startAngle - 2 * pi * (t / _kMoonPeriod);
    final ringRect = Rect.fromCircle(center: _kPlanetCenter, radius: _kOrbitRadius);

    // Inclined elliptical orbit rings
    _ringPaint.color = planet.primaryColor.withValues(alpha: 0.40);
    canvas.drawCircle(_kPlanetCenter, _kOrbitRadius, _ringPaint);

    // Nebula glow under tail
    _nebulaGlowPaint.color = planet.glowColor.withValues(alpha: 0.18);
    canvas.drawArc(
      ringRect,
      angle,
      _tailSweep,
      false,
      _nebulaGlowPaint,
    );

    if (_cachedMoonShader == null || _cachedTailShader == null || _cachedPlanet != planet) {
      _cachedPlanet = planet;
      _cachedMoonShader = RadialGradient(
        center: const Alignment(-0.4, -0.45),
        radius: 1.1,
        colors: [planet.companionColor, planet.glowColor],
      ).createShader(
        const Rect.fromLTWH(-_kMoonRadius, -_kMoonRadius, _kMoonRadius * 2, _kMoonRadius * 2),
      );
      _cachedTailShader = SweepGradient(
        startAngle: 0,
        endAngle: _tailSweep,
        colors: [
          planet.primaryColor.withValues(alpha: 0.9),
          planet.primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(_unitOrbitRect);
    }

    canvas.save();
    canvas.translate(_kPlanetCenter.dx, _kPlanetCenter.dy);
    canvas.rotate(angle);
    _tailPaint.shader = _cachedTailShader;
    canvas.drawArc(
      _unitOrbitRect,
      0,
      _tailSweep,
      false,
      _tailPaint,
    );
    canvas.restore();

    for (int i = 0; i < 5; i++) {
      final a = angle + _tailSweep + 0.08 + i * 0.07;
      _dotPaint.color = planet.primaryColor.withValues(alpha: 0.6 - i * 0.12);
      canvas.drawCircle(
        _kPlanetCenter + Offset(cos(a), sin(a)) * _kOrbitRadius,
        1,
        _dotPaint,
      );
    }

    final moon = _kPlanetCenter + Offset(cos(angle), sin(angle)) * _kOrbitRadius;
    _moonGlowPaint.color = planet.companionColor.withValues(alpha: 0.35);
    canvas.drawCircle(
      moon,
      _kMoonRadius + 4,
      _moonGlowPaint,
    );

    canvas.save();
    canvas.translate(moon.dx, moon.dy);
    _moonPaint.shader = _cachedMoonShader;
    canvas.drawCircle(
      Offset.zero,
      _kMoonRadius,
      _moonPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitSystemPainter old) => old.planet != planet;
}

class _TwinklePainter extends CustomPainter {
  final Animation<double> clock;
  _TwinklePainter(this.clock) : super(repaint: clock);

  static final List<({double x, double y, double baseR, double speed, double phase})> _stars = () {
    final rng = Random(1337);
    return List.generate(45, (i) {
      return (
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        baseR: 0.6 + rng.nextDouble() * 1.4,
        speed: 1.5 + rng.nextDouble() * 3.5,
        phase: rng.nextDouble() * 2 * pi,
      );
    });
  }();

  final Paint _starPaint = Paint()..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _kLoopSeconds;
    for (final s in _stars) {
      final wave = 0.5 + 0.5 * sin(t * s.speed + s.phase);
      _starPaint.color = Colors.white.withValues(alpha: 0.20 + 0.70 * wave);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.baseR * (0.8 + 0.4 * wave),
        _starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter old) => false;
}
