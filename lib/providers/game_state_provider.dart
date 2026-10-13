/// Provider that wraps the GameEngine and exposes reactive state to widgets.
library;
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
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('highScore') ?? 0;
    _totalStarDust = prefs.getInt('totalStarDust') ?? 1240; // starter stardust matching Figma
    _bestDistance = prefs.getInt('bestDistance') ?? 0;
    _equippedPlanetId = prefs.getString('equippedPlanet') ?? 'terra';
    final savedUnlocked = prefs.getStringList('unlockedPlanets');
    if (savedUnlocked != null && savedUnlocked.isNotEmpty) {
      _unlockedPlanetIds = savedUnlocked.toSet();
    } else {
      _unlockedPlanetIds = {'terra', 'ember'};
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', _highScore);
    await prefs.setInt('totalStarDust', _totalStarDust);
    await prefs.setInt('bestDistance', _bestDistance);
    await prefs.setString('equippedPlanet', _equippedPlanetId ?? 'terra');
    await prefs.setStringList('unlockedPlanets', (_unlockedPlanetIds ?? {'terra', 'ember'}).toList());
  }

  /// Equips an already unlocked planet.
  void equipPlanet(String id) {
    _unlockedPlanetIds ??= {'terra', 'ember'};
    if (!_unlockedPlanetIds!.contains(id)) return;
    _equippedPlanetId = id;
    _endlessManager = null;
    _saveData();
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
    _saveData();
    notifyListeners();
    return true;
  }

  /// Initialise or restart the endless mode.
  void startLevel(double screenWidth, double screenHeight) {
    _endlessManager = EndlessManager(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      startingPlanet: equippedPlanet,
    );
    engine.init(_endlessManager!, screenWidth, screenHeight);
    
    // Wire up engine events without dropping existing audio/haptic handlers
    final prevHit = engine.onHit;
    final prevShoot = engine.onShoot;
    final prevGameOver = engine.onGameOver;
    final prevLevelComplete = engine.onLevelComplete;

    engine.onHit = () {
      prevHit?.call();
      notifyListeners();
    };
    engine.onShoot = () {
      prevShoot?.call();
    };
    engine.onGameOver = () {
      _updateHighScore();
      _totalStarDust += engine.sectorStarDust;
      _saveData();
      prevGameOver?.call();
      notifyListeners();
    };
    engine.onLevelComplete = (completedLevel, bonus) {
      _updateHighScore();
      _totalStarDust += bonus;
      _saveData();
      prevLevelComplete?.call(completedLevel, bonus);
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

  void _updateHighScore() {
    if (engine.score > _highScore) {
      _highScore = engine.score;
    }
    if (engine.currentLevel > _bestDistance) {
      _bestDistance = engine.currentLevel;
    }
  }
}
