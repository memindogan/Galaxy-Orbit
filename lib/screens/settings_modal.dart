/// Settings modal bottom sheet.
///
/// Crafted 1:1 against Figma design specifications:
/// Yeni UI Tasarımı/27621a4d-130e-4b67-9caa-2b4f7b68d5f9.png
///
/// Features:
///  - SOUND & FEEL:
///      - Music Volume slider (0-100%)
///      - Sound Effects Volume slider (0-100%)
///      - Haptic feedback switch
///  - SYSTEM:
///      - Reduced motion switch
///      - Graphics quality selector (High / Medium / Low)
///      - Language selector (English / Türkçe)
///      - Color blind mode switch
///  - Footer: GALAXY ORBIT · v1.0.0
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/haptic_service.dart';

import '../providers/settings_provider.dart';

class SettingsModal extends StatelessWidget {
  const SettingsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final isLowQuality = settings.graphicsQuality == GraphicsQuality.low;
        final sheetContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1626).withValues(alpha: isLowQuality ? 0.98 : 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: Color(0xFF1E3250), width: 1.2),
              left: BorderSide(color: Color(0xFF1E3250), width: 1.2),
              right: BorderSide(color: Color(0xFF1E3250), width: 1.2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 32,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Drag Handle Bar ────────────────────────────────────
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(top: 4, bottom: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24364E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // ── Header: Title & Close Button ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          settings.strings.settings,
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (settings.vibrationEnabled) {
                              HapticService.selectionClick();
                            }
                            Navigator.of(context).pop();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF132237),
                              border: Border.all(
                                color: const Color(0xFF1E3554),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: Color(0xFF8CEFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── SECTION 1: SOUND & FEEL ────────────────────────────
                    Text(
                      settings.strings.soundAndFeel,
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Music Volume
                    _VolumeSliderRow(
                      label: settings.strings.music,
                      value: settings.musicVolume,
                      onChanged: (v) => settings.musicVolume = v,
                    ),
                    const SizedBox(height: 16),

                    // Sound Effects Volume
                    _VolumeSliderRow(
                      label: settings.strings.soundEffects,
                      value: settings.sfxVolume,
                      onChanged: (v) => settings.sfxVolume = v,
                    ),
                    const SizedBox(height: 12),

                    // Haptic Feedback Switch
                    _SettingsSwitchRow(
                      label: settings.strings.hapticFeedback,
                      value: settings.vibrationEnabled,
                      onChanged: (v) {
                        if (v) HapticService.mediumImpact();
                        settings.vibrationEnabled = v;
                      },
                    ),

                    // ── Divider ────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      height: 1,
                      color: const Color(0xFF16253B),
                    ),

                    // ── SECTION 2: SYSTEM ──────────────────────────────────
                    Text(
                      settings.strings.system,
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reduced Motion Switch
                    _SettingsSwitchRow(
                      label: settings.strings.reducedMotion,
                      value: settings.reducedMotion,
                      onChanged: (v) {
                        if (settings.vibrationEnabled) {
                          HapticService.selectionClick();
                        }
                        settings.reducedMotion = v;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Graphics Quality Option
                    _SettingsActionRow(
                      label: settings.strings.graphicsQuality,
                      valueText: settings.strings.graphicsQualityLabel(settings.graphicsQuality),
                      onTap: () {
                        if (settings.vibrationEnabled) {
                          HapticService.selectionClick();
                        }
                        settings.cycleGraphicsQuality();
                      },
                    ),
                    const SizedBox(height: 14),

                    // Language Option
                    _SettingsActionRow(
                      label: settings.strings.languageTitle,
                      valueText: settings.language,
                      onTap: () {
                        if (settings.vibrationEnabled) {
                          HapticService.selectionClick();
                        }
                        settings.cycleLanguage();
                      },
                    ),
                    const SizedBox(height: 14),

                    // Color-blind Mode Switch
                    _SettingsSwitchRow(
                      label: settings.strings.colorBlindMode,
                      value: settings.colorBlindMode,
                      onChanged: (v) {
                        if (settings.vibrationEnabled) {
                          HapticService.selectionClick();
                        }
                        settings.colorBlindMode = v;
                      },
                    ),

                    // ── Footer: Version Info ───────────────────────────────
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        settings.strings.versionFooter,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF405878),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                  ],
                ),
              ),
            );

        if (isLowQuality) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: sheetContent,
          );
        }

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: sheetContent,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subcomponents
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _VolumeSliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: GoogleFonts.inter(
                color: const Color(0xFF8BA3C7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF8CEFFF),
            inactiveTrackColor: const Color(0xFF14243B),
            thumbColor: const Color(0xFF8CEFFF),
            overlayColor: const Color(0xFF8CEFFF).withValues(alpha: 0.15),
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: 0,
            max: 1,
          ),
        ),
      ],
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF8CEFFF),
          activeTrackColor: const Color(0xFF1A3B5C),
          inactiveThumbColor: const Color(0xFF4A607F),
          inactiveTrackColor: const Color(0xFF121E2F),
        ),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueText,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8BA3C7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF8BA3C7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
