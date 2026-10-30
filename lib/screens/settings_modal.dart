/// Settings modal bottom sheet.
///
/// Crafted 1:1 against Figma design specifications:
/// media_1793295243950_d21eb68d.png
///
/// Features:
///  - Top drag handle & close button
///  - SOUND & FEEL (Violet header):
///      - Music Volume slider with live percentage & speaker icon
///      - Sound Effects Volume slider with live percentage & soundwave icon
///      - Haptic feedback glowing iOS-style cyan switch & vibrate icon
///  - SYSTEM & ACCESSIBILITY (Violet header):
///      - Graphics quality segmented control (Low / Medium / HIGH)
///      - Language segmented control (English / TÜRKÇE)
///      - Reduced motion switch
///      - Color blind mode switch
///  - Footer: • GALAXY ORBIT • v1.0.0 • SYSTEM NOMINAL
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/figma_icons.dart';

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
                // ── Drag Handle Bar ────────────────────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4, bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24364E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header: Title & Close Button ───────────────────────────
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
                        alignment: Alignment.center,
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

                // ── SECTION 1: SOUND & FEEL ────────────────────────────────
                Text(
                  settings.strings.soundAndFeel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFC084FC),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 18),

                // Music Volume
                _FullVolumeSlider(
                  icon: FigmaIcon.speaker(size: 18, color: const Color(0xFFF0F7FF)),
                  label: settings.strings.music,
                  value: settings.musicVolume,
                  onChanged: (v) => settings.musicVolume = v,
                ),
                const SizedBox(height: 18),

                // Sound Effects Volume
                _FullVolumeSlider(
                  icon: FigmaIcon.soundwave(size: 18, color: const Color(0xFFF0F7FF)),
                  label: settings.strings.soundEffects,
                  value: settings.sfxVolume,
                  onChanged: (v) => settings.sfxVolume = v,
                ),
                const SizedBox(height: 16),

                // Haptic Feedback Switch
                _SettingsToggleRow(
                  icon: FigmaIcon.vibrate(size: 18, color: const Color(0xFFF0F7FF)),
                  label: settings.strings.hapticFeedback,
                  value: settings.vibrationEnabled,
                  onChanged: (v) {
                    if (v) HapticService.mediumImpact();
                    settings.vibrationEnabled = v;
                  },
                ),

                // ── Divider ────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 22),
                  height: 1,
                  color: const Color(0xFF16253B),
                ),

                // ── SECTION 2: SYSTEM & ACCESSIBILITY ──────────────────────
                Text(
                  settings.strings.system,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFC084FC),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Graphics Quality Label + Segmented Control
                GestureDetector(
                  onTap: () {
                    if (settings.vibrationEnabled) HapticService.selectionClick();
                    settings.cycleGraphicsQuality();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    settings.strings.graphicsQuality,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9BACCA),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _GraphicsSegmentedControl(
                  current: settings.graphicsQuality,
                  strings: settings.strings,
                  onSelect: (q) {
                    if (settings.vibrationEnabled) HapticService.selectionClick();
                    settings.graphicsQuality = q;
                  },
                ),
                const SizedBox(height: 18),

                // Language Label + Segmented Control
                GestureDetector(
                  onTap: () {
                    if (settings.vibrationEnabled) HapticService.selectionClick();
                    settings.cycleLanguage();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    settings.strings.languageTitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9BACCA),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LanguageSegmentedControl(
                  currentLanguage: settings.language,
                  onSelect: (lang) {
                    if (settings.vibrationEnabled) HapticService.selectionClick();
                    settings.language = lang;
                  },
                ),
                const SizedBox(height: 18),

                // Reduced Motion Switch
                _SettingsToggleRow(
                  label: settings.strings.reducedMotion,
                  value: settings.reducedMotion,
                  onChanged: (v) {
                    if (settings.vibrationEnabled) HapticService.selectionClick();
                    settings.reducedMotion = v;
                  },
                ),
                const SizedBox(height: 16),

                // Color-blind Mode Switch
                _SettingsToggleRow(
                  label: settings.strings.colorBlindMode,
                  value: settings.colorBlindMode,
                  onChanged: (v) {
                    if (settings.vibrationEnabled) HapticService.selectionClick();
                    settings.colorBlindMode = v;
                  },
                ),

                // ── Footer: Version Info ───────────────────────────────────
                const SizedBox(height: 32),
                Center(
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
                      const SizedBox(width: 8),
                      Text(
                        settings.strings.versionFooter,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF647B9B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Home indicator space
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
              ],
            ),
          ),
        );

        if (isLowQuality) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: ColoredBox(
              color: const Color(0xF50A1322),
              child: sheetContent,
            ),
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

// ═════════════════════════════════════════════════════════════════════════════
// Sub-components: Volume Slider, Toggle Switch, Segmented Controls
// ═════════════════════════════════════════════════════════════════════════════

class _FullVolumeSlider extends StatelessWidget {
  final Widget icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _FullVolumeSlider({
    required this.icon,
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
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFFF0F7FF),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF8CEFFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF8CEFFF),
            inactiveTrackColor: const Color(0xFF132237),
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

class _SettingsToggleRow extends StatelessWidget {
  final Widget? icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFF0F7FF),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 48,
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: value ? const Color(0xFF8CEFFF) : const Color(0xFF24364E),
              boxShadow: value
                  ? [
                      const BoxShadow(
                        color: Color(0x608CEFFF),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GraphicsSegmentedControl extends StatelessWidget {
  final GraphicsQuality current;
  final AppStrings strings;
  final ValueChanged<GraphicsQuality> onSelect;

  const _GraphicsSegmentedControl({
    required this.current,
    required this.strings,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1422),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF132237), width: 1.0),
      ),
      child: Row(
        children: GraphicsQuality.values.map((q) {
          final isSelected = current == q;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(q),
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF112338) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF8CEFFF), width: 1.2)
                      : null,
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x258CEFFF),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  strings.graphicsQualityLabel(q),
                  style: GoogleFonts.inter(
                    color: isSelected ? const Color(0xFF8CEFFF) : const Color(0xFF647B9B),
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LanguageSegmentedControl extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onSelect;

  const _LanguageSegmentedControl({
    required this.currentLanguage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const langs = ['English', 'Türkçe'];
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1422),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF132237), width: 1.0),
      ),
      child: Row(
        children: langs.map((lang) {
          final isSelected = currentLanguage == lang;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(lang),
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF112338) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF8CEFFF), width: 1.2)
                      : null,
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x258CEFFF),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  lang,
                  style: GoogleFonts.inter(
                    color: isSelected ? const Color(0xFF8CEFFF) : const Color(0xFF647B9B),
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
