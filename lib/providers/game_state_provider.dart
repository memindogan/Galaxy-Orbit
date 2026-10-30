/// Provider that wraps the GameEngine and exposes reactive state to widgets.
library;
import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/game_engine.dart';
import '../engine/level_manager.dart';
import '../models/cosmic_customization.dart';
import '../models/fleet_planet.dart';
import '../models/planet.dart';

class GameStateProvider extends ChangeNotifier {
  final GameEngine engine = GameEngine();

  int _highScore = 0;
  int _timeAttackHighScore = 0;
  bool _isLastRunNewHighScore = false;
  int _totalStarDust = 0;
  int _bestDistance = 0;
  GameMode _selectedMode = GameMode.endless;
  String? _equippedPlanetId = 'terra';
  Set<String>? _unlockedPlanetIds = {'terra', 'ember'};
  String? _equippedCustomizationId = 'classic';
  Set<String>? _unlockedCustomizationIds = {'classic'};
  bool _isInitialized = false;
  bool _modifiedBeforeLoad = false;
  bool _saveScheduled = false;
  SharedPreferences? _prefs;
  EndlessManager? _endlessManager;

  int get currentLevel => engine.currentLevel;
  int get highScore => _highScore;
  int get timeAttackHighScore => _timeAttackHighScore;
  bool get isLastRunNewHighScore => _isLastRunNewHighScore;
  int get activeHighScore =>
      engine.mode == GameMode.timeAttack ? _timeAttackHighScore : _highScore;
  int get totalStarDust => _totalStarDust;
  int get bestDistance => _bestDistance;
  int get score => engine.score;
  int get levelStarDust => engine.levelStarDust;
  int get combo => engine.combo;
  GamePhase get phase => engine.phase;
  GameMode get selectedMode => _selectedMode;
  bool get isInitialized => _isInitialized;
  bool get canRevive => engine.canRevive;
  bool get canAffordRevive => engine.canRevive && _totalStarDust >= engine.nextReviveCost;
  int get nextReviveCost => engine.nextReviveCost;
  int get remainingRevives => engine.remainingRevives;

  String get equippedPlanetId => _equippedPlanetId ?? 'terra';
  Set<String> get unlockedPlanetIds => _unlockedPlanetIds ?? {'terra', 'ember'};
  FleetPlanet get equippedPlanet => FleetCatalog.getById(_equippedPlanetId ?? 'terra');

  String get equippedCustomizationId => _equippedCustomizationId ?? 'classic';
  Set<String> get unlockedCustomizationIds => _unlockedCustomizationIds ?? {'classic'};
  CosmicCustomization get equippedCustomization =>
      CustomizationCatalog.getById(_equippedCustomizationId ?? 'classic');

  bool isUnlocked(String id) =>
      (_unlockedPlanetIds ?? {'terra', 'ember'}).contains(id);
  bool isEquipped(String id) =>
      (_equippedPlanetId ?? 'terra') == id;

  bool isCustomizationUnlocked(String id) =>
      (_unlockedCustomizationIds ?? {'classic'}).contains(id);
  bool isCustomizationEquipped(String id) =>
      (_equippedCustomizationId ?? 'classic') == id;

  void setGameMode(GameMode mode) {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    notifyListeners();
  }

  GameStateProvider() {
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final diskHigh = prefs.getInt('highScore') ?? 0;
      final diskTimeHigh = prefs.getInt('timeAttackHighScore') ?? 0;
      final diskDust = prefs.getInt('totalStarDust') ?? 0;
      final diskBest = prefs.getInt('bestDistance') ?? 0;
      final diskEquipped = prefs.getString('equippedPlanet') ?? 'terra';
      final savedUnlocked = prefs.getStringList('unlockedPlanets');
      final diskCustom = prefs.getString('equippedCustomization') ?? 'classic';
      final savedUnlockedCustom = prefs.getStringList('unlockedCustomizations');

      if (_modifiedBeforeLoad) {
        _highScore = max(_highScore, diskHigh);
        _timeAttackHighScore = max(_timeAttackHighScore, diskTimeHigh);
        _totalStarDust = max(0, _totalStarDust + diskDust);
        _bestDistance = max(_bestDistance, diskBest);
        if (savedUnlocked != null && savedUnlocked.isNotEmpty) {
          _unlockedPlanetIds = {...?_unlockedPlanetIds, ...savedUnlocked};
        }
        if (savedUnlockedCustom != null && savedUnlockedCustom.isNotEmpty) {
          _unlockedCustomizationIds = {...?_unlockedCustomizationIds, ...savedUnlockedCustom};
        }
      } else {
        _highScore = diskHigh;
        _timeAttackHighScore = diskTimeHigh;
        _totalStarDust = diskDust;
        _bestDistance = diskBest;
        _equippedPlanetId = diskEquipped;
        _equippedCustomizationId = diskCustom;
        if (savedUnlocked != null && savedUnlocked.isNotEmpty) {
          _unlockedPlanetIds = savedUnlocked.toSet();
        } else {
          _unlockedPlanetIds = {'terra', 'ember'};
        }
        if (savedUnlockedCustom != null && savedUnlockedCustom.isNotEmpty) {
          _unlockedCustomizationIds = savedUnlockedCustom.toSet();
        } else {
          _unlockedCustomizationIds = {'classic'};
        }
      }
      _isInitialized = true;
      notifyListeners();
    } catch (_) {
      _isInitialized = true;
    }
  }

  void _scheduleSave({bool immediate = false}) {
    if (!_isInitialized) {
      _modifiedBeforeLoad = true;
    }
    if (immediate) {
      _saveData();
      return;
    }
    if (_saveScheduled) return;
    _saveScheduled = true;
    Future.microtask(() {
      _saveScheduled = false;
      _saveData();
    });
  }

  Future<void> _saveData() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await Future.wait([
        prefs.setInt('highScore', _highScore),
        prefs.setInt('timeAttackHighScore', _timeAttackHighScore),
        prefs.setInt('totalStarDust', _totalStarDust),
        prefs.setInt('bestDistance', _bestDistance),
        prefs.setString('equippedPlanet', _equippedPlanetId ?? 'terra'),
        prefs.setStringList('unlockedPlanets', (_unlockedPlanetIds ?? {'terra', 'ember'}).toList()),
        prefs.setString('equippedCustomization', _equippedCustomizationId ?? 'classic'),
        prefs.setStringList('unlockedCustomizations', (_unlockedCustomizationIds ?? {'classic'}).toList()),
      ]);
    } catch (_) {}
  }

  /// Equips an already unlocked planet.
  void equipPlanet(String id) {
    _unlockedPlanetIds ??= {'terra', 'ember'};
    if (!_unlockedPlanetIds!.contains(id)) return;
    _equippedPlanetId = id;
    _endlessManager = null;
    _scheduleSave(immediate: true);
    notifyListeners();
  }

  /// Unlocks a locked planet if sufficient Stardust is available.
  bool unlockPlanet(String id) {
    _unlockedPlanetIds ??= {'terra', 'ember'};
    final planet = FleetCatalog.getById(id);
    if (_unlockedPlanetIds!.contains(id)) {
      equipPlanet(id);
      return true;
    }
    if (_totalStarDust < planet.price) {
      return false;
    }
    _totalStarDust -= planet.price;
    _unlockedPlanetIds!.add(id);
    _equippedPlanetId = id; // auto equip upon unlock
    _endlessManager = null;
    _scheduleSave(immediate: true);
    notifyListeners();
    return true;
  }

  /// Equips an already unlocked cosmic customization (trail + launch wave).
  void equipCustomization(String id) {
    _unlockedCustomizationIds ??= {'classic'};
    if (!_unlockedCustomizationIds!.contains(id)) return;
    _equippedCustomizationId = id;
    _scheduleSave(immediate: true);
    notifyListeners();
  }

  /// Unlocks a cosmic customization if sufficient Stardust is available.
  bool unlockCustomization(String id) {
    _unlockedCustomizationIds ??= {'classic'};
    final item = CustomizationCatalog.getById(id);
    if (_unlockedCustomizationIds!.contains(id)) {
      equipCustomization(id);
      return true;
    }
    if (_totalStarDust < item.price) {
      return false;
    }
    _totalStarDust -= item.price;
    _unlockedCustomizationIds!.add(id);
    _equippedCustomizationId = id;
    _scheduleSave(immediate: true);
    notifyListeners();
    return true;
  }

  void Function()? _onHitCallback;
  void Function()? _onShootCallback;
  void Function()? _onGameOverCallback;
  void Function(int completedLevel, int bonus)? _onLevelCompleteCallback;
  void Function(OrbitPowerUpType powerUp)? _onPowerUpCollectedCallback;
  void Function(bool brokeHazard)? _onShieldUsedCallback;

  /// Attach active UI listeners from the currently mounted GameScreen.
  void attachCallbacks({
    VoidCallback? onHit,
    VoidCallback? onShoot,
    VoidCallback? onGameOver,
    void Function(int completedLevel, int bonus)? onLevelComplete,
    void Function(OrbitPowerUpType powerUp)? onPowerUpCollected,
    void Function(bool brokeHazard)? onShieldUsed,
  }) {
    _onHitCallback = onHit;
    _onShootCallback = onShoot;
    _onGameOverCallback = onGameOver;
    _onLevelCompleteCallback = onLevelComplete;
    _onPowerUpCollectedCallback = onPowerUpCollected;
    _onShieldUsedCallback = onShieldUsed;
  }

  /// Detach UI listeners when GameScreen is unmounted/disposed.
  void detachCallbacks() {
    _onHitCallback = null;
    _onShootCallback = null;
    _onGameOverCallback = null;
    _onLevelCompleteCallback = null;
    _onPowerUpCollectedCallback = null;
    _onShieldUsedCallback = null;
  }

  /// Initialise or restart the active game mode.
  void startLevel(double screenWidth, double screenHeight, {GameMode? modeOverride}) {
    if (modeOverride != null) {
      _selectedMode = modeOverride;
    }
    _isLastRunNewHighScore = false;
    _endlessManager = EndlessManager(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      startingPlanet: equippedPlanet,
    );

    engine.init(_endlessManager!, screenWidth, screenHeight, gameMode: _selectedMode);

    engine.onHit = () {
      try {
        _onHitCallback?.call();
      } catch (e) {
        debugPrint('Error in onHit callback: $e');
      }
      if (engine.capturesInLevel < engine.totalCapturesInLevel) {
        notifyListeners();
      }
    };

    engine.onShoot = () {
      try {
        _onShootCallback?.call();
      } catch (e) {
        debugPrint('Error in onShoot callback: $e');
      }
    };

    engine.onPowerUpCollected = (powerUp) {
      try {
        _onPowerUpCollectedCallback?.call(powerUp);
      } catch (e) {
        debugPrint('Error in onPowerUpCollected callback: $e');
      }
      notifyListeners();
    };

    engine.onShieldUsed = (brokeHazard) {
      try {
        _onShieldUsedCallback?.call(brokeHazard);
      } catch (e) {
        debugPrint('Error in onShieldUsed callback: $e');
      }
      notifyListeners();
    };

    engine.onGameOver = () {
      _updateHighScore();
      _totalStarDust += engine.sectorStarDust;
      engine.sectorStarDust = 0;
      engine.levelStarDust = 0;
      _scheduleSave(immediate: true);
      try {
        _onGameOverCallback?.call();
      } catch (e) {
        debugPrint('Error in onGameOver callback: $e');
      }
      notifyListeners();
    };

    engine.onLevelComplete = (completedLevel, bonus) {
      _updateHighScore();
      _totalStarDust += engine.lastBankedSectorStarDust;
      // Debounce disk I/O so completing a level mid-flight never stalls the 60fps render loop
      _scheduleSave(immediate: false);
      try {
        _onLevelCompleteCallback?.call(completedLevel, bonus);
      } catch (e) {
        debugPrint('Error in onLevelComplete callback: $e');
      }
      notifyListeners();
    };

    notifyListeners();
  }

  /// Advance to the next sector/level.
  void nextLevel() {
    engine.advanceToNextLevel();
    notifyListeners();
  }

  /// Retry the game.
  void retryLevel(double screenWidth, double screenHeight) {
    startLevel(screenWidth, screenHeight);
  }

  /// Spend Stardust to revive the player on the last cleared planet.
  /// Costs escalate across consecutive uses in a run: 25 -> 60 -> 120 (max 3).
  bool revive() {
    if (!canAffordRevive) return false;
    final cost = engine.nextReviveCost;
    if (!engine.revivePlayer()) return false;
    _totalStarDust -= cost;
    _scheduleSave(immediate: false);
    notifyListeners();
    return true;
  }

  void _updateHighScore() {
    if (engine.mode == GameMode.timeAttack) {
      if (engine.score > _timeAttackHighScore && engine.score > 0) {
        _timeAttackHighScore = engine.score;
        _isLastRunNewHighScore = true;
      }
    } else {
      if (engine.score > _highScore && engine.score > 0) {
        _highScore = engine.score;
        _isLastRunNewHighScore = true;
      }
      if (engine.currentLevel > _bestDistance) {
        _bestDistance = engine.currentLevel;
      }
    }
  }
}
