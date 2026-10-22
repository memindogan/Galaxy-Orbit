/// Provider that wraps the GameEngine and exposes reactive state to widgets.
library;
import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/game_engine.dart';
import '../engine/level_manager.dart';
import '../models/fleet_planet.dart';

class GameStateProvider extends ChangeNotifier {
  final GameEngine engine = GameEngine();

  int _highScore = 0;
  int _totalStarDust = 0;
  int _bestDistance = 0;
  String? _equippedPlanetId = 'terra';
  Set<String>? _unlockedPlanetIds = {'terra', 'ember'};
  bool _isInitialized = false;
  bool _modifiedBeforeLoad = false;
  bool _saveScheduled = false;
  SharedPreferences? _prefs;
  EndlessManager? _endlessManager;

  int get currentLevel => engine.currentLevel;
  int get highScore => _highScore;
  int get totalStarDust => _totalStarDust;
  int get bestDistance => _bestDistance;
  int get score => engine.score;
  int get levelStarDust => engine.levelStarDust;
  int get combo => engine.combo;
  GamePhase get phase => engine.phase;
  bool get isInitialized => _isInitialized;
  bool get canRevive => engine.canRevive;
  bool get canAffordRevive => engine.canRevive && _totalStarDust >= engine.nextReviveCost;
  int get nextReviveCost => engine.nextReviveCost;
  int get remainingRevives => engine.remainingRevives;

  String get equippedPlanetId => _equippedPlanetId ?? 'terra';
  Set<String> get unlockedPlanetIds => _unlockedPlanetIds ?? {'terra', 'ember'};
  FleetPlanet get equippedPlanet => FleetCatalog.getById(_equippedPlanetId ?? 'terra');

  bool isUnlocked(String id) =>
      (_unlockedPlanetIds ?? {'terra', 'ember'}).contains(id);
  bool isEquipped(String id) =>
      (_equippedPlanetId ?? 'terra') == id;

  GameStateProvider() {
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final diskHigh = prefs.getInt('highScore') ?? 0;
      final diskDust = prefs.getInt('totalStarDust') ?? 0;
      final diskBest = prefs.getInt('bestDistance') ?? 0;
      final diskEquipped = prefs.getString('equippedPlanet') ?? 'terra';
      final savedUnlocked = prefs.getStringList('unlockedPlanets');

      if (_modifiedBeforeLoad) {
        _highScore = max(_highScore, diskHigh);
        _totalStarDust = max(0, _totalStarDust + diskDust);
        _bestDistance = max(_bestDistance, diskBest);
        if (savedUnlocked != null && savedUnlocked.isNotEmpty) {
          _unlockedPlanetIds = {...?_unlockedPlanetIds, ...savedUnlocked};
        }
      } else {
        _highScore = diskHigh;
        _totalStarDust = diskDust;
        _bestDistance = diskBest;
        _equippedPlanetId = diskEquipped;
        if (savedUnlocked != null && savedUnlocked.isNotEmpty) {
          _unlockedPlanetIds = savedUnlocked.toSet();
        } else {
          _unlockedPlanetIds = {'terra', 'ember'};
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
        prefs.setInt('totalStarDust', _totalStarDust),
        prefs.setInt('bestDistance', _bestDistance),
        prefs.setString('equippedPlanet', _equippedPlanetId ?? 'terra'),
        prefs.setStringList('unlockedPlanets', (_unlockedPlanetIds ?? {'terra', 'ember'}).toList()),
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

  void Function()? _onHitCallback;
  void Function()? _onShootCallback;
  void Function()? _onGameOverCallback;
  void Function(int completedLevel, int bonus)? _onLevelCompleteCallback;

  /// Attach active UI listeners from the currently mounted GameScreen.
  void attachCallbacks({
    VoidCallback? onHit,
    VoidCallback? onShoot,
    VoidCallback? onGameOver,
    void Function(int completedLevel, int bonus)? onLevelComplete,
  }) {
    _onHitCallback = onHit;
    _onShootCallback = onShoot;
    _onGameOverCallback = onGameOver;
    _onLevelCompleteCallback = onLevelComplete;
  }

  /// Detach UI listeners when GameScreen is unmounted/disposed.
  void detachCallbacks() {
    _onHitCallback = null;
    _onShootCallback = null;
    _onGameOverCallback = null;
    _onLevelCompleteCallback = null;
  }

  /// Initialise or restart the endless mode.
  void startLevel(double screenWidth, double screenHeight) {
    _endlessManager = EndlessManager(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      startingPlanet: equippedPlanet,
    );

    engine.init(_endlessManager!, screenWidth, screenHeight);

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
    if (engine.score > _highScore) {
      _highScore = engine.score;
    }
    if (engine.currentLevel > _bestDistance) {
      _bestDistance = engine.currentLevel;
    }
  }
}
