/// Celestial Market / Hangar screen — Crafted 1:1 against Figma design specifications.
///
/// Features:
///  1. Top Bar: Circular back button at top-left, "CELESTIAL MARKET" title centered, Stardust wallet pill at top-right.
///  2. Hero Showcase Card (342x340):
///     - Sci-Fi corner brackets (top-right ┐ & bottom-left └)
///     - "FEATURED WORLD / 09" micro-badge with cyan glow dot
///     - Real-time high-fidelity selected planet imagery with spherical terminator shading and atmospheric glow
///     - Inclined elliptical neon orbit ring with revolving companion vessel and ion thruster flame
///     - Dynamic telemetry tag (e.g. "CORONA ACTIVITY +98.6%"), world name, category pill, and companion info
///  3. Worlds & Companions header with fleet unlocked badge ("4 / 12 UNLOCKED")
///  4. Horizontal planet catalog carousel (12 celestial worlds with live statuses):
///     - EQUIPPED (cyan badge)
///     - OWNED / Equip (interactive equip action)
///     - SELECTED (1.5px glowing cyan active border)
///     - LOCKED (top-right lock badge + golden Stardust price)
///  5. Carousel indicator pills (active 22x3 cyan pill, inactive 5x3 pills)
///  6. Bundle info card ("Unlock a world. Bring its companion.")
///  7. High-glow Bottom Action CTA Button (Unlock with Stardust / Equip Fleet / Equipped Fleet)
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/fleet_planet.dart';
import '../providers/game_state_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/figma_icons.dart';
import '../services/haptic_service.dart';

class HangarScreen extends StatefulWidget {
  const HangarScreen({super.key});

  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends State<HangarScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  late String _selectedPlanetId;
  final ScrollController _carouselController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

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
    _carouselController.dispose();
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
          backgroundColor: const Color(0xFF101B2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF8CEFFF), width: 1.0),
          ),
          content: Text(
            settings.strings.equippedSnackbar(planet.name, planet.companionName),
            style: GoogleFonts.inter(color: const Color(0xFFF0F7FF), fontSize: 13),
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
            style: GoogleFonts.inter(color: const Color(0xFFF0F7FF), fontSize: 13),
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
          backgroundColor: const Color(0xFF101B2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF8CEFFF), width: 1.5),
          ),
          content: Text(
            settings.strings.unlockedSnackbar(planet.name, planet.companionName),
            style: GoogleFonts.orbitron(
              color: const Color(0xFF8CEFFF),
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
    final selectedIndex = FleetCatalog.worlds.indexWhere((w) => w.id == selectedPlanet.id);

    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      body: Stack(
        children: [
          // 1. Galaxy Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.45,
              child: Image.asset(
                'assets/images/menu_bg.jpg',
                fit: BoxFit.cover,
                cacheWidth: 780,
                gaplessPlayback: true,
              ),
            ),
          ),

          // 2. Subtle Darkening Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF050814).withValues(alpha: 0.35),
                    const Color(0xFF050814).withValues(alpha: 0.70),
                    const Color(0xFF050814).withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 3. Responsive Edge-to-Edge UI
          SafeArea(
            child: Column(
              children: [
                // ── Top Bar: Back Button, Centered Title, Wallet Pill ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back Button on far left
                      GestureDetector(
                        key: const Key('hangar_back_button'),
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
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
                                color: Color(0x30000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: FigmaIcon.arrowBack(size: 19, color: const Color(0xFFF0F7FF)),
                        ),
                      ),

                      // Title in the center
                      Text(
                        'CELESTIAL MARKET',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFF0F7FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),

                      // Stardust Wallet Pill on far right
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
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
                              color: Color(0x30000000),
                              blurRadius: 8,
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
                              _formatThousands(totalDust),
                              style: GoogleFonts.orbitron(
                                color: const Color(0xFFF0F7FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Centered Main Content ──
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. Featured World Card (Real Planet Image + Companion Orbit)
                            _FeaturedWorldCard(
                              planet: selectedPlanet,
                              index: selectedIndex >= 0 ? selectedIndex + 1 : 1,
                              clock: _clock,
                            ),
                            const SizedBox(height: 16),

                            // 2. Section Header: Worlds & Companions / Fleet unlocked pill
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        settings.strings.worldsAndCompanions,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFF0F7FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        settings.strings.yourCosmicFleet,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF7F91AB),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF101B2C),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: const Color(0x268CEFFF),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$unlockedCount / ${FleetCatalog.worlds.length} UNLOCKED',
                                    style: GoogleFonts.orbitron(
                                      color: const Color(0xFF8CEFFF),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 3. Carousel of Planet Cards (12 items)
                            SizedBox(
                              height: 130,
                              child: ListView.separated(
                                controller: _carouselController,
                                scrollDirection: Axis.horizontal,
                                itemCount: FleetCatalog.worlds.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final world = FleetCatalog.worlds[index];
                                  final isItemUnlocked = gameState.isUnlocked(world.id);
                                  final isItemEquipped = gameState.isEquipped(world.id);
                                  final isItemSelected = world.id == _selectedPlanetId;

                                  return _PlanetCatalogCard(
                                    world: world,
                                    isUnlocked: isItemUnlocked,
                                    isEquipped: isItemEquipped,
                                    isSelected: isItemSelected,
                                    strings: settings.strings,
                                    onTap: () => _onSelectPlanet(world.id),
                                    onEquip: () {
                                      gameState.equipPlanet(world.id);
                                      setState(() => _selectedPlanetId = world.id);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 4. Carousel Indicator Dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(4, (i) {
                                final isActive = (selectedIndex ~/ 3) == i;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                  width: isActive ? 22 : 5,
                                  height: 3,
                                  decoration: ShapeDecoration(
                                    color: isActive
                                        ? const Color(0xFF8CEFFF)
                                        : const Color(0xFF24364E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),

                            // 5. Active Fleet Bundle Capsule
                            _BundleInfoCapsule(
                              planet: selectedPlanet,
                              isUnlocked: isUnlocked,
                              strings: settings.strings,
                            ),
                            const SizedBox(height: 16),

                            // 6. Primary Action CTA Button (Unlock / Equip / Equipped)
                            _ActionButton(
                              planet: selectedPlanet,
                              isUnlocked: isUnlocked,
                              isEquipped: isEquipped,
                              totalDust: totalDust,
                              strings: settings.strings,
                              onPressed: _onActionButtonPressed,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
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

// ═════════════════════════════════════════════════════════════════════════════
// Sub-components: Featured World Card & 3D Celestial Showcase
// ═════════════════════════════════════════════════════════════════════════════

class _FeaturedWorldCard extends StatelessWidget {
  final FleetPlanet planet;
  final int index;
  final Animation<double> clock;

  const _FeaturedWorldCard({
    required this.planet,
    required this.index,
    required this.clock,
  });

  String _telemetryTag(FleetPlanet p) {
    return switch (p.id) {
      'nova' => 'CORONA ACTIVITY +98.6%',
      'ember' => 'SURFACE TEMP 840 K',
      'aether' => 'ION FLUX 14.2 keV',
      'chronos' => 'GRAVITATIONAL DILATION 3.4x',
      'titan' => 'ATMOSPHERIC PRESSURE 1.5 ATM',
      'solaris' => 'SOLAR RADIATION 12.8 kW/m²',
      'gliese' => 'TIDALLY LOCKED • STABLE',
      'nebula9' => 'PLASMA IONIZATION 87%',
      _ => 'BIOSPHERE STABILITY 99.8%',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 342,
      height: 340,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0xD90C1626),
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x268CEFFF),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Stack(
        children: [
          // 1. Deep Space Backdrop Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/images/menu_bg.jpg',
                fit: BoxFit.cover,
                cacheWidth: 684,
                gaplessPlayback: true,
              ),
            ),
          ),

          // 2. REAL Planet Body (ClipOval with authentic spherical lighting & glowing atmosphere)
          Positioned(
            left: (342 - 150) / 2,
            top: 40,
            width: 150,
            height: 150,
            child: _FeaturedPlanetBody(planet: planet),
          ),

          // 3. Inclined Orbit Ring + Revolving Companion Vessel
          Positioned(
            left: 0,
            top: 20,
            width: 342,
            height: 190,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HangarOrbitPainter(clock, planet: planet),
              ),
            ),
          ),

          // 4. Bottom Gradient Fade for Typography Readability
          Positioned(
            left: 0,
            top: 170,
            width: 342,
            height: 170,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00050814),
                    Color(0xF5050814),
                  ],
                ),
              ),
            ),
          ),

          // 5. Sci-Fi Corner Bracket: Top Right (┐)
          Positioned(
            right: 16,
            top: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 16, height: 1, color: const Color(0x808CEFFF)),
                Container(width: 1, height: 10, color: const Color(0x808CEFFF)),
              ],
            ),
          ),

          // 6. Sci-Fi Corner Bracket: Bottom Left (└)
          Positioned(
            left: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 1, height: 8, color: const Color(0x508CEFFF)),
                Container(width: 12, height: 1, color: const Color(0x508CEFFF)),
              ],
            ),
          ),

          // 7. Top Left Micro-Badge: "FEATURED WORLD / 09"
          Positioned(
            left: 16,
            top: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF8CEFFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    shadows: const [
                      BoxShadow(
                        color: Color(0x558CEFFF),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'FEATURED WORLD / ${index.toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB8D9ED),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // 8. Telemetry Tag
          Positioned(
            left: 18,
            top: 234,
            child: Text(
              _telemetryTag(planet),
              style: GoogleFonts.inter(
                color: planet.glowColor,
                fontSize: 7.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // 9. Planet Name & Category Badge & Companion Info
          Positioned(
            left: 18,
            top: 250,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      planet.name.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFFF0F7FF),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: ShapeDecoration(
                        color: planet.glowColor.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            color: planet.glowColor.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: Text(
                        planet.category,
                        style: GoogleFonts.inter(
                          color: planet.glowColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    FigmaIcon.orbit(size: 13, color: const Color(0xFFB8D9ED)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Companion: ${planet.companionName} (${planet.companionType})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFB8D9ED),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
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

/// Featured Planet Body showing the REAL selected planet image
class _FeaturedPlanetBody extends StatelessWidget {
  final FleetPlanet planet;

  const _FeaturedPlanetBody({required this.planet});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: planet.glowColor.withValues(alpha: 0.50),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              planet.assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              cacheWidth: 512,
              cacheHeight: 512,
              gaplessPlayback: true,
            ),
            // Spherical terminator lighting shading: lit from upper-left
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4, -0.45),
                  radius: 1.25,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Atmospheric glowing rim
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: planet.primaryColor.withValues(alpha: 0.45),
                  width: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter: Inclined Orbit Ring & Companion Vessel
class _HangarOrbitPainter extends CustomPainter {
  final Animation<double> clock;
  final FleetPlanet planet;

  _HangarOrbitPainter(this.clock, {required this.planet}) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.58);
    final t = clock.value * 2 * pi;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.30); // ~17 deg inclination

    final orbitA = 120.0;
    final orbitB = 42.0;
    final orbitRect = Rect.fromCenter(center: Offset.zero, width: orbitA * 2, height: orbitB * 2);

    // Neon Orbit Ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8CEFFF).withValues(alpha: 0.55);
    canvas.drawOval(orbitRect, ringPaint);

    // Faint outer ring aura
    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF8CEFFF).withValues(alpha: 0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: (orbitA + 6) * 2, height: (orbitB + 3) * 2),
      auraPaint,
    );

    // Revolving companion vessel
    final shipAngle = t * 1.5;
    final shipX = orbitA * cos(shipAngle);
    final shipY = orbitB * sin(shipAngle);

    // Ion Thruster Flame Glow behind vessel
    final flamePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8CEFFF),
          const Color(0xFF38BDF8).withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(shipX + 7, shipY - 3), radius: 12));
    canvas.drawCircle(Offset(shipX + 7, shipY - 3), 12, flamePaint);

    // Vessel Body
    final vesselPaint = Paint()..color = const Color(0xFFF0F7FF);
    canvas.drawCircle(Offset(shipX, shipY), 6.0, vesselPaint);

    // Cockpit
    final cockpitPaint = Paint()..color = const Color(0xFF8CEFFF);
    canvas.drawCircle(Offset(shipX - 1.2, shipY - 1.2), 2.2, cockpitPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HangarOrbitPainter oldDelegate) => true;
}

/// Catalog Card for horizontal carousel item
class _PlanetCatalogCard extends StatelessWidget {
  final FleetPlanet world;
  final bool isUnlocked;
  final bool isEquipped;
  final bool isSelected;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onEquip;

  const _PlanetCatalogCard({
    required this.world,
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
      child: Container(
        width: 100,
        height: 130,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: const Color(0xD90C1626),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: isSelected ? 1.5 : 1.0,
              color: isSelected ? const Color(0xFF8CEFFF) : const Color(0x268CEFFF),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          shadows: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x228CEFFF),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Planet Thumbnail Image (100x84)
                SizedBox(
                  width: 100,
                  height: 84,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        world.assetPath,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: 200,
                        gaplessPlayback: true,
                      ),
                      // Radial dark shadow to enhance contrast
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB00C1626)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Name & Status Pill
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 8, right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        world.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFF0F7FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (isEquipped)
                        Container(
                          height: 17,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: ShapeDecoration(
                            color: const Color(0x168CEFFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FigmaIcon.check(size: 8, color: const Color(0xFF8CEFFF)),
                              const SizedBox(width: 4),
                              Text(
                                'EQUIPPED',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8CEFFF),
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isSelected && !isUnlocked)
                        Container(
                          height: 17,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: ShapeDecoration(
                            color: const Color(0x168CEFFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            'SELECTED',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8CEFFF),
                              fontSize: 6.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (isUnlocked)
                        GestureDetector(
                          onTap: onEquip,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 17,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: ShapeDecoration(
                              color: isSelected
                                  ? const Color(0x228CEFFF)
                                  : Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: 0.8,
                                  color: isSelected
                                      ? const Color(0xFF8CEFFF)
                                      : Colors.transparent,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                strings.equip,
                                style: GoogleFonts.inter(
                                  color: isSelected
                                      ? const Color(0xFF8CEFFF)
                                      : const Color(0xFFF0F7FF),
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 17,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: ShapeDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FigmaIcon.stardust(size: 9),
                              const SizedBox(width: 3),
                              Text(
                                _formatThousands(world.price),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFFD166),
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Lock Overlay Icon (Top Right)
            if (!isUnlocked)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: const Color(0xAA050814),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: FigmaIcon.lock(size: 11, color: const Color(0xFFB8D9ED)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Active Fleet Bundle Info Capsule
class _BundleInfoCapsule extends StatelessWidget {
  final FleetPlanet planet;
  final bool isUnlocked;
  final AppStrings strings;

  const _BundleInfoCapsule({
    required this.planet,
    required this.isUnlocked,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 342,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x600C1626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x208CEFFF),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: const Color(0x13A855F7),
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 1,
                  color: Color(0x40A855F7),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: FigmaIcon.orbit(size: 18, color: const Color(0xFFA855F7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${planet.name} + ${planet.companionName}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF0F7FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unlock a world. Bring its companion.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7F91AB),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (!isUnlocked)
            FigmaIcon.lock(size: 15, color: const Color(0xFF7F91AB))
          else
            FigmaIcon.check(size: 15, color: const Color(0xFF8CEFFF)),
        ],
      ),
    );
  }
}

/// Primary Action CTA Button (Unlock / Equip / Equipped)
class _ActionButton extends StatelessWidget {
  final FleetPlanet planet;
  final bool isUnlocked;
  final bool isEquipped;
  final int totalDust;
  final AppStrings strings;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.planet,
    required this.isUnlocked,
    required this.isEquipped,
    required this.totalDust,
    required this.strings,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isEquipped) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x1A8CEFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x408CEFFF), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FigmaIcon.check(size: 16, color: const Color(0xFF8CEFFF)),
            const SizedBox(width: 8),
            Text(
              'EQUIPPED FLEET',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF8CEFFF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    if (isUnlocked) {
      return GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3254), Color(0xFF0C243C)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF8CEFFF), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x358CEFFF),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'EQUIP FLEET',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF8CEFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              FigmaIcon.arrowRight(size: 15, color: const Color(0xFF8CEFFF)),
            ],
          ),
        ),
      );
    }

    // Locked State: Vibrant Glowing Gradient Button
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB5F7FF), Color(0xFF56D7F0)],
          ),
          shape: RoundedRectangleBorder(
            side: const BorderSide(
              width: 1,
              color: Color(0xFFC9FBFF),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x558CEFFF),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
              child: FigmaIcon.stardust(size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'UNLOCK FOR ${_formatThousands(planet.price)} STARDUST',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF071722),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            FigmaIcon.arrowRight(size: 16, color: const Color(0xFF071722)),
          ],
        ),
      ),
    );
  }
}

String _formatThousands(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
