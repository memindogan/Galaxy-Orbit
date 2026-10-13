/// Neon Orbit color palette and theme constants.
///
/// All visual tokens (colors, glow radii, stroke widths) live here so that
/// the accessibility color-blind mode can swap palettes in a single place.
library;
import 'dart:ui';

// ─── Default (Normal) Palette ────────────────────────────────────────────────
const Color kBackgroundColor = Color(0xFF050814);
const Color kTextColor = Color(0xFFF2F7FF);
const Color kAccentColor = Color(0xFF8CEFFF);

// ─── Galaxy Orbit (Figma) Design Tokens ─────────────────────────────────────
const Color kTextMuted = Color(0xFF9BACCA); // secondary labels
const Color kTitleSoft = Color(0xFFDCEAFF); // "GALAXY" title
const Color kBorderSoft = Color(0xFF9BBDEA); // hairline borders (use ~15% alpha)
const Color kSurfaceColor = Color(0xFF132139); // cards / buttons (~63% alpha)
const Color kPillSurface = Color(0xFF101B2C); // wallet pill (~56% alpha)
const Color kChipSurface = Color(0xFFA7BDE8); // icon chip (~8% alpha)

/// Figma frame size the UI coordinates are authored against.
const double kDesignWidth = 390.0;
const double kDesignHeight = 844.0;

// ─── Color-Blind Palette ─────────────────────────────────────────────────────
const Color kPlayerColorCB = Color(0xFFFFA500); // Orange
const Color kPlanetColorCB = Color(0xFF1E90FF); // Dodger Blue
