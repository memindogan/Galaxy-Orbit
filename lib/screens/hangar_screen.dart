/// Celestial Market / Hangar screen — Figma: "Hangar · Celestial market" frame (390×844).
///
/// Features:
///  1. Header with back button, Stardust wallet, category and "2 / 12 unlocked" tab.
///  2. Hero Showcase Card: real-time revolving planet with companion vessel and orbit ring.
///  3. Worlds & Companions list: 12 celestial worlds with equip/unlock states.
///  4. Bottom Action Button: Unlock / Equip with live Stardust balance deduction.
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
import '../services/haptic_service.dart';
import 'main_menu_screen.dart';

class HangarScreen extends StatefulWidget {
  const HangarScreen({super.key});

  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends State<HangarScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  late String _selectedPlanetId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Default inspected planet is the currently equipped planet
    final gameState = context.read<GameStateProvider>();
    _selectedPlanetId = gameState.equippedPlanetId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_clock.isAnimating) _clock.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_clock.isAnimating) _clock.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  void _onSelectPlanet(String id) {
    if (context.read<SettingsProvider>().vibrationEnabled) {
      HapticService.selectionClick();
    }
    setState(() {
      _selectedPlanetId = id;
    });
  }

  void _onActionButtonPressed() {
    final gameState = context.read<GameStateProvider>();
    final settings = context.read<SettingsProvider>();
    final planet = FleetCatalog.getById(_selectedPlanetId);
    final isUnlocked = gameState.isUnlocked(planet.id);
    final isEquipped = gameState.isEquipped(planet.id);

    if (isEquipped) {
      return;
    }

    if (isUnlocked) {
      gameState.equipPlanet(planet.id);
      if (settings.vibrationEnabled) {
        HapticService.mediumImpact();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: kAccentColor.withValues(alpha: 0.3)),
          ),
          content: Text(
            settings.strings.equippedSnackbar(planet.name, planet.companionName),
            style: GoogleFonts.inter(color: kTextColor, fontSize: 13),
          ),
        ),
      );
      return;
    }

    // Attempt to unlock
    if (gameState.totalStarDust < planet.price) {
      if (settings.vibrationEnabled) {
        HapticService.heavyImpact();
      }
      final needed = planet.price - gameState.totalStarDust;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2A1520),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFF5252), width: 1),
          ),
          content: Text(
            settings.strings.needMoreDustSnackbar(planet.name, needed),
            style: GoogleFonts.inter(color: kTextColor, fontSize: 13),
          ),
        ),
      );
      return;
    }

    final success = gameState.unlockPlanet(planet.id);
    if (success) {
      if (settings.vibrationEnabled) {
        HapticService.heavyImpact();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: kAccentColor, width: 1.5),
          ),
          content: Text(
            settings.strings.unlockedSnackbar(planet.name, planet.companionName),
            style: GoogleFonts.orbitron(
              color: kAccentColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameStateProvider>();
    final settings = context.watch<SettingsProvider>();
    final selectedPlanet = FleetCatalog.getById(_selectedPlanetId);
    final isUnlocked = gameState.isUnlocked(selectedPlanet.id);
    final isEquipped = gameState.isEquipped(selectedPlanet.id);
    final unlockedCount = gameState.unlockedPlanetIds.length;
    final totalDust = gameState.totalStarDust;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          // 1. Galaxy space background (bounded decode cache + gapless playback)
          Positioned.fill(
            child: Image.asset(
              'assets/images/menu_bg.jpg',
              fit: BoxFit.cover,
              cacheWidth: 780,
              gaplessPlayback: true,
            ),
          ),

          // 2. Darkening overlay for readibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kBackgroundColor.withValues(alpha: 0.70),
                    kBackgroundColor.withValues(alpha: 0.85),
                    kBackgroundColor.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 3. Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header bar (back button + wallet)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      GestureDetector(
                        key: const Key('hangar_back_button'),
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kChipSurface.withValues(alpha: 0.10),
                            border: Border.all(
                              color: kBorderSoft.withValues(alpha: 0.20),
                              width: 1.2,
                            ),
                          ),
                          child: FigmaIcon.arrowBack(size: 20),
                        ),
                      ),

                      // Stardust wallet pill
                      _MarketWalletPill(amount: totalDust),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Title section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.strings.celestialMarket,
                        style: GoogleFonts.inter(
                          color: kAccentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.strings.yourCosmicFleet,
                        style: GoogleFonts.orbitron(
                          color: kTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tabs & unlocked count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.strings.worldsAndCompanions,
                                style: GoogleFonts.inter(
                                  color: kAccentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 80,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: kAccentColor,
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kAccentColor.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            settings.strings.unlockedWorlds(unlockedCount, FleetCatalog.worlds.length),
                            style: GoogleFonts.inter(
                              color: kTextMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Scrollable middle section: Hero card + Worlds list (Virtualized ListView.builder)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
                    itemCount: FleetCatalog.worlds.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _HeroShowcaseCard(
                            planet: selectedPlanet,
                            clock: _clock,
                            isUnlocked: isUnlocked,
                            isEquipped: isEquipped,
                          ),
                        );
                      }

                      final world = FleetCatalog.worlds[index - 1];
                      final isItemUnlocked = gameState.isUnlocked(world.id);
                      final isItemEquipped = gameState.isEquipped(world.id);
                      final isItemSelected = world.id == _selectedPlanetId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WorldListCard(
                          key: ValueKey(world.id),
                          planet: world,
                          isUnlocked: isItemUnlocked,
                          isEquipped: isItemEquipped,
                          isSelected: isItemSelected,
                          strings: settings.strings,
                          onTap: () => _onSelectPlanet(world.id),
                          onEquip: () {
                            gameState.equipPlanet(world.id);
                            setState(() => _selectedPlanetId = world.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom floating action bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MarketActionButton(
                    planet: selectedPlanet,
                    isUnlocked: isUnlocked,
                    isEquipped: isEquipped,
                    currentDust: totalDust,
                    strings: settings.strings,
                    onPressed: _onActionButtonPressed,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEquipped
                        ? settings.strings.activeWorldNote
                        : isUnlocked
                            ? settings.strings.readyToDeployNote
                            : settings.strings.afterUnlockNote(max(0, totalDust - selectedPlanet.price)),
                    style: GoogleFonts.inter(
                      color: kTextMuted.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sub-components
// ═════════════════════════════════════════════════════════════════════════════

class _MarketWalletPill extends StatelessWidget {
  final int amount;
  const _MarketWalletPill({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: kPillSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: kBorderSoft.withValues(alpha: 0.20), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FigmaIcon.stardust(size: 15),
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

/// The big showcase card displaying the rotating planet & orbiting companion.
class _HeroShowcaseCard extends StatelessWidget {
  final FleetPlanet planet;
  final Animation<double> clock;
  final bool isUnlocked;
  final bool isEquipped;

  const _HeroShowcaseCard({
    required this.planet,
    required this.clock,
    required this.isUnlocked,
    required this.isEquipped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: kSurfaceColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: planet.primaryColor.withValues(alpha: 0.30),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: planet.glowColor.withValues(alpha: 0.15),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle stars/glow
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      planet.glowColor.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bundle Tag (Top Left)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: planet.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: planet.primaryColor.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                planet.bundleTag,
                style: GoogleFonts.inter(
                  color: planet.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),

          // Status Badge (Top Right)
          if (isEquipped)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'EQUIPPED',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF34D399),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

          // Center Planet & Orbiting Vessel
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Revolving orbit line and companion vessel
                    RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(220, 220),
                        painter: _ShowcaseOrbitPainter(
                          clock: clock,
                          planet: planet,
                        ),
                      ),
                    ),

                    // Planet Sphere
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: planet.glowColor.withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Transform.scale(
                              scale: 1024 / 888,
                              child: Image.asset(
                                planet.assetPath,
                                fit: BoxFit.cover,
                                cacheWidth: 256,
                                cacheHeight: 256,
                                gaplessPlayback: true,
                              ),
                            ),
                            // Shading
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(-0.4, -0.4),
                                  radius: 1.2,
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Color(0x99000000),
                                  ],
                                  stops: [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Planet Info (Name + Description)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Column(
              children: [
                Text(
                  planet.name.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    color: kTextColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  planet.heroSubtitle,
                  style: GoogleFonts.inter(
                    color: kTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the showcase orbit ring and companion vessel.
class _ShowcaseOrbitPainter extends CustomPainter {
  final Animation<double> clock;
  final FleetPlanet planet;

  _ShowcaseOrbitPainter({required this.clock, required this.planet})
      : super(repaint: clock);

  final Paint _orbitPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _trailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;
  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Paint _bodyPaint = Paint()..color = kTextColor;
  final Paint _wingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  Shader? _cachedTrailShader;
  FleetPlanet? _cachedPlanet;
  static const Rect _unitTrailRect = Rect.fromLTWH(-86.0, -86.0, 172.0, 172.0);
  static const Rect _vesselBodyRect = Rect.fromLTWH(-4.0, -6.0, 8.0, 12.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 86.0;

    // Draw orbit path circle
    _orbitPaint.color = planet.primaryColor.withValues(alpha: 0.35);
    canvas.drawCircle(center, radius, _orbitPaint);

    // Compute companion position
    final angle = clock.value * 2 * pi;
    final vesselPos = center + Offset(cos(angle), sin(angle)) * radius;

    // Cached plasma thruster trail shader rotated via canvas transform (zero per-frame compilation)
    if (_cachedTrailShader == null || _cachedPlanet != planet) {
      _cachedPlanet = planet;
      _cachedTrailShader = SweepGradient(
        startAngle: 0,
        endAngle: 0.7,
        colors: [
          Colors.transparent,
          planet.primaryColor.withValues(alpha: 0.8),
        ],
      ).createShader(_unitTrailRect);
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle - 0.7);
    _trailPaint.shader = _cachedTrailShader;
    canvas.drawArc(
      _unitTrailRect,
      0,
      0.7,
      false,
      _trailPaint,
    );
    canvas.restore();

    // Draw companion vessel
    canvas.save();
    canvas.translate(vesselPos.dx, vesselPos.dy);
    canvas.rotate(angle + pi / 2); // face tangential to orbit

    // Vessel glow
    _glowPaint.color = planet.companionColor.withValues(alpha: 0.5);
    canvas.drawCircle(Offset.zero, 8, _glowPaint);

    // Vessel body (sleek satellite probe shape)
    canvas.drawRect(_vesselBodyRect, _bodyPaint);
    // Solar wings
    _wingPaint.color = planet.companionColor;
    canvas.drawLine(const Offset(-8, -2), const Offset(-4, -2), _wingPaint);
    canvas.drawLine(const Offset(4, -2), const Offset(8, -2), _wingPaint);
    canvas.drawLine(const Offset(-8, 2), const Offset(-4, 2), _wingPaint);
    canvas.drawLine(const Offset(4, 2), const Offset(8, 2), _wingPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShowcaseOrbitPainter oldDelegate) =>
      oldDelegate.planet != planet;
}

/// Item card in the worlds list.
class _WorldListCard extends StatelessWidget {
  final FleetPlanet planet;
  final bool isUnlocked;
  final bool isEquipped;
  final bool isSelected;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onEquip;

  const _WorldListCard({
    super.key,
    required this.planet,
    required this.isUnlocked,
    required this.isEquipped,
    required this.isSelected,
    required this.strings,
    required this.onTap,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? kSurfaceColor.withValues(alpha: 0.75)
              : kSurfaceColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? planet.primaryColor.withValues(alpha: 0.8)
                : kBorderSoft.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: planet.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Planet thumbnail with bounded cache dimensions
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: planet.glowColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: Transform.scale(
                  scale: 1024 / 888,
                  child: Image.asset(
                    planet.assetPath,
                    fit: BoxFit.cover,
                    cacheWidth: 120,
                    cacheHeight: 120,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Planet details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planet.name,
                    style: GoogleFonts.orbitron(
                      color: kTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    planet.subtitle,
                    style: GoogleFonts.inter(
                      color: kTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Status indicator / button
            if (isEquipped)
              Text(
                strings.equipped,
                style: GoogleFonts.inter(
                  color: const Color(0xFF34D399),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (isUnlocked)
              GestureDetector(
                onTap: onEquip,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: kAccentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kAccentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    strings.equip,
                    style: GoogleFonts.inter(
                      color: kAccentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kPillSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kBorderSoft.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FigmaIcon.lock(size: 13, color: kTextMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${planet.price}',
                      style: GoogleFonts.inter(
                        color: kTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Big bottom action button (Unlock / Equip / Equipped).
class _MarketActionButton extends StatelessWidget {
  final FleetPlanet planet;
  final bool isUnlocked;
  final bool isEquipped;
  final int currentDust;
  final AppStrings strings;
  final VoidCallback onPressed;

  const _MarketActionButton({
    required this.planet,
    required this.isUnlocked,
    required this.isEquipped,
    required this.currentDust,
    required this.strings,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isEquipped) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kSurfaceColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF34D399).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 18),
            const SizedBox(width: 8),
            Text(
              strings.equippedFleetButton,
              style: GoogleFonts.orbitron(
                color: const Color(0xFF34D399),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (isUnlocked) {
      return GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kAccentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kAccentColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: kAccentColor.withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            strings.equipPlanetButton(planet.name.toUpperCase()),
            style: GoogleFonts.orbitron(
              color: kAccentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
    }

    // Locked state
    final canAfford = currentDust >= planet.price;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: canAfford ? kAccentColor : kSurfaceColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canAfford ? kAccentColor : kBorderSoft.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: canAfford
              ? [
                  BoxShadow(
                    color: kAccentColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              strings.unlockPlanetButton(planet.price),
              style: GoogleFonts.orbitron(
                color: canAfford ? const Color(0xFF050814) : kTextMuted,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            FigmaIcon.stardust(
              size: 16,
              color: canAfford ? const Color(0xFF050814) : kTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}
