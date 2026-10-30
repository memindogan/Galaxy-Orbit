/// Celestial Market / Hangar screen — Crafted 1:1 against Figma design specifications.
///
/// Features:
///  1. Top Bar: Circular back button at top-left, "CELESTIAL MARKET" title centered, Stardust wallet pill at top-right.
///  2. Dual Tabs:
///     - Tab 0: "Worlds & companions" (Dünyalar & uydular)
///     - Tab 1: "Customizations" (Özelleştirmeler - Skins / Trails / Shockwaves)
///  3. Hero Showcase Card (Tab 0):
///     - Sci-Fi corner brackets (top-right ┐ & bottom-left └)
///     - "FEATURED WORLD / 09" micro-badge with cyan glow dot
///     - Real-time high-fidelity selected planet imagery with spherical terminator shading and atmospheric glow
///     - Inclined elliptical neon orbit ring with revolving companion vessel and ion thruster flame
///     - Dynamic telemetry tag (e.g. "CORONA ACTIVITY +98.6%"), world name, category pill, and companion info
///  4. Horizontal planet catalog carousel (12 celestial worlds with live statuses):
///     - EQUIPPED (cyan badge)
///     - OWNED / Equip (interactive equip action)
///     - SELECTED (1.5px glowing cyan active border)
///     - LOCKED (top-right lock badge + golden Stardust price)
///  5. Customizations Showcase & Catalog (Tab 1):
///     - Live interactive orbital particle & shockwave preview
///     - 4 Cosmic Customization bundles (Classic Neon, Stardust Sparkle, Dual Ion, Cyber Glitch)
///     - High-glow Unlock / Equip action button
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/cosmic_customization.dart';
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
  late String _selectedCustomizationId;
  int _selectedTab = 0; // 0 = Worlds & companions, 1 = Customizations
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
    _selectedCustomizationId = gameState.equippedCustomizationId;
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

  void _onSelectCustomization(String id) {
    if (context.read<SettingsProvider>().vibrationEnabled) {
      HapticService.selectionClick();
    }
    setState(() {
      _selectedCustomizationId = id;
    });
  }

  void _onCustomizationActionPressed() {
    final gameState = context.read<GameStateProvider>();
    final settings = context.read<SettingsProvider>();
    final item = CustomizationCatalog.getById(_selectedCustomizationId);
    final isUnlocked = gameState.isCustomizationUnlocked(item.id);
    final isEquipped = gameState.isCustomizationEquipped(item.id);
    final itemName = item.name(settings.isTurkish);

    if (isEquipped) return;

    if (isUnlocked) {
      gameState.equipCustomization(item.id);
      if (settings.vibrationEnabled) {
        HapticService.mediumImpact();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF101B2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: item.primaryColor.withValues(alpha: 0.4)),
          ),
          content: Text(
            settings.strings.equippedCustomizationSnackbar(itemName),
            style: GoogleFonts.inter(color: const Color(0xFFF0F7FF), fontSize: 13),
          ),
        ),
      );
      return;
    }

    if (gameState.totalStarDust < item.price) {
      if (settings.vibrationEnabled) {
        HapticService.heavyImpact();
      }
      final needed = item.price - gameState.totalStarDust;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2A1520),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFF5252), width: 1),
          ),
          content: Text(
            settings.strings.needMoreDustSnackbar(itemName, needed),
            style: GoogleFonts.inter(color: const Color(0xFFF0F7FF), fontSize: 13),
          ),
        ),
      );
      return;
    }

    final success = gameState.unlockCustomization(item.id);
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
            side: BorderSide(color: item.primaryColor, width: 1.5),
          ),
          content: Text(
            settings.strings.unlockedCustomizationSnackbar(itemName),
            style: GoogleFonts.orbitron(
              color: item.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
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

    final selectedCustom = CustomizationCatalog.getById(_selectedCustomizationId);
    final isCustomUnlocked = gameState.isCustomizationUnlocked(selectedCustom.id);
    final isCustomEquipped = gameState.isCustomizationEquipped(selectedCustom.id);

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
                      ),
                    ],
                  ),
                ),

                // ── Dual Tab Selector Pills (Worlds & Companions vs Customizations) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
                  child: Center(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xD90C1626),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: const Color(0x268CEFFF),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tab 0: Worlds & companions
                          GestureDetector(
                            key: const Key('hangar_worlds_tab'),
                            onTap: () {
                              if (_selectedTab != 0) {
                                if (settings.vibrationEnabled) {
                                  HapticService.selectionClick();
                                }
                                setState(() => _selectedTab = 0);
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0
                                    ? const Color(0x228CEFFF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: _selectedTab == 0
                                    ? Border.all(
                                        color: const Color(0xFF8CEFFF),
                                        width: 1.0,
                                      )
                                    : null,
                                boxShadow: _selectedTab == 0
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x408CEFFF),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FigmaIcon.orbit(
                                    size: 13,
                                    color: _selectedTab == 0
                                        ? const Color(0xFF8CEFFF)
                                        : const Color(0xFF7F91AB),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    settings.strings.worldsAndCompanions,
                                    style: GoogleFonts.inter(
                                      color: _selectedTab == 0
                                          ? const Color(0xFF8CEFFF)
                                          : const Color(0xFF7F91AB),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Tab 1: Customizations (Özelleştirmeler)
                          GestureDetector(
                            key: const Key('hangar_customizations_tab'),
                            onTap: () {
                              if (_selectedTab != 1) {
                                if (settings.vibrationEnabled) {
                                  HapticService.selectionClick();
                                }
                                setState(() => _selectedTab = 1);
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1
                                    ? const Color(0x228CEFFF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: _selectedTab == 1
                                    ? Border.all(
                                        color: const Color(0xFF8CEFFF),
                                        width: 1.0,
                                      )
                                    : null,
                                boxShadow: _selectedTab == 1
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x408CEFFF),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 13,
                                    color: _selectedTab == 1
                                        ? const Color(0xFF8CEFFF)
                                        : const Color(0xFF7F91AB),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    settings.strings.customizationsTab,
                                    style: GoogleFonts.inter(
                                      color: _selectedTab == 1
                                          ? const Color(0xFF8CEFFF)
                                          : const Color(0xFF7F91AB),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
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

                const SizedBox(height: 2),

                // ── Centered Main Content ──
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: _selectedTab == 0
                          ? SingleChildScrollView(
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
                                  const SizedBox(height: 14),

                                  // 2. Section Header: Worlds & Companions / Subtitle
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
                                              settings.strings.yourCosmicFleet,
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
                                              settings.strings.unlockedWorlds(unlockedCount, FleetCatalog.worlds.length),
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
                                    ],
                                  ),
                                  const SizedBox(height: 10),

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
                                  const SizedBox(height: 14),

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
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                    children: [
                                      // 1. Customization Showcase Preview Card
                                      _CustomizationShowcaseCard(
                                        customization: selectedCustom,
                                        planet: gameState.equippedPlanet,
                                        clock: _clock,
                                        isTurkish: settings.isTurkish,
                                        isEquipped: isCustomEquipped,
                                      ),
                                      const SizedBox(height: 14),

                                      // 2. Customizations List
                                      ...CustomizationCatalog.items.map((item) {
                                        final isItemUnlocked = gameState.isCustomizationUnlocked(item.id);
                                        final isItemEquipped = gameState.isCustomizationEquipped(item.id);
                                        final isItemSelected = item.id == _selectedCustomizationId;

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: _CustomizationListCard(
                                            key: ValueKey('custom_'),
                                            customization: item,
                                            isUnlocked: isItemUnlocked,
                                            isEquipped: isItemEquipped,
                                            isSelected: isItemSelected,
                                            isTurkish: settings.isTurkish,
                                            strings: settings.strings,
                                            onTap: () => _onSelectCustomization(item.id),
                                            onEquip: () {
                                              gameState.equipCustomization(item.id);
                                              setState(() => _selectedCustomizationId = item.id);
                                            },
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),

                                // 3. Customization Action CTA Button (Pinned Bottom)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: _CustomizationActionButton(
                                    customization: selectedCustom,
                                    isUnlocked: isCustomUnlocked,
                                    isEquipped: isCustomEquipped,
                                    isTurkish: settings.isTurkish,
                                    currentDust: totalDust,
                                    strings: settings.strings,
                                    onPressed: _onCustomizationActionPressed,
                                  ),
                                ),
                              ],
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
      height: 316,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xD90C1626),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 16,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 1.0,
          color: const Color(0x358CEFFF),
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

          // 2. LAYER 1: Back Orbit Ring & Companion (Behind Planet)
          Positioned(
            left: 0,
            top: 6,
            width: 342,
            height: 190,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HangarOrbitPainter(
                  clock,
                  planet: planet,
                  isForeground: false,
                ),
              ),
            ),
          ),

          // 3. LAYER 2: REAL Planet Body (ClipOval with authentic spherical lighting & glowing atmosphere)
          Positioned(
            left: (342 - 150) / 2,
            top: 26,
            width: 150,
            height: 150,
            child: _FeaturedPlanetBody(planet: planet),
          ),

          // 4. LAYER 3: Front Orbit Ring & Companion (In Front of Planet)
          Positioned(
            left: 0,
            top: 6,
            width: 342,
            height: 190,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HangarOrbitPainter(
                  clock,
                  planet: planet,
                  isForeground: true,
                ),
              ),
            ),
          ),

          // 5. Bottom Gradient Fade for Typography Readability
          Positioned(
            left: 0,
            top: 148,
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

          // 6. Top Left Micro-Badge: "FEATURED WORLD / 09"
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

          // 7. World Details & Telemetry
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _telemetryTag(planet),
                  style: GoogleFonts.inter(
                    color: planet.primaryColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      planet.name.toUpperCase(),
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFFF0F7FF),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: planet.primaryColor.withValues(alpha: 0.14),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 0.8,
                            color: planet.primaryColor.withValues(alpha: 0.40),
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
/// CustomPainter: Inclined Orbit Ring & Companion Vessel with 3D Depth Layering
class _HangarOrbitPainter extends CustomPainter {
  final Animation<double> clock;
  final FleetPlanet planet;
  final bool isForeground;

  _HangarOrbitPainter(
    this.clock, {
    required this.planet,
    required this.isForeground,
  }) : super(repaint: clock);

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
    final auraRect = Rect.fromCenter(
      center: Offset.zero,
      width: (orbitA + 6) * 2,
      height: (orbitB + 3) * 2,
    );

    final pColor = planet.primaryColor;
    final gColor = planet.glowColor;

    // Orbit Ring Paint customized to the planet's celestial energy
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = pColor.withValues(alpha: isForeground ? 0.65 : 0.40);

    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = gColor.withValues(alpha: isForeground ? 0.30 : 0.18);

    if (isForeground) {
      // ── Front Layer (In front of Planet): draw 0 to pi radians ──────
      canvas.drawArc(orbitRect, 0, pi, false, ringPaint);
      canvas.drawArc(auraRect, 0, pi, false, auraPaint);
    } else {
      // ── Back Layer (Behind Planet): draw pi to 2*pi radians ──────────
      // Note: The part directly behind the planet disk is naturally
      // occluded by the opaque planet body in Layer 2. The left and right
      // flanks extend seamlessly into open space.
      canvas.drawArc(orbitRect, pi, pi, false, ringPaint);
      canvas.drawArc(auraRect, pi, pi, false, auraPaint);
    }

    // Companion Orbit calculation:
    final shipAngle = t * 1.5;
    final shipX = orbitA * cos(shipAngle);
    final shipY = orbitB * sin(shipAngle);

    final isShipForeground = shipY >= 0;

    // Only paint the companion in its appropriate layer (foreground vs background)
    if (isShipForeground == isForeground) {
      _drawCompanion(canvas, shipX, shipY, shipAngle, planet);
    }

    canvas.restore();
  }

  void _drawCompanion(
    Canvas canvas,
    double shipX,
    double shipY,
    double shipAngle,
    FleetPlanet planet,
  ) {
    final isMoon = planet.companionType.toLowerCase().contains('moon');
    final pColor = planet.primaryColor;
    final cColor = planet.companionColor;
    final gColor = planet.glowColor;

    // Trailing comet/ion dust particles along the orbit path
    for (int i = 1; i <= 6; i++) {
      final trailAngle = shipAngle - i * 0.055;
      final tx = 120.0 * cos(trailAngle);
      final ty = 42.0 * sin(trailAngle);
      final alpha = (1.0 - i / 7.0) * 0.50;
      final trailPaint = Paint()
        ..color = Color.lerp(pColor, cColor, 0.4)!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(tx, ty), 3.2 - i * 0.4, trailPaint);
    }

    if (isMoon) {
      // ── Natural Moon Archetype (e.g. Luna for Terra) ─────────────────
      // Lunar Aura Glow
      final moonAuraPaint = Paint()
        ..color = cColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(shipX, shipY), 8.5, moonAuraPaint);

      // Spherical Moon Body with terminator shading
      final moonPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.0,
          colors: [
            cColor,
            Color.lerp(cColor, const Color(0xFF1E293B), 0.7)!,
            const Color(0xFF0F172A),
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(shipX, shipY), radius: 6.5));
      canvas.drawCircle(Offset(shipX, shipY), 6.5, moonPaint);

      // Subtle lunar crater marks
      final craterPaint = Paint()..color = const Color(0x35000000);
      canvas.drawCircle(Offset(shipX - 1.8, shipY - 1.2), 1.2, craterPaint);
      canvas.drawCircle(Offset(shipX + 2.0, shipY + 1.4), 1.0, craterPaint);
      canvas.drawCircle(Offset(shipX + 0.2, shipY + 2.2), 0.7, craterPaint);
    } else {
      // ── Sci-Fi Companion Vessel / Satellite Archetype ─────────────────
      // Determine movement direction vector along orbit tangent
      final tangentX = -120.0 * sin(shipAngle);
      final tangentY = 42.0 * cos(shipAngle);
      final tangentAngle = atan2(tangentY, tangentX);

      // Thruster Flame Plume behind vessel
      final thrusterDir = Offset(-cos(tangentAngle), -sin(tangentAngle));
      final thrusterPos = Offset(shipX, shipY) + thrusterDir * 6.5;

      final flamePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            gColor,
            pColor.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: thrusterPos, radius: 11));
      canvas.drawCircle(thrusterPos, 10, flamePaint);

      canvas.save();
      canvas.translate(shipX, shipY);
      canvas.rotate(tangentAngle);

      final type = planet.companionType.toLowerCase();

      // Wings / Solar Arrays / Collector Fins
      if (type.contains('skimmer') || type.contains('recon') || type.contains('probe')) {
        // Swept delta wings
        final wingPaint = Paint()
          ..color = Color.lerp(cColor, const Color(0xFF0C1626), 0.3)!
          ..style = PaintingStyle.fill;
        final wingPath = Path()
          ..moveTo(6, 0)
          ..lineTo(-5, -6)
          ..lineTo(-3, 0)
          ..lineTo(-5, 6)
          ..close();
        canvas.drawPath(wingPath, wingPaint);

        final wingTrim = Paint()
          ..color = pColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawPath(wingPath, wingTrim);
      } else {
        // Solar panels / Collector arrays
        final panelPaint = Paint()..color = pColor.withValues(alpha: 0.85);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-7, -1.2, 14, 2.4),
            const Radius.circular(1),
          ),
          panelPaint,
        );
      }

      // Main Hull Body with metallic directional shading
      final hullPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            const Color(0xFFFFFFFF),
            cColor,
            Color.lerp(cColor, const Color(0xFF0F172A), 0.65)!,
          ],
        ).createShader(const Rect.fromLTWH(-4.5, -4.5, 9, 9));
      canvas.drawCircle(Offset.zero, 4.5, hullPaint);

      // Cockpit / Energy Sensor Core (pulsing with planet color)
      final corePaint = Paint()
        ..color = pColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(const Offset(1.2, 0), 1.8, corePaint);

      final coreCenter = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawCircle(const Offset(1.2, 0), 0.9, coreCenter);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HangarOrbitPainter oldDelegate) => true;
}

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
        decoration: BoxDecoration(
          color: const Color(0xD90C1626),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x358CEFFF),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: isSelected ? 1.5 : 1.0,
            color: isSelected ? const Color(0xFF8CEFFF) : const Color(0x268CEFFF),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Planet Thumbnail Image (100x84)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: SizedBox(
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

// ═════════════════════════════════════════════════════════════════════════════
// Sub-components: Customization Showcase & List (Tab 1)
// ═════════════════════════════════════════════════════════════════════════════

class _CustomizationShowcaseCard extends StatelessWidget {
  final CosmicCustomization customization;
  final FleetPlanet planet;
  final Animation<double> clock;
  final bool isTurkish;
  final bool isEquipped;

  const _CustomizationShowcaseCard({
    required this.customization,
    required this.planet,
    required this.clock,
    required this.isTurkish,
    required this.isEquipped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 342,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xD90C1626),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: customization.primaryColor.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: customization.primaryColor.withValues(alpha: 0.14),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Background subtle canvas
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: CustomPaint(
                painter: _CustomizationPreviewPainter(
                  clock: clock,
                  customization: customization,
                ),
              ),
            ),
          ),

          // Central planet thumbnail for scale context
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: planet.glowColor.withValues(alpha: 0.4),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  planet.assetPath,
                  fit: BoxFit.cover,
                  cacheWidth: 120,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),

          // Top badges
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: customization.primaryColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: customization.primaryColor.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                customization.tag(isTurkish),
                style: GoogleFonts.orbitron(
                  color: customization.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          if (isEquipped)
            Positioned(
              right: 18,
              top: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF34D399),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: Color(0xFF34D399)),
                    const SizedBox(width: 4),
                    Text(
                      'ACTIVE',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Info
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customization.name(isTurkish),
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customization.subtitle(isTurkish),
                  style: GoogleFonts.inter(
                    color: customization.secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  customization.description(isTurkish),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9BACCA),
                    fontSize: 11,
                    height: 1.35,
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

class _CustomizationPreviewPainter extends CustomPainter {
  final Animation<double> clock;
  final CosmicCustomization customization;

  _CustomizationPreviewPainter({
    required this.clock,
    required this.customization,
  }) : super(repaint: clock);

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 78.0;
    final primary = customization.primaryColor;
    final secondary = customization.secondaryColor;

    // Orbit ring
    _stroke.strokeWidth = 1.0;
    _stroke.color = primary.withValues(alpha: 0.28);
    canvas.drawCircle(center, radius, _stroke);

    final angle = clock.value * 4 * pi;
    final vesselPos = center + Offset(cos(angle), sin(angle)) * radius;

    // Periodic launch shockwave every 2.5 seconds at top of orbit
    final waveCycle = (clock.value * 12) % 1.0;
    final waveRadius = waveCycle * 95.0;
    final waveAlpha = (1.0 - waveCycle).clamp(0.0, 1.0);

    if (waveRadius > 4) {
      switch (customization.style) {
        case CustomizationStyle.classic:
          _stroke.strokeWidth = 2.0;
          _stroke.color = primary.withValues(alpha: waveAlpha * 0.7);
          canvas.drawCircle(center, waveRadius, _stroke);
          break;

        case CustomizationStyle.sparkle:
          _stroke.strokeWidth = 1.8;
          _stroke.color = primary.withValues(alpha: waveAlpha * 0.75);
          canvas.drawCircle(center, waveRadius, _stroke);
          // 4 corner sparkles
          for (int s = 0; s < 4; s++) {
            final sparkA = s * pi / 2 + waveCycle * 2;
            final sparkOffset = center + Offset(cos(sparkA), sin(sparkA)) * waveRadius;
            _fill.color = secondary.withValues(alpha: waveAlpha * 0.9);
            canvas.drawCircle(sparkOffset, 2.5 * waveAlpha, _fill);
          }
          break;

        case CustomizationStyle.dualIon:
          _stroke.strokeWidth = 1.6;
          _stroke.color = primary.withValues(alpha: waveAlpha * 0.8);
          canvas.drawCircle(center, waveRadius, _stroke);
          _stroke.strokeWidth = 1.0;
          _stroke.color = secondary.withValues(alpha: waveAlpha * 0.5);
          canvas.drawCircle(center, waveRadius * 0.82, _stroke);
          break;

        case CustomizationStyle.cyberGlitch:
          _stroke.strokeWidth = 1.8;
          _stroke.color = primary.withValues(alpha: waveAlpha * 0.85);
          _path.reset();
          for (int i = 0; i < 8; i++) {
            final a = (i * pi / 4) + (waveCycle * 0.5);
            final p = center + Offset(cos(a), sin(a)) * waveRadius;
            if (i == 0) {
              _path.moveTo(p.dx, p.dy);
            } else {
              _path.lineTo(p.dx, p.dy);
            }
          }
          _path.close();
          canvas.drawPath(_path, _stroke);
          break;
      }
    }

    // Orbiting Vessel Trail
    const trailCount = 14;
    for (int i = 0; i < trailCount; i++) {
      final trailFrac = i / trailCount;
      final trailAngle = angle - (i * 0.08);
      final trailPos = center + Offset(cos(trailAngle), sin(trailAngle)) * radius;
      final alpha = (1.0 - trailFrac) * 0.8;

      switch (customization.style) {
        case CustomizationStyle.classic:
          _fill.color = primary.withValues(alpha: alpha);
          canvas.drawCircle(trailPos, 3.5 * (1.0 - trailFrac * 0.6), _fill);
          break;

        case CustomizationStyle.sparkle:
          _fill.color = (i % 2 == 0 ? primary : secondary).withValues(alpha: alpha);
          if (i % 3 == 0) {
            // Star diamond
            final d = 3.2 * (1.0 - trailFrac * 0.5);
            _path.reset();
            _path.moveTo(trailPos.dx, trailPos.dy - d);
            _path.lineTo(trailPos.dx + d, trailPos.dy);
            _path.lineTo(trailPos.dx, trailPos.dy + d);
            _path.lineTo(trailPos.dx - d, trailPos.dy);
            _path.close();
            canvas.drawPath(_path, _fill);
          } else {
            canvas.drawCircle(trailPos, 2.4 * (1.0 - trailFrac), _fill);
          }
          break;

        case CustomizationStyle.dualIon:
          final perp = Offset(-sin(trailAngle), cos(trailAngle));
          final p1 = trailPos + perp * 3.5;
          final p2 = trailPos - perp * 3.5;
          _fill.color = primary.withValues(alpha: alpha);
          canvas.drawCircle(p1, 2.2 * (1.0 - trailFrac * 0.5), _fill);
          _fill.color = secondary.withValues(alpha: alpha);
          canvas.drawCircle(p2, 2.2 * (1.0 - trailFrac * 0.5), _fill);
          break;

        case CustomizationStyle.cyberGlitch:
          _fill.color = (i % 2 == 0 ? primary : secondary).withValues(alpha: alpha);
          final sqSize = 4.2 * (1.0 - trailFrac * 0.5);
          canvas.drawRect(
            Rect.fromCenter(center: trailPos, width: sqSize, height: sqSize),
            _fill,
          );
          break;
      }
    }

    // Vessel Body
    _fill.color = Colors.white;
    canvas.drawCircle(vesselPos, 4.5, _fill);
    _stroke.strokeWidth = 1.5;
    _stroke.color = primary;
    canvas.drawCircle(vesselPos, 4.5, _stroke);
  }

  @override
  bool shouldRepaint(covariant _CustomizationPreviewPainter oldDelegate) => true;
}

class _CustomizationListCard extends StatelessWidget {
  final CosmicCustomization customization;
  final bool isUnlocked;
  final bool isEquipped;
  final bool isSelected;
  final bool isTurkish;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onEquip;

  const _CustomizationListCard({
    super.key,
    required this.customization,
    required this.isUnlocked,
    required this.isEquipped,
    required this.isSelected,
    required this.isTurkish,
    required this.strings,
    required this.onTap,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final IconData iconData = switch (customization.style) {
      CustomizationStyle.classic => Icons.auto_awesome_motion_rounded,
      CustomizationStyle.sparkle => Icons.auto_awesome_rounded,
      CustomizationStyle.dualIon => Icons.bolt_rounded,
      CustomizationStyle.cyberGlitch => Icons.grid_view_rounded,
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? customization.primaryColor.withValues(alpha: 0.12)
              : const Color(0xD90C1626),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? customization.primaryColor
                : const Color(0x268CEFFF),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: customization.primaryColor.withValues(alpha: 0.20),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon glyph
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: customization.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: customization.primaryColor.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(iconData, color: customization.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Name + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          customization.name(isTurkish),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: customization.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          customization.tag(isTurkish),
                          style: GoogleFonts.inter(
                            color: customization.primaryColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customization.subtitle(isTurkish),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7F91AB),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing action / badge
            if (isEquipped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34D399), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: Color(0xFF34D399)),
                    const SizedBox(width: 4),
                    Text(
                      strings.equippedBadge,
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (isUnlocked)
              GestureDetector(
                onTap: onEquip,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: customization.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: customization.primaryColor, width: 1.2),
                  ),
                  child: Text(
                    strings.equip,
                    style: GoogleFonts.orbitron(
                      color: customization.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x60101B2C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x208CEFFF),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FigmaIcon.lock(size: 13, color: const Color(0xFF7F91AB)),
                    const SizedBox(width: 6),
                    Text(
                      '${customization.price}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

class _CustomizationActionButton extends StatelessWidget {
  final CosmicCustomization customization;
  final bool isUnlocked;
  final bool isEquipped;
  final bool isTurkish;
  final int currentDust;
  final AppStrings strings;
  final VoidCallback onPressed;

  const _CustomizationActionButton({
    required this.customization,
    required this.isUnlocked,
    required this.isEquipped,
    required this.isTurkish,
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
          color: const Color(0x1A34D399),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF34D399),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 18),
            const SizedBox(width: 8),
            Text(
              strings.equippedCustomizationButton,
              style: GoogleFonts.orbitron(
                color: const Color(0xFF34D399),
                fontSize: 13,
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
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: customization.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: customization.primaryColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: customization.primaryColor.withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            strings.equipPlanetButton(customization.name(isTurkish).toUpperCase()),
            style: GoogleFonts.orbitron(
              color: customization.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
    }

    final canAfford = currentDust >= customization.price;
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: canAfford ? customization.primaryColor : const Color(0x60101B2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canAfford ? customization.primaryColor : const Color(0x308CEFFF),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              strings.unlockPlanetButton(customization.price),
              style: GoogleFonts.orbitron(
                color: canAfford ? const Color(0xFF050814) : const Color(0xFF7F91AB),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            FigmaIcon.stardust(
              size: 16,
              color: canAfford ? const Color(0xFF050814) : const Color(0xFF7F91AB),
            ),
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
