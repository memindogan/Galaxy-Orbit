/// GameScreen — the full-screen game widget.
///
/// Owns the [AnimationController] that drives the 60 fps loop,
/// wires tap input to the engine, preloads planetary assets,
/// and composites the [GamePainter] with the Figma-aligned HUD overlay.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../engine/game_engine.dart';
import '../painters/game_painter.dart';
import '../providers/game_state_provider.dart';
import '../providers/settings_provider.dart';
import '../services/audio_service.dart';
import '../widgets/figma_icons.dart';
import 'game_modals.dart';
import 'settings_modal.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late AnimationController _ticker;
  late AnimationController _bannerController;
  late Animation<double> _bannerFade;
  late Animation<Offset> _bannerSlide;
  Timer? _bannerTimer;
  int _bannerLevel = 1;
  int _bannerBonus = 0;
  late AudioService _audio;
  double _lastTime = 0;
  bool _initialised = false;
  Map<String, ui.Image> _planetImages = {};

  @override
  void initState() {
    super.initState();
    _audio = AudioService();
    _loadPlanetImages();

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 365), // effectively infinite
    );

    _ticker.addListener(_onTick);
    _ticker.forward();

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _bannerFade = CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0.0, -0.4),
      end: Offset.zero,
    ).animate(_bannerFade);
  }

  Future<void> _loadPlanetImages() async {
    try {
      final terraData = await rootBundle.load('assets/images/planet_terra.jpg');
      final emberData = await rootBundle.load('assets/images/planet_ember.jpg');
      final aetherData = await rootBundle.load('assets/images/planet_aether.jpg');

      final terraImg = (await (await ui.instantiateImageCodec(
        terraData.buffer.asUint8List(),
        targetWidth: 256,
        targetHeight: 256,
      )).getNextFrame()).image;
      final emberImg = (await (await ui.instantiateImageCodec(
        emberData.buffer.asUint8List(),
        targetWidth: 256,
        targetHeight: 256,
      )).getNextFrame()).image;
      final aetherImg = (await (await ui.instantiateImageCodec(
        aetherData.buffer.asUint8List(),
        targetWidth: 256,
        targetHeight: 256,
      )).getNextFrame()).image;

      if (mounted) {
        setState(() {
          _planetImages = {
            'terra': terraImg,
            'ember': emberImg,
            'aether': aetherImg,
          };
        });
      } else {
        terraImg.dispose();
        emberImg.dispose();
        aetherImg.dispose();
      }
    } catch (_) {
      // Procedural fallback gracefully kicks in
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initGame();
        }
      });
    }
  }

  void _initGame() {
    final size = MediaQuery.of(context).size;
    final gameState = context.read<GameStateProvider>();
    final settings = context.read<SettingsProvider>();

    _audio.musicVolume = settings.musicVolume;
    _audio.sfxVolume = settings.sfxVolume;

    final engine = gameState.engine;
    engine.onShoot = _onShoot;
    engine.onHit = _onHit;
    engine.onGameOver = _onGameOver;
    engine.onLevelComplete = _onLevelComplete;

    gameState.startLevel(size.width, size.height);
    _audio.playBGM();
    _lastTime = 0;
    if (!_ticker.isAnimating) {
      _ticker.forward();
    }
  }

  void _onTick() {
    final currentTime = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    final dt = (_lastTime == 0) ? 1 / 60 : (currentTime - _lastTime) / 1e6;
    _lastTime = currentTime.toDouble();

    // Clamp dt to avoid spiral-of-death on frame hitches.
    final clampedDt = dt.clamp(0.0, 1 / 30);

    final gameState = context.read<GameStateProvider>();
    final engine = gameState.engine;
    engine.update(clampedDt);
    engine.smoothCamera(clampedDt);
  }

  // ─── Engine callbacks ───────────────────────────────────────────────────

  void _onShoot() {
    _audio.playShootSound();
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _onHit() {
    final combo = context.read<GameStateProvider>().engine.combo;
    _audio.playHitSound(combo);
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void _onGameOver() {
    _ticker.stop();
    _audio.playGameOverSound();
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _onLevelComplete(int completedLevel, int bonus) {
    final combo = context.read<GameStateProvider>().engine.combo;
    _audio.playHitSound(combo);
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    _showLevelCompleteBanner(completedLevel, bonus);
  }

  void _showLevelCompleteBanner(int completedLevel, int bonus) {
    if (!mounted) return;
    setState(() {
      _bannerLevel = completedLevel;
      _bannerBonus = bonus;
    });
    _bannerTimer?.cancel();
    _bannerController.forward(from: 0.0);
    _bannerTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _bannerController.reverse();
      }
    });
  }

  // ─── Settings modal ────────────────────────────────────────────────────────

  void _openSettings() {
    _ticker.stop();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SettingsModal(),
    ).then((_) {
      _lastTime = 0;
      if (mounted && !_ticker.isAnimating) {
        _ticker.forward();
      }
    });
  }

  // ─── Tap handler ──────────────────────────────────────────────────────────

  void _handleTap() {
    final gameState = context.read<GameStateProvider>();
    gameState.engine.onTap();
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final gameState = context.read<GameStateProvider>();
    final engine = gameState.engine;

    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      body: DefaultTextStyle(
        style: GoogleFonts.inter(
          decoration: TextDecoration.none,
          color: Colors.white,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: Stack(
            children: [
              // ── Solid Deep Space Base Canvas (prevents window bleed) ───
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF050814)),
              ),

              // ── Game Canvas (Driven by _ticker, never rebuilds on HUD updates) ──
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: GamePainter(
                      engine: engine,
                      colorBlindMode: settings.colorBlindMode,
                      graphicsQuality: settings.graphicsQuality,
                      reducedMotion: settings.reducedMotion,
                      isTurkish: settings.isTurkish,
                      equippedPlanet: gameState.equippedPlanet,
                      planetImages: _planetImages,
                      repaint: _ticker,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              // ── HUD Elements (Scoped reactive builder, tight edge alignment) ──
              Positioned.fill(
                child: Consumer<GameStateProvider>(
                  builder: (context, gState, _) {
                    final eng = gState.engine;
                    if (eng.phase != GamePhase.playing && eng.phase != GamePhase.levelComplete) {
                      return const SizedBox.shrink();
                    }

                    return Stack(
                      children: [
                      // Top-Left: Level & Capture Progress Dots (closer to edges)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 6,
                        left: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  settings.strings.level(eng.currentLevel),
                                  style: GoogleFonts.orbitron(
                                    decoration: TextDecoration.none,
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.0,
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: gState.equippedPlanet.primaryColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: gState.equippedPlanet.primaryColor.withValues(alpha: 0.55),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    gState.equippedPlanet.companionName.toUpperCase(),
                                    style: GoogleFonts.orbitron(
                                      decoration: TextDecoration.none,
                                      color: gState.equippedPlanet.companionColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              settings.strings.captures(eng.capturesInLevel, eng.totalCapturesInLevel),
                              style: GoogleFonts.inter(
                                decoration: TextDecoration.none,
                                color: const Color(0xFF9BACCA),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(eng.totalCapturesInLevel, (index) {
                                final isFilled = index < eng.capturesInLevel;
                                return Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFilled ? const Color(0xFF8CEFFF) : const Color(0xFF1E2D4A),
                                    boxShadow: isFilled
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF8CEFFF).withValues(alpha: 0.85),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                      // Top-Right: Score, Settings Gear, Stardust Wallet Pill, Combo Badge (closer to edges)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 6,
                        right: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  settings.strings.score(_formatNumber(eng.score)),
                                  style: GoogleFonts.orbitron(
                                    decoration: TextDecoration.none,
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  key: const Key('game_settings_button'),
                                  onTap: _openSettings,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF0D1424).withValues(alpha: 0.85),
                                      border: Border.all(
                                        color: const Color(0xFF223555),
                                        width: 1,
                                      ),
                                    ),
                                    child: FigmaIcon.gear(size: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1424).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF223555),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FigmaIcon.stardust(size: 12, color: const Color(0xFF8CEFFF)),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatNumber(gState.totalStarDust + eng.levelStarDust),
                                    style: GoogleFonts.inter(
                                      decoration: TextDecoration.none,
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (eng.combo >= 2) ...[
                              const SizedBox(height: 6),
                              Text(
                                settings.strings.combo(eng.combo),
                                style: GoogleFonts.orbitron(
                                  decoration: TextDecoration.none,
                                  color: const Color(0xFF8CEFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF8CEFFF).withValues(alpha: 0.75),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Bottom-Center: TAP ANYWHERE TO LAUNCH Hint (closer to bottom edge)
                      if (eng.phase == GamePhase.playing)
                        Positioned(
                          bottom: MediaQuery.of(context).padding.bottom + 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              settings.strings.tapToLaunch,
                              style: GoogleFonts.inter(
                                decoration: TextDecoration.none,
                                color: const Color(0xFF647B9B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // ── Game Over Modal (Step 5) ───
            Positioned.fill(
              child: Selector<GameStateProvider, GamePhase>(
                selector: (_, g) => g.phase,
                builder: (context, phase, _) {
                  if (phase == GamePhase.gameOver) {
                    final gState = context.read<GameStateProvider>();
                    final eng = gState.engine;
                    return OrbitLostModal(
                      score: eng.score,
                      level: gState.currentLevel,
                      highScore: gState.highScore,
                      runStarDust: eng.runStarDust,
                      totalWalletStarDust: gState.totalStarDust,
                      onRetry: () {
                        final size = MediaQuery.of(context).size;
                        gState.retryLevel(size.width, size.height);
                        _lastTime = 0;
                        if (!_ticker.isAnimating) {
                          _ticker.forward();
                        }
                      },
                      onMenu: () => Navigator.of(context).pop(),
                    );
                  }
                  return const IgnorePointer(child: SizedBox.shrink());
                },
              ),
            ),

            // ── Floating Level Complete Pill Banner (Non-intrusive, auto-dismissing) ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 46,
              left: 0,
              right: 0,
              child: Center(
                child: IgnorePointer(
                  child: FadeTransition(
                    key: const Key('level_complete_banner'),
                    opacity: _bannerFade,
                    child: SlideTransition(
                      position: _bannerSlide,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF091426).withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF8CEFFF).withValues(alpha: 0.45),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8CEFFF).withValues(alpha: 0.22),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF8CEFFF).withValues(alpha: 0.18),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF8CEFFF),
                                size: 13,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              settings.strings.levelCompleteBanner(_bannerLevel),
                              style: GoogleFonts.orbitron(
                                decoration: TextDecoration.none,
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (_bannerBonus > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8CEFFF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FigmaIcon.stardust(size: 11, color: const Color(0xFF8CEFFF)),
                              const SizedBox(width: 4),
                              Text(
                                '+$_bannerBonus',
                                style: GoogleFonts.inter(
                                  decoration: TextDecoration.none,
                                  color: const Color(0xFF8CEFFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
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
            ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _audio.stopBGM();
    _audio.dispose();
    for (final img in _planetImages.values) {
      img.dispose();
    }
    _planetImages.clear();
    super.dispose();
  }
}
