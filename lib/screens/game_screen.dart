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
import '../l10n/app_strings.dart';
import '../models/fleet_planet.dart';
import '../painters/game_painter.dart';
import '../providers/game_state_provider.dart';
import '../providers/settings_provider.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../widgets/figma_icons.dart';
import 'game_modals.dart';
import 'settings_modal.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _ticker;
  late AnimationController _bannerController;
  late CurvedAnimation _bannerFade;
  late Animation<Offset> _bannerSlide;
  Timer? _bannerTimer;
  final ValueNotifier<({int level, int bonus})> _bannerNotifier =
      ValueNotifier((level: 1, bonus: 0));
  late AudioService _audio;
  double _lastTime = 0;
  bool _initialised = false;
  Map<String, ui.Image> _planetImages = _cachedPlanetImages ?? {};
  static Map<String, ui.Image>? _cachedPlanetImages;
  static Future<Map<String, ui.Image>>? _loadingPlanetImagesFuture;
  GameEngine? _cachedEngine;

  // ─── Pre-cached HUD & Banner TextStyles (avoids GoogleFonts lookup per hit) ─
  static final TextStyle _baseInterStyle = GoogleFonts.inter(
    decoration: TextDecoration.none,
    color: Colors.white,
  );
  static final TextStyle _hudLevelStyle = GoogleFonts.orbitron(
    decoration: TextDecoration.none,
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
    shadows: const [
      Shadow(
        color: Color(0x59FFFFFF),
        blurRadius: 6,
      ),
    ],
  );
  static final TextStyle _hudCapturesStyle = GoogleFonts.inter(
    decoration: TextDecoration.none,
    color: const Color(0xFF9BACCA),
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static final TextStyle _hudScoreStyle = GoogleFonts.orbitron(
    decoration: TextDecoration.none,
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    shadows: const [
      Shadow(
        color: Color(0x59FFFFFF),
        blurRadius: 6,
      ),
    ],
  );
  static final TextStyle _hudWalletStyle = GoogleFonts.inter(
    decoration: TextDecoration.none,
    color: Colors.white,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );
  static final TextStyle _hudComboStyle = GoogleFonts.orbitron(
    decoration: TextDecoration.none,
    color: const Color(0xFF8CEFFF),
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    shadows: const [
      Shadow(
        color: Color(0xBF8CEFFF),
        blurRadius: 10,
      ),
    ],
  );
  static final TextStyle _hudTapHintStyle = GoogleFonts.inter(
    decoration: TextDecoration.none,
    color: const Color(0xFF647B9B),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
  );
  static final TextStyle _bannerTitleStyle = GoogleFonts.orbitron(
    decoration: TextDecoration.none,
    color: Colors.white,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
  static final TextStyle _bannerBonusStyle = GoogleFonts.inter(
    decoration: TextDecoration.none,
    color: const Color(0xFF8CEFFF),
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (_cachedPlanetImages != null) {
      if (mounted && _planetImages != _cachedPlanetImages) {
        setState(() => _planetImages = _cachedPlanetImages!);
      }
      return;
    }

    try {
      _loadingPlanetImagesFuture ??= _decodeAllPlanetTextures();
      final result = await _loadingPlanetImagesFuture!;
      _cachedPlanetImages = result;
      if (mounted) {
        setState(() => _planetImages = result);
      }
    } catch (_) {
      _loadingPlanetImagesFuture = null;
      // Procedural fallback gracefully kicks in
    }
  }

  static Future<Map<String, ui.Image>> _decodeAllPlanetTextures() async {
    const double size = 256.0;
    final Rect dstRect = const Rect.fromLTWH(0, 0, size, size);
    final Path clipCircle = Path()..addOval(dstRect);
    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;

    Future<ui.Image> decodeAndPreMaskAsset(String path) async {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256, targetHeight: 256);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final rawImg = frame.image;

      // Pre-crop 6.5% inset and pre-mask into a circular GPU texture once at load time
      // so GamePainter never needs canvas.clipRRect during 60/120fps gameplay!
      final inset = rawImg.width * 0.065;
      final srcRect = Rect.fromLTWH(
        inset,
        inset,
        rawImg.width - 2 * inset,
        rawImg.height - 2 * inset,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, dstRect);
      canvas.clipPath(clipCircle);
      canvas.drawImageRect(rawImg, srcRect, dstRect, paint);
      final picture = recorder.endRecording();
      final circularImg = await picture.toImage(256, 256);
      picture.dispose();
      rawImg.dispose();
      return circularImg;
    }

    final map = <String, ui.Image>{};
    for (final w in FleetCatalog.worlds) {
      try {
        map[w.id] = await decodeAndPreMaskAsset(w.assetPath);
      } catch (_) {}
    }
    return map;
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
    } else if (_cachedEngine != null) {
      final size = MediaQuery.sizeOf(context);
      if (size.width > 0 && size.height > 0) {
        _cachedEngine!.updateScreenSize(size.width, size.height);
      }
    }
  }

  void _initGame() {
    final size = MediaQuery.sizeOf(context);
    final gameState = context.read<GameStateProvider>();
    _cachedEngine = gameState.engine;
    final settings = context.read<SettingsProvider>();

    _audio.musicVolume = settings.musicVolume;
    _audio.sfxVolume = settings.sfxVolume;

    gameState.attachCallbacks(
      onShoot: _onShoot,
      onHit: _onHit,
      onGameOver: _onGameOver,
      onLevelComplete: _onLevelComplete,
    );

    gameState.startLevel(size.width, size.height);
    _audio.playBGM();
    _lastTime = 0;
    if (!_ticker.isAnimating) {
      _ticker.forward();
    }
  }

  void _onTick() {
    final currentTime = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    double dt = (_lastTime == 0) ? (1.0 / 60.0) : (currentTime - _lastTime) / 1e6;
    _lastTime = currentTime.toDouble();

    // Guard against identical microsecond vsync ticks, clock rewind, or NaN/infinity.
    if (dt <= 0.0 || dt.isNaN || dt.isInfinite) {
      dt = 1.0 / 60.0;
    }

    // Clamp total frame delta to 50ms max, and sub-step physics in <= 16.67ms increments
    // so frame hitches never lose physics time or cause orbital velocity warping.
    final clampedDt = dt.clamp(1.0 / 240.0, 0.05);
    const double maxPhysicsStep = 1.0 / 60.0;

    final engine = _cachedEngine;
    if (engine != null) {
      double remaining = clampedDt;
      while (remaining > 1e-5 && engine.phase == GamePhase.playing) {
        final step = remaining > maxPhysicsStep ? maxPhysicsStep : remaining;
        engine.update(step);
        remaining -= step;
      }
      engine.smoothCamera(clampedDt);
    }
  }

  // ─── Engine callbacks ───────────────────────────────────────────────────

  void _onShoot() {
    _audio.playShootSound();
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      HapticService.lightImpact();
    }
  }

  void _onHit() {
    final combo = context.read<GameStateProvider>().engine.combo;
    _audio.playHitSound(combo);
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      if (combo > 0) {
        HapticService.heavyImpact();
      } else {
        HapticService.mediumImpact();
      }
    }
  }

  void _onGameOver() {
    if (_ticker.isAnimating) {
      _ticker.stop();
    }
    _audio.pauseBGM();
    _audio.playGameOverSound();
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      HapticService.heavyImpact();
    }
  }

  void _onLevelComplete(int completedLevel, int bonus) {
    final combo = context.read<GameStateProvider>().engine.combo;
    _audio.playHitSound(combo);
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      HapticService.heavyImpact();
    }
    _showLevelCompleteBanner(completedLevel, bonus);
  }

  void _showLevelCompleteBanner(int completedLevel, int bonus) {
    if (!mounted) return;
    _bannerNotifier.value = (level: completedLevel, bonus: bonus);
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
    _cachedEngine?.onTap();
  }

  String _formatNumber(int n) {
    if (n >= 0 && n < 1000) return n.toString();
    final s = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gameState = context.read<GameStateProvider>();
    final engine = gameState.engine;

    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      body: DefaultTextStyle(
        style: _baseInterStyle,
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
                  child: Selector<SettingsProvider, (bool, GraphicsQuality, bool, bool)>(
                    selector: (_, s) => (
                      s.colorBlindMode,
                      s.graphicsQuality,
                      s.reducedMotion,
                      s.isTurkish,
                    ),
                    builder: (context, data, _) {
                      final equipped = context.select<GameStateProvider, FleetPlanet>(
                        (g) => g.equippedPlanet,
                      );
                      return CustomPaint(
                        painter: GamePainter(
                          engine: engine,
                          colorBlindMode: data.$1,
                          graphicsQuality: data.$2,
                          reducedMotion: data.$3,
                          isTurkish: data.$4,
                          equippedPlanet: equipped,
                          planetImages: _planetImages,
                          repaint: _ticker,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ),

              // ── HUD Elements (Isolated RepaintBoundary + cached TextStyles) ──
              Positioned.fill(
                child: RepaintBoundary(
                  child: Consumer<GameStateProvider>(
                    builder: (context, gState, _) {
                      final eng = gState.engine;
                      if (eng.phase != GamePhase.playing && eng.phase != GamePhase.levelComplete) {
                        return const SizedBox.shrink();
                      }
                      final strings = context.select<SettingsProvider, AppStrings>((s) => s.strings);
                      final isColorBlind = context.select<SettingsProvider, bool>((s) => s.colorBlindMode);

                      return Stack(
                        children: [
                        // Top-Left: Level & Capture Progress Dots (closer to edges)
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 6,
                          left: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    strings.level(eng.currentLevel),
                                    style: _hudLevelStyle,
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
                                strings.captures(eng.capturesInLevel, eng.totalCapturesInLevel),
                                style: _hudCapturesStyle,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(eng.totalCapturesInLevel, (index) {
                                  final isFilled = index < eng.capturesInLevel;
                                  final activeDotColor = isColorBlind
                                      ? const Color(0xFFFFD600)
                                      : const Color(0xFF8CEFFF);
                                  return Container(
                                    margin: const EdgeInsets.only(right: 5),
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFilled ? activeDotColor : const Color(0xFF1E2D4A),
                                      boxShadow: isFilled
                                          ? [
                                              BoxShadow(
                                                color: activeDotColor.withValues(alpha: 0.85),
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
                          top: MediaQuery.paddingOf(context).top + 6,
                          right: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    strings.score(_formatNumber(eng.score)),
                                    style: _hudScoreStyle,
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
                                        color: const Color(0xD90D1424),
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
                                  color: const Color(0xD90D1424),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF223555),
                                    width: 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66000000),
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
                                      style: _hudWalletStyle,
                                    ),
                                  ],
                                ),
                              ),
                              if (eng.combo >= 1) ...[
                                const SizedBox(height: 6),
                                Text(
                                  strings.combo(eng.combo),
                                  style: _hudComboStyle,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Bottom-Center: TAP ANYWHERE TO LAUNCH Hint (closer to bottom edge)
                        if (eng.phase == GamePhase.playing)
                          Positioned(
                            bottom: MediaQuery.paddingOf(context).bottom + 14,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Text(
                                strings.tapToLaunch,
                                style: _hudTapHintStyle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
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
                      canRevive: gState.canRevive,
                      canAffordRevive: gState.canAffordRevive,
                      reviveCost: gState.nextReviveCost,
                      remainingRevives: gState.remainingRevives,
                      maxRevives: GameEngine.maxRevivesPerRun,
                      onRevive: () {
                        if (gState.revive()) {
                          _audio.resumeBGM();
                          _lastTime = 0;
                          if (!_ticker.isAnimating) {
                            _ticker.forward();
                          }
                        }
                      },
                      onRetry: () {
                        final size = MediaQuery.sizeOf(context);
                        gState.retryLevel(size.width, size.height);
                        _audio.resumeBGM();
                        _lastTime = 0;
                        if (!_ticker.isAnimating) {
                          _ticker.forward();
                        }
                      },
                      onMenu: () {
                        _audio.resumeBGM();
                        Navigator.of(context).pop();
                      },
                    );
                  }
                  return const IgnorePointer(child: SizedBox.shrink());
                },
              ),
            ),

            // ── Floating Level Complete Pill Banner (Zero full-screen setState) ──
            Positioned(
              top: MediaQuery.paddingOf(context).top + 46,
              left: 0,
              right: 0,
              child: Center(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: FadeTransition(
                      key: const Key('level_complete_banner'),
                      opacity: _bannerFade,
                      child: SlideTransition(
                        position: _bannerSlide,
                        child: ValueListenableBuilder<({int level, int bonus})>(
                          valueListenable: _bannerNotifier,
                          builder: (context, banner, _) {
                            final strings = context.select<SettingsProvider, AppStrings>(
                              (s) => s.strings,
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xE6091426),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0x738CEFFF),
                                  width: 1.0,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x388CEFFF),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: Color(0x73000000),
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
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0x2E8CEFFF),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Color(0xFF8CEFFF),
                                      size: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    strings.levelCompleteBanner(banner.level),
                                    style: _bannerTitleStyle,
                                  ),
                                  if (banner.bonus > 0) ...[
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
                                      '+${banner.bonus}',
                                      style: _bannerBonusStyle,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      if (_ticker.isAnimating) {
        _ticker.stop();
      }
      _audio.pauseBGM();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) {
        final gameState = context.read<GameStateProvider>();
        if (gameState.phase == GamePhase.playing) {
          _lastTime = 0;
          if (!_ticker.isAnimating) {
            _ticker.forward();
          }
          _audio.resumeBGM();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.resumeBGM();
    try {
      context.read<GameStateProvider>().detachCallbacks();
    } catch (_) {}
    _ticker.dispose();
    _bannerTimer?.cancel();
    _bannerNotifier.dispose();
    _bannerFade.dispose();
    _bannerController.dispose();
    super.dispose();
  }
}
