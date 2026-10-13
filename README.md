# 🪐 Galaxy Orbit

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.1+-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Tests](https://img.shields.io/badge/Tests-17%20Passed-brightgreen)

**Galaxy Orbit** is a fast-paced, neon-styled orbital physics arcade game built from scratch using pure Flutter and high-performance `CustomPainter` rendering. Slingshot through deep space, latch onto planetary gravitational fields, collect Stardust, and conquer endless cosmic sectors!

[Features](#-key-features) • [Gameplay](#-gameplay--controls) • [Architecture](#-architecture--performance) • [Getting Started](#-getting-started) • [Fleet Hangar](#-fleet-hangar)

</div>

---

## ✨ Key Features

- 🌌 **High-Octane Orbital Mechanics:** Slingshot between celestial bodies with realistic gravitational acceleration and responsive one-tap controls.
- 🎨 **Neon Cyberpunk Aesthetic:** Custom glow shaders, smooth trail rendering, dynamic starfield parallax, and explosive particle feedback.
- 🚀 **12 Unlockable Planets / Ships:** Collect Stardust across your runs to unlock distinct celestial hulls in the Hangar with custom neon palettes and traits.
- ⚡ **Seamless Flow State:** Non-intrusive floating HUD notifications for level progressions and achievements that never pause your momentum.
- 🎵 **Atmospheric Audio Engine:** Multi-layered sound effects for orbital latching, slingshot releases, near-miss boosts, and ambient deep space synth.
- 📱 **Pure Flutter Canvas:** Zero third-party physics bloat; 60/120 FPS buttery-smooth frame rendering with zero garbage collection spikes.

---

## 🕹️ Gameplay & Controls

| Action | Control | Description |
| :--- | :--- | :--- |
| **Launch / Release** | `Tap anywhere` | Release from current orbit and slingshot forward into deep space. |
| **Latch Orbit** | `Proximity Trigger` | Automatically enters the gravitational pull when entering a planet's gravity well. |
| **Direction Switch** | `Orbit Dynamics` | Slingshot angles dictate your rotational direction (Clockwise / Counter-Clockwise). |
| **Stardust Collect** | `Flight Path` | Intercept glowing space dust floating in sectors to fund hangar unlocks. |

> **Pro Tip:** Time your slingshot release at the tangent point of your orbit toward the next target planet to maintain high combo speed and earn bonus Stardust!

---

## 🛠️ Architecture & Performance

Galaxy Orbit is built with an ultra-lean architecture optimized for mobile devices:

- **Render Loop:** Driven by Flutter's `Ticker` / `AnimationController` delivering consistent 60–120 FPS render loops via `GamePainter`.
- **Pre-cached & Static Drawing:** Avoids runtime paint allocations and GC pauses by reusing cached `Paint` objects, paths, and trigonometric lookups.
- **State Separation:** Decoupled `GameProvider` manages score, stardust, game state, and high scores with persistent storage via `SharedPreferences`.
- **Responsive Layout:** Edge-to-edge safe area HUD aligning score, level banners, audio toggles, and pause menus symmetrically across all phone aspect ratios.

```
lib/
├── engine/          # Game physics, collision detection, and coordinate transforms
├── models/          # Planet, Ship, Stardust, and Particle entities
├── painters/        # Optimized CustomPainters (GamePainter, StarfieldPainter)
├── providers/       # State management (GameProvider)
├── screens/         # MainMenuScreen, GameScreen, HangarScreen
├── services/        # AudioService, StorageService, SettingsService
└── widgets/         # Symmetrical HUD, Level Toast, Modals (Orbit Lost, Settings)
```

---

## 🛸 Fleet Hangar

Unlock up to **12 unique celestial hulls** using collected Stardust:

1. **Neon Prime** (Starter Core)
2. **Solar Flare** (Sunburst Orange)
3. **Void Walker** (Abyssal Purple)
4. **Cyber Sentinel** (Electric Cyan)
5. **Pulsar Drift** (Emerald Ion)
6. **Quantum Nova** (Deep Amethyst)
7. *...and 6 more legendary cosmic bodies!*

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.13.0` or newer)
- Dart SDK (`^3.1.0` or newer)
- Android Studio / Xcode / VS Code

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/memindogan/Galaxy-Orbit.git
   cd Galaxy-Orbit
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run automated test suite:**
   ```bash
   flutter test
   ```

4. **Launch the game:**
   ```bash
   # Android / iOS device or emulator
   flutter run

   # For optimal 60/120 FPS release performance:
   flutter run --release
   ```

---

## 🧪 Testing

The project includes unit and widget tests covering the physics engine, collision boundaries, stardust collection, and UI overlays:

```bash
flutter test
```
All **17 test suites** pass cleanly out-of-the-box.

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
