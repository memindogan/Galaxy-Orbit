/// Game Over (Orbit Lost) and Level/Sector Complete modals.
///
/// Crafted 1:1 against Figma design specifications:
///  - Orbit Lost: c0f7d2b3-59dd-4590-954a-f51bf14627cd.png
///  - Level Complete: c0e62e08-c27d-485e-b16e-ce7f7854aac0.png
library;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/theme_constants.dart';
import '../models/fleet_planet.dart';
import '../painters/game_painter.dart';
import '../providers/settings_provider.dart';
import '../widgets/figma_icons.dart';

String _formatNum(int n) {
  if (n >= 0 && n < 1000) return n.toString();
  final s = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. ORBIT LOST MODAL (Game Over — Animated Figma Spec)
// ─────────────────────────────────────────────────────────────────────────────

class OrbitLostModal extends StatefulWidget {
  final int score;
  final int level;
  final int highScore;
  final int runStarDust;
  final int totalWalletStarDust;
  final int orbitsCompleted;
  final int bestCombo;
  final bool isNewHighScore;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final bool canRevive;
  final bool canAffordRevive;
  final int reviveCost;
  final int remainingRevives;
  final int maxRevives;
  final VoidCallback? onRevive;
  final bool isTimeUp;
  final bool isTimeAttack;
  final FleetPlanet? equippedPlanet;

  const OrbitLostModal({
    super.key,
    required this.score,
    required this.level,
    required this.highScore,
    required this.runStarDust,
    required this.totalWalletStarDust,
    required this.onRetry,
    required this.onMenu,
    this.orbitsCompleted = 0,
    this.bestCombo = 0,
    this.isNewHighScore = false,
    this.canRevive = true,
    this.canAffordRevive = false,
    this.reviveCost = 25,
    this.remainingRevives = 3,
    this.maxRevives = 3,
    this.onRevive,
    this.isTimeUp = false,
    this.isTimeAttack = false,
    this.equippedPlanet,
  });

  @override
  State<OrbitLostModal> createState() => _OrbitLostModalState();
}

class _OrbitLostModalState extends State<OrbitLostModal>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _rocketLaunchController;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _cardScale;
  late final Animation<double> _actionsFade;
  late final Animation<Offset> _actionsSlide;

  bool _isLaunchingRetry = false;

  @override
  void initState() {
    super.initState();

    // 1. Staggered Entrance & Score Card Spring (650ms total)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(_headerFade);

    _cardFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.15, 0.72, curve: Curves.easeOut),
    );
    _cardScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOutBack),
      ),
    );

    _actionsFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );
    _actionsSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(_actionsFade);

    // 2. Rocket Launch Animation when TRY AGAIN is tapped (380ms)
    _rocketLaunchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _rocketLaunchController.dispose();
    super.dispose();
  }

  Future<void> _handleRetryTap(bool reducedMotion) async {
    if (_isLaunchingRetry) return;
    setState(() => _isLaunchingRetry = true);
    if (!reducedMotion) {
      await _rocketLaunchController.forward(from: 0.0);
    }
    if (mounted) {
      widget.onRetry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = settings.strings;
    final isLowQuality = settings.graphicsQuality == GraphicsQuality.low;
    final reducedMotion = settings.reducedMotion;
    final planet = widget.equippedPlanet ?? FleetCatalog.worlds.first;

    final bool isReviveActive = widget.canRevive &&
        widget.canAffordRevive &&
        widget.remainingRevives > 0 &&
        widget.onRevive != null;
    final bool showNewHigh =
        widget.isNewHighScore || (widget.score > 0 && widget.score >= widget.highScore);

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: GoogleFonts.inter(
          decoration: TextDecoration.none,
          color: Colors.white,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // Absorb backdrop taps
          child: Stack(
            children: [
              // ── 1. Deep Space Gradient & Radial Nebulae (Figma 1:1) ──────
              Positioned.fill(
                child: isLowQuality
                    ? const ColoredBox(color: Color(0xF203060E))
                    : ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xEB050814),
                                  Color(0xF502040A),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              // Top-center ambient indigo-blue radial glow
              Positioned(
                top: 40,
                left: -40,
                right: -40,
                height: 390,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x65172867),
                          Color(0x200C1F3A),
                          Color(0x00050814),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Secondary upper-right violet glow near paper plane
              Positioned(
                top: 155,
                right: 24,
                width: 165,
                height: 130,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x385534AF),
                          Color(0x005534AF),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Ambient Stardust Field Dots
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _OrbitLostBackdropPainter(),
                  ),
                ),
              ),

              // ── 2. Main Modal Content Layout (Edge-to-Edge Adaptive Distribution) ──
              Positioned.fill(
                child: SafeArea(
                  top: true,
                  bottom: true,
                  minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double availableHeight = constraints.maxHeight;

                          // Child 1: Header Section (Fade + Slide Down)
                          final Widget headerWidget = FadeTransition(
                            opacity: _headerFade,
                            child: SlideTransition(
                              position: _headerSlide,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Top Pill: • LEVEL 5 · FLIGHT ENDED
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xCC0A1224),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0x4000F0FF),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF00F0FF),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0xCC00F0FF),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.isTimeAttack
                                              ? strings.timeAttackEnded(widget.level)
                                              : strings.runEnded(widget.level),
                                          style: GoogleFonts.orbitron(
                                            color: const Color(0xFFD6E4FF),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Glowing ORBIT LOST Title
                                  Text(
                                    widget.isTimeUp
                                        ? strings.timeUpTitle
                                        : strings.orbitLost,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.orbitron(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 3.0,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x9900F0FF),
                                          blurRadius: 18,
                                        ),
                                        Shadow(
                                          color: Color(0x4D0080FF),
                                          blurRadius: 34,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 5),

                                  // Italic Quote
                                  Text(
                                    widget.isTimeUp
                                        ? strings.timeUpQuote
                                        : strings.orbitLostQuote,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8DA2C0),
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Companion Satellite & Planet Silhouette Trajectory Graphic ("SIGNAL LOST / 05")
                                  SizedBox(
                                    height: 56,
                                    width: double.infinity,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _SignalLostCompanionPainter(
                                              planet: planet,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 12,
                                          bottom: 8,
                                          child: Text(
                                            strings.signalLostCode(widget.level),
                                            style: GoogleFonts.orbitron(
                                              color: const Color(0xFF475B78),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          // Child 2: Center Section (Score Card + Standalone Revive Button)
                          final Widget centerSection = Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: _cardFade,
                                child: ScaleTransition(
                                  scale: _cardScale,
                                  child: _FigmaScoreCard(
                                    score: widget.score,
                                    highScore: widget.highScore,
                                    runStarDust: widget.runStarDust,
                                    orbitsCompleted: widget.orbitsCompleted,
                                    bestCombo: widget.bestCombo,
                                    showNewHigh: showNewHigh,
                                    reducedMotion: reducedMotion,
                                    runScoreLabel: strings.runScore,
                                    newHighLabel: strings.newHighBadge,
                                    highScoreText:
                                        strings.highScoreLabel(_formatNum(widget.highScore)),
                                    stardustPillText:
                                        strings.stardustPill(widget.runStarDust),
                                    orbitsText: strings.orbitsPill(widget.orbitsCompleted),
                                    comboText: strings.comboPill(widget.bestCombo),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 1. RETURN TO ORBIT Card (Stands alone in the middle section)
                              FadeTransition(
                                opacity: _actionsFade,
                                child: _FigmaReviveButton(
                                  key: const Key('revive_button'),
                                  label: widget.canRevive && widget.remainingRevives > 0
                                      ? strings.reviveLabel(
                                          widget.remainingRevives,
                                          widget.maxRevives,
                                        )
                                      : strings.reviveExhausted,
                                  cost: widget.reviveCost,
                                  showCost:
                                      widget.canRevive && widget.remainingRevives > 0,
                                  enabled: isReviveActive,
                                  heartbeatActive: isReviveActive && !reducedMotion,
                                  onTap: widget.onRevive,
                                ),
                              ),
                            ],
                          );

                          // Child 3: Bottom Action Group (Pushed down to the bottom, holding wallet)
                          final Widget bottomActions = FadeTransition(
                            opacity: _actionsFade,
                            child: SlideTransition(
                              position: _actionsSlide,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // TRY AGAIN Button (Neon Cyan)
                                  _FigmaTryAgainButton(
                                    label: strings.retry,
                                    rocketAnimation: _rocketLaunchController,
                                    onTap: () => _handleRetryTap(reducedMotion),
                                  ),
                                  const SizedBox(height: 10),

                                  // MAIN MENU Button
                                  _FigmaMainMenuButton(
                                    label: strings.menu,
                                    onTap: widget.onMenu,
                                  ),
                                  const SizedBox(height: 12),

                                  // Total Wallet Footer
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const _WalletChipIcon(),
                                      const SizedBox(width: 7),
                                      Text(
                                        strings.walletPill(
                                          _formatNum(widget.totalWalletStarDust),
                                        ),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF6E84A3),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        ' · Stardust',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF6E84A3),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          // On modern tall screens (height >= 680), distribute top, center, bottom with Spacer
                          // On shorter devices/tests, wrap in a scroll view with balanced spacing to prevent overflows
                          if (availableHeight >= 680) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                headerWidget,
                                const Spacer(flex: 1),
                                centerSection,
                                const Spacer(flex: 2),
                                bottomActions,
                              ],
                            );
                          } else {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  headerWidget,
                                  const SizedBox(height: 12),
                                  centerSection,
                                  const SizedBox(height: 16),
                                  bottomActions,
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ambient twinkling stardust dots in the Orbit Lost background.
class _OrbitLostBackdropPainter extends CustomPainter {
  const _OrbitLostBackdropPainter();

  static const List<(double, double, double, double)> _dots = [
    (0.07, 0.05, 1.2, 0.50),
    (0.23, 0.03, 0.8, 0.45),
    (0.81, 0.04, 1.2, 0.40),
    (0.91, 0.11, 0.9, 0.70),
    (0.09, 0.21, 1.3, 0.45),
    (0.16, 0.28, 0.8, 0.65),
    (0.83, 0.32, 1.2, 0.40),
    (0.94, 0.40, 0.9, 0.70),
    (0.04, 0.50, 0.9, 0.50),
    (0.95, 0.60, 1.1, 0.55),
    (0.06, 0.74, 1.0, 0.45),
    (0.92, 0.89, 1.1, 0.50),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final d in _dots) {
      paint.color = const Color(0xFFECFAFF).withValues(alpha: d.$4);
      canvas.drawCircle(
        Offset(size.width * d.$1, size.height * d.$2),
        d.$3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders a distant stylized planet silhouette, orbital trajectory arc,
/// cyan/purple exhaust wake, and the equipped planet's companion satellite/probe vessel.
class _SignalLostCompanionPainter extends CustomPainter {
  final FleetPlanet planet;

  const _SignalLostCompanionPainter({required this.planet});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Distant Planet Silhouette (Celestial Body with Atmospheric Glow)
    // ─────────────────────────────────────────────────────────────────────────
    final planetCenter = Offset(w * 0.38, h * 0.50);
    const planetRadius = 24.0;

    // Atmospheric corona / outer space glow
    final atmosphereGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          planet.glowColor.withValues(alpha: 0.30),
          planet.primaryColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.60, 1.0],
      ).createShader(Rect.fromCircle(center: planetCenter, radius: planetRadius * 2.2));
    canvas.drawCircle(planetCenter, planetRadius * 2.2, atmosphereGlow);

    // Planet celestial sphere body (dark shadow with colored limb tint)
    final planetBodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        radius: 0.95,
        colors: [
          planet.primaryColor.withValues(alpha: 0.40),
          const Color(0xFF0C1628),
          const Color(0xFF030712),
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: planetCenter, radius: planetRadius));
    canvas.drawCircle(planetCenter, planetRadius, planetBodyPaint);

    // Crescent highlight along illuminated limb
    final crescentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = planet.glowColor.withValues(alpha: 0.65);
    canvas.drawArc(
      Rect.fromCircle(center: planetCenter, radius: planetRadius - 0.7),
      -2.4,
      2.0,
      false,
      crescentPaint,
    );

    // Stylized celestial planetary rings tilted across the silhouette
    canvas.save();
    canvas.translate(planetCenter.dx, planetCenter.dy);
    canvas.rotate(-0.35);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = planet.glowColor.withValues(alpha: 0.32);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: planetRadius * 3.1, height: planetRadius * 0.75),
      ringPaint,
    );
    ringPaint
      ..strokeWidth = 0.5
      ..color = const Color(0x18ECFAFF);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: planetRadius * 3.5, height: planetRadius * 0.90),
      ringPaint,
    );
    canvas.restore();

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Orbital Trajectory Arcs
    // ─────────────────────────────────────────────────────────────────────────
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0x2600F0FF);

    canvas.save();
    canvas.translate(w * 0.48, h * 0.72);
    canvas.rotate(-0.14);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 1.18, height: 64),
      orbitPaint,
    );
    orbitPaint.color = const Color(0x1400F0FF);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: w * 1.32, height: 84),
      orbitPaint,
    );
    canvas.restore();

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Dashed Cyan/Violet Wake leading to the Companion Satellite
    // ─────────────────────────────────────────────────────────────────────────
    final vesselX = w * 0.79;
    final vesselY = h * 0.34;

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i <= 5; i++) {
      final t1 = i * 0.14;
      final t2 = t1 + 0.06;
      final x1 = vesselX - t1 * 125;
      final y1 = vesselY + t1 * 44;
      final x2 = vesselX - t2 * 125;
      final y2 = vesselY + t2 * 44;
      dashPaint.color = planet.companionColor.withValues(
        alpha: (0.85 - i * 0.14).clamp(0.15, 0.85),
      );
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dashPaint);
    }

    // Wake sparkles
    final dotPaint = Paint()..style = PaintingStyle.fill;
    dotPaint.color = planet.glowColor.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(vesselX - 24, vesselY + 14), 1.8, dotPaint);
    dotPaint.color = const Color(0x9900F0FF);
    canvas.drawCircle(Offset(vesselX - 42, vesselY + 22), 2.1, dotPaint);
    dotPaint.color = planet.companionColor.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(vesselX - 60, vesselY + 26), 1.5, dotPaint);

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Equipped Planet's Satellite / Companion Probe Vessel
    // ─────────────────────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(vesselX, vesselY);
    canvas.rotate(-0.38); // Tangent to orbit heading
    canvas.scale(1.35);   // Scaled up for crisp UI icon visibility

    // Soft beacon glow behind the vessel
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = planet.companionColor.withValues(alpha: 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, 8.0, glowPaint);

    // Render the exact bespoke vessel for this fleet world
    GamePainter.drawCompanionVessel(canvas, planet);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SignalLostCompanionPainter oldDelegate) =>
      oldDelegate.planet != planet;
}

/// Score Card with subtle blueprint grid, top violet highlight bar,
/// conditional shimmering NEW HIGH! badge, and 3 bottom metric pills.
class _FigmaScoreCard extends StatelessWidget {
  final int score;
  final int highScore;
  final int runStarDust;
  final int orbitsCompleted;
  final int bestCombo;
  final bool showNewHigh;
  final bool reducedMotion;
  final String runScoreLabel;
  final String newHighLabel;
  final String highScoreText;
  final String stardustPillText;
  final String orbitsText;
  final String comboText;

  const _FigmaScoreCard({
    required this.score,
    required this.highScore,
    required this.runStarDust,
    required this.orbitsCompleted,
    required this.bestCombo,
    required this.showNewHigh,
    required this.reducedMotion,
    required this.runScoreLabel,
    required this.newHighLabel,
    required this.highScoreText,
    required this.stardustPillText,
    required this.orbitsText,
    required this.comboText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE60B1328),
            Color(0xF2070C1A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x475E439C),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top glowing purple rim highlight bar
          Positioned(
            top: 0,
            left: 28,
            right: 28,
            height: 2.2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00A36BFF),
                    Color(0xFFB997FF),
                    Color(0x00A36BFF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x80A36BFF),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          // Foreground content
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // RUN SCORE label
                Text(
                  runScoreLabel,
                  style: GoogleFonts.orbitron(
                    color: const Color(0xFF00F0FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 14),

                // Giant Score + Conditional Animated NEW HIGH! Badge
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      _formatNum(score),
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        shadows: const [
                          Shadow(
                            color: Color(0x40FFFFFF),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                    if (showNewHigh)
                      _ShimmeringNewHighBadge(
                        label: newHighLabel,
                        reducedMotion: reducedMotion,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // High Score Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FigmaIcon.trophy(
                      size: 14,
                      color: const Color(0xFF7B93B6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      highScoreText,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7B93B6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Horizontal Divider
                Container(
                  height: 1,
                  width: double.infinity,
                  color: const Color(0x267393C3),
                ),
                const SizedBox(height: 18),

                // 3 Bottom Metric Pills: +45 Stardust | 12 Orbits | x5 Combo
                Row(
                  children: [
                    // 1. Stardust
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.star_border_rounded,
                            size: 16,
                            color: Color(0xFFFFD166),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              stardustPillText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: const Color(0x267393C3),
                    ),
                    // 2. Orbits
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FigmaIcon.orbit(
                            size: 14,
                            color: const Color(0xFF00F0FF),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              orbitsText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: const Color(0x267393C3),
                    ),
                    // 3. Combo
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: Color(0xFFE879F9),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              comboText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 1. Conditional NEW HIGH! Badge — only appears on a new high score and pulses/shimmers!
class _ShimmeringNewHighBadge extends StatefulWidget {
  final String label;
  final bool reducedMotion;

  const _ShimmeringNewHighBadge({
    required this.label,
    required this.reducedMotion,
  });

  @override
  State<_ShimmeringNewHighBadge> createState() =>
      _ShimmeringNewHighBadgeState();
}

class _ShimmeringNewHighBadgeState extends State<_ShimmeringNewHighBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  int _cycles = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (!widget.reducedMotion) {
      _shimmerController.addStatusListener(_onStatus);
      _shimmerController.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) return;
    // Run 6 full pulse cycles (~6.6 seconds of lively glow) or stop cleanly when settled
    if (status == AnimationStatus.completed) {
      _shimmerController.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _cycles++;
      if (_cycles < 6) {
        _shimmerController.forward();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final p = _shimmerController.value;
        final scale = 1.0 + 0.055 * p;
        return Transform.scale(
          scale: scale,
          child: Container(
            key: const Key('new_high_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(
                    const Color(0xFF4A3818),
                    const Color(0xFF70531F),
                    p,
                  )!,
                  Color.lerp(
                    const Color(0xFF332610),
                    const Color(0xFF523C14),
                    p,
                  )!,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Color.lerp(
                  const Color(0x99FBBF24),
                  const Color(0xFFFFE066),
                  p,
                )!,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24)
                      .withValues(alpha: 0.25 + 0.38 * p),
                  blurRadius: 10 + 10 * p,
                  spreadRadius: 1.5 * p,
                ),
              ],
            ),
            child: Text(
              widget.label,
              style: GoogleFonts.orbitron(
                color: const Color(0xFFFFD56B),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 2. RETURN TO ORBIT Card — Heart icon beats ONLY when `heartbeatActive` is true
/// (player has remaining revives AND sufficient Stardust).
class _FigmaReviveButton extends StatefulWidget {
  final String label;
  final int cost;
  final bool showCost;
  final bool enabled;
  final bool heartbeatActive;
  final VoidCallback? onTap;

  const _FigmaReviveButton({
    super.key,
    required this.label,
    required this.cost,
    required this.showCost,
    required this.enabled,
    required this.heartbeatActive,
    this.onTap,
  });

  @override
  State<_FigmaReviveButton> createState() => _FigmaReviveButtonState();
}

class _FigmaReviveButtonState extends State<_FigmaReviveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  int _beatCount = 0;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _syncHeartAnimation();
  }

  @override
  void didUpdateWidget(covariant _FigmaReviveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heartbeatActive != widget.heartbeatActive) {
      _syncHeartAnimation();
    }
  }

  void _syncHeartAnimation() {
    _heartController.removeStatusListener(_onBeatStatus);
    if (widget.heartbeatActive) {
      _beatCount = 0;
      _heartController.addStatusListener(_onBeatStatus);
      _heartController.forward(from: 0.0);
    } else {
      _heartController.stop();
      _heartController.value = 0.0;
    }
  }

  void _onBeatStatus(AnimationStatus status) {
    if (!mounted || !widget.heartbeatActive) return;
    if (status == AnimationStatus.completed) {
      _beatCount++;
      // Keep beating while open (cap at 15 cycles so automated pumpAndSettle tests never hang)
      if (_beatCount < 15) {
        _heartController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  /// Double-pulse lub-dub heartbeat curve matching the Figma video.
  double _heartScale(double t) {
    if (!widget.heartbeatActive) return 1.0;
    if (t < 0.18) {
      return 1.0 + 0.24 * sin((t / 0.18) * pi);
    } else if (t < 0.38) {
      return 1.0 + 0.15 * sin(((t - 0.18) / 0.20) * pi);
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.45,
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.enabled
                      ? const [
                          Color(0xFF39204C),
                          Color(0xFF20132E),
                        ]
                      : const [
                          Color(0xFF161A29),
                          Color(0xFF0E121D),
                        ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.enabled
                      ? const Color(0x80D880E8)
                      : const Color(0x337393C3),
                  width: 1.2,
                ),
                boxShadow: widget.enabled
                    ? const [
                        BoxShadow(
                          color: Color(0x38A855F7),
                          blurRadius: 18,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Beating Heart Icon (Static when disabled / out of revives / low Stardust)
                    AnimatedBuilder(
                      animation: _heartController,
                      builder: (context, child) {
                        final s = _heartScale(_heartController.value);
                        return Transform.scale(
                          scale: s,
                          child: Container(
                            key: ValueKey<bool>(widget.heartbeatActive),
                            child: Icon(
                              Icons.favorite_border_rounded,
                              size: 21,
                              color: widget.enabled
                                  ? const Color(0xFFE879F9)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),

                    // RETURN TO ORBIT (2/3)
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),

                    if (widget.showCost) ...[
                      Container(
                        width: 1,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: const Color(0x40D880E8),
                      ),
                      Text(
                        '${widget.cost}',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFF3D1FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Stardust',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE5B8F7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3. TRY AGAIN Button — Rocket icon animates/launches ONLY when tapped,
/// then navigates back into the game screen.
class _FigmaTryAgainButton extends StatelessWidget {
  final String label;
  final Animation<double> rocketAnimation;
  final VoidCallback onTap;

  const _FigmaTryAgainButton({
    required this.label,
    required this.rocketAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('try_again_button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF00F0FF),
                  Color(0xFF0088FF),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x5900D8FF),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: rocketAnimation,
                    builder: (context, child) {
                      final t = Curves.easeInBack.transform(
                        rocketAnimation.value.clamp(0.0, 1.0),
                      );
                      final dx = t * 28.0;
                      final dy = -t * 24.0;
                      final scale = 1.0 + rocketAnimation.value * 0.25;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      size: 19,
                      color: Color(0xFF030816),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.orbitron(
                      color: const Color(0xFF030816),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// MAIN MENU Outlined Dark Glass Button.
class _FigmaMainMenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FigmaMainMenuButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('main_menu_button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xB3070D1B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x592E8ABC),
                width: 1.1,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.home_outlined,
                    size: 18,
                    color: Color(0xFF8CEFFF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletChipIcon extends StatelessWidget {
  const _WalletChipIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF6E84A3),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: FigmaIcon.stardust(
        size: 10,
        color: const Color(0xFF6E84A3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. LEVEL COMPLETE MODAL (Sector Clear)
// ─────────────────────────────────────────────────────────────────────────────

class LevelCompleteModal extends StatelessWidget {
  final int score;
  final int level;
  final int highScore;
  final int combo;
  final int sectorStarDust;
  final int totalWalletStarDust;
  final VoidCallback onNextLevel;
  final VoidCallback onMenu;

  const LevelCompleteModal({
    super.key,
    required this.score,
    required this.level,
    required this.highScore,
    required this.combo,
    required this.sectorStarDust,
    required this.totalWalletStarDust,
    required this.onNextLevel,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = settings.strings;
    final isLowQuality = settings.graphicsQuality == GraphicsQuality.low;
    final stageBonus = 100 + level * 20;
    final comboBonus = combo * 20;
    final stardustEarned = sectorStarDust > 0 ? sectorStarDust : (120 + level * 10);
    final nextSubtitle = strings.sectorSubtitle(level + 1);

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: GoogleFonts.inter(
          decoration: TextDecoration.none,
          color: Colors.white,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // Absorb backdrop taps
          child: Stack(
            children: [
              // ── Deep Space Darkening Veil (ensures contrast over bright planets) ──
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x8C030712),
                ),
              ),

              // ── Frosted Glass Backdrop (Icy Frost Blur) ─────────────────────
              Positioned.fill(
                child: isLowQuality
                    ? Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xD90E2644),
                              Color(0xE6081426),
                              Color(0xF5040711),
                            ],
                            stops: [0.0, 0.45, 1.0],
                          ),
                        ),
                      )
                    : ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x800E2644), // frosty cyan sheen
                                  Color(0xA6081426), // deep translucent icy slate
                                  Color(0xD1040711), // deep space night
                                ],
                                stops: [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              // ── Frost Crystal Light Wash (Diagonal Sheen) ───────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1.0, -1.0),
                        end: const Alignment(1.0, 1.0),
                        colors: [
                          const Color(0xFF8CEFFF).withValues(alpha: 0.09),
                          Colors.transparent,
                          const Color(0xFF8CEFFF).withValues(alpha: 0.04),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Subtle Frost Shimmer Vignette ──────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.20),
                        radius: 0.85,
                        colors: [
                          const Color(0xFF8CEFFF).withValues(alpha: 0.09),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Modal Animated Content ─────────────────────────────────────
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * value,
                    child: RepaintBoundary(child: child),
                  ),
                );
              },
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Glowing Cyan Concentric Emblem
                        const _LevelCompleteEmblem(),
                        const SizedBox(height: 20),

                        // Level and status caption
                        Text(
                          strings.allCaptured(level),
                          style: GoogleFonts.orbitron(
                            color: kAccentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Main Title
                        Text(
                          strings.levelComplete,
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle / quote
                        Text(
                          strings.levelCompleteQuote,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: kTextMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Glassmorphic Breakdown Card (Frosted Ice Aesthetic) ─
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E1A2D).withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF8CEFFF).withValues(alpha: 0.22),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: const Color(0xFF8CEFFF).withValues(alpha: 0.06),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header: RUN SCORE | 3,960
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    strings.runScore,
                                    style: GoogleFonts.inter(
                                      color: kTextMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Text(
                                    _formatNum(score),
                                    style: GoogleFonts.orbitron(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(
                                color: const Color(0xFF9BBDEA).withValues(alpha: 0.16),
                                height: 1,
                                thickness: 1,
                              ),
                              const SizedBox(height: 16),

                              // Row 1: Stage cleared
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    strings.stageCleared,
                                    style: GoogleFonts.inter(
                                      color: kTextMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    '+$stageBonus',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Row 2: Flawless combo
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    strings.flawlessCombo(combo > 0 ? combo : 1),
                                    style: GoogleFonts.inter(
                                      color: kTextMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    '+$comboBonus',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Row 3: Stardust earned
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    strings.stardustEarned,
                                    style: GoogleFonts.inter(
                                      color: kAccentColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '+$stardustEarned',
                                    style: GoogleFonts.orbitron(
                                      color: kAccentColor,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Wallet and High Score Footer ───────────────────
                        Text(
                          strings.walletHighScoreSummary(_formatNum(totalWalletStarDust), _formatNum(highScore)),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: kTextMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Action Buttons ─────────────────────────────────
                        // NEXT LEVEL button (Neon Cyan)
                        _ModalActionButton(
                          label: strings.nextLevel,
                          icon: Icons.arrow_forward_rounded,
                          isPrimary: true,
                          onTap: onNextLevel,
                        ),
                        const SizedBox(height: 12),

                        // MENU button (Dark Glass)
                        _ModalActionButton(
                          label: strings.menu,
                          isPrimary: false,
                          onTap: onMenu,
                        ),
                        const SizedBox(height: 20),

                        // ── Footnote: Next Challenge ───────────────────────
                        Text(
                          strings.upNext(level + 1, nextSubtitle),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

/// Custom painted glowing cyan concentric emblem for Level Complete.
class _LevelCompleteEmblem extends StatelessWidget {
  const _LevelCompleteEmblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer circle
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: kAccentColor.withValues(alpha: 0.28),
                width: 1.0,
              ),
            ),
          ),
          // Inner circle with glow
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: kAccentColor.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: kAccentColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // Central stardust star
          FigmaIcon.stardust(size: 20, color: kAccentColor),
          // Orbit dot
          Positioned(
            left: 20,
            bottom: 22,
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: const BoxDecoration(
                color: kAccentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Action Button (Primary Neon vs Secondary Glass)
// ─────────────────────────────────────────────────────────────────────────────

class _ModalActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ModalActionButton({
    required this.label,
    this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: isPrimary
                  ? kAccentColor
                  : const Color(0xFF132139).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: const Color(0xFF9BBDEA).withValues(alpha: 0.22),
                      width: 1.0,
                    ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: kAccentColor.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.orbitron(
                      color: isPrimary ? const Color(0xFF050814) : const Color(0xFFF2F7FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      icon,
                      size: 18,
                      color: isPrimary ? const Color(0xFF050814) : const Color(0xFFF2F7FF),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
