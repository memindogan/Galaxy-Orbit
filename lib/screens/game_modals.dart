/// Game Over (Orbit Lost) and Level/Sector Complete modals.
///
/// Crafted 1:1 against Figma design specifications:
///  - Orbit Lost: c0f7d2b3-59dd-4590-954a-f51bf14627cd.png
///  - Level Complete: c0e62e08-c27d-485e-b16e-ce7f7854aac0.png
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/theme_constants.dart';
import '../providers/settings_provider.dart';
import '../widgets/figma_icons.dart';
import 'package:provider/provider.dart';

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
// 1. ORBIT LOST MODAL (Game Over)
// ─────────────────────────────────────────────────────────────────────────────

class OrbitLostModal extends StatelessWidget {
  final int score;
  final int level;
  final int highScore;
  final int runStarDust;
  final int totalWalletStarDust;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final bool canRevive;
  final bool canAffordRevive;
  final int reviveCost;
  final int remainingRevives;
  final int maxRevives;
  final VoidCallback? onRevive;

  const OrbitLostModal({
    super.key,
    required this.score,
    required this.level,
    required this.highScore,
    required this.runStarDust,
    required this.totalWalletStarDust,
    required this.onRetry,
    required this.onMenu,
    this.canRevive = true,
    this.canAffordRevive = false,
    this.reviveCost = 25,
    this.remainingRevives = 3,
    this.maxRevives = 3,
    this.onRevive,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = settings.strings;
    final isLowQuality = settings.graphicsQuality == GraphicsQuality.low;
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
                              Color(0xD90E223D),
                              Color(0xE6081324),
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
                                  Color(0x800E223D), // frosty cyan luminescence
                                  Color(0xA6081324), // deep translucent icy slate
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
                          const Color(0xFF8CEFFF).withValues(alpha: 0.08),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Glowing Purple Orbit Emblem
                        const _OrbitLostEmblem(),
                        const SizedBox(height: 14),

                        // Level and status caption
                        Text(
                          strings.runEnded(level),
                          style: GoogleFonts.orbitron(
                            color: const Color(0xFFAA93FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Main Title
                        Text(
                          strings.orbitLost,
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Subtitle / quote
                        Text(
                          strings.orbitLostQuote,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: kTextMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Glassmorphic Score Card (Frosted Ice Aesthetic) ─
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                              Text(
                                strings.runScore,
                                style: GoogleFonts.inter(
                                  color: kTextMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatNum(score),
                                style: GoogleFonts.orbitron(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FigmaIcon.trophy(size: 14, color: const Color(0xFFAA93FF)),
                                  const SizedBox(width: 6),
                                  Text(
                                    strings.highScoreLabel(_formatNum(highScore)),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFAA93FF),
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

                        // ── Stardust Status Row ────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FigmaIcon.stardust(size: 15, color: kAccentColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    strings.stardustPill(runStarDust),
                                    style: GoogleFonts.inter(
                                      color: kAccentColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                strings.walletPill(_formatNum(totalWalletStarDust)),
                                style: GoogleFonts.inter(
                                  color: kTextMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Action Buttons ─────────────────────────────────
                        // REVIVE button (Stardust Second Chance)
                        _ReviveActionButton(
                          key: const Key('revive_button'),
                          label: canRevive && remainingRevives > 0
                              ? strings.reviveLabel(remainingRevives, maxRevives)
                              : strings.reviveExhausted,
                          cost: reviveCost,
                          showCost: canRevive && remainingRevives > 0,
                          enabled: canRevive && canAffordRevive && remainingRevives > 0 && onRevive != null,
                          onTap: onRevive,
                        ),
                        const SizedBox(height: 10),

                        // RETRY button (Neon Cyan)
                        _ModalActionButton(
                          label: strings.retry,
                          icon: Icons.refresh_rounded,
                          isPrimary: true,
                          onTap: onRetry,
                        ),
                        const SizedBox(height: 10),

                        // MENU button (Dark Glass)
                        _ModalActionButton(
                          label: strings.menu,
                          isPrimary: false,
                          onTap: onMenu,
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

/// Custom painted glowing purple emblem for Orbit Lost.
class _OrbitLostEmblem extends StatelessWidget {
  const _OrbitLostEmblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer halo
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFAA93FF).withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAA93FF).withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // Orbital center glyph
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFAA93FF),
                        width: 1.4,
                      ),
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFFAA93FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Satellite dot on top left
                  Positioned(
                    top: 1,
                    left: 2,
                    child: Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC4B5FD),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Satellite dot on bottom right
                  Positioned(
                    bottom: 1,
                    right: 2,
                    child: Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC4B5FD),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 4-pointed star sparkle on top right
          Positioned(
            top: 2,
            right: 4,
            child: FigmaIcon.stardust(size: 15, color: const Color(0xFFC4B5FD)),
          ),
        ],
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

class _ReviveActionButton extends StatelessWidget {
  final String label;
  final int cost;
  final bool showCost;
  final bool enabled;
  final VoidCallback? onTap;

  const _ReviveActionButton({
    super.key,
    required this.label,
    required this.cost,
    required this.showCost,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color accentPurple = Color(0xFFAA93FF);
    const Color accentGold = Color(0xFFFBBF24);

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: enabled
                      ? [
                          const Color(0xFF2B1B54).withValues(alpha: 0.90),
                          const Color(0xFF191233).withValues(alpha: 0.90),
                        ]
                      : [
                          const Color(0xFF131B2E).withValues(alpha: 0.60),
                          const Color(0xFF0E1525).withValues(alpha: 0.60),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: enabled
                      ? accentPurple.withValues(alpha: 0.65)
                      : const Color(0xFF9BBDEA).withValues(alpha: 0.18),
                  width: 1.2,
                ),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: accentPurple.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: enabled ? accentPurple : kTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showCost) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accentGold.withValues(alpha: 0.45),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FigmaIcon.stardust(size: 12, color: accentGold),
                            const SizedBox(width: 4),
                            Text(
                              '$cost',
                              style: GoogleFonts.orbitron(
                                color: accentGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
