import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../services/audio_service.dart';

enum GraphicsQuality {
  high('High'),
  medium('Medium'),
  low('Low');

  final String label;
  const GraphicsQuality(this.label);
}

class SettingsProvider extends ChangeNotifier {
  double _musicVolume = 0.75;
  double _sfxVolume = 0.90;
  bool _vibrationEnabled = true;
  bool _colorBlindMode = false;
  bool _reducedMotion = false;
  GraphicsQuality _graphicsQuality = GraphicsQuality.high;
  String _language = 'English';
  AppStrings _cachedStrings = AppStrings('English');
  bool _isLoaded = false;
  SharedPreferences? _prefs;
  Timer? _saveDebounceTimer;

  SettingsProvider() {
    _loadSettings();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get colorBlindMode => _colorBlindMode;
  bool get reducedMotion => _reducedMotion;
  GraphicsQuality get graphicsQuality => _graphicsQuality;
  String get language => _language;
  bool get isLoaded => _isLoaded;
  AppStrings get strings => _cachedStrings;
  bool get isTurkish => _language == 'Türkçe';

  // ─── Setters ──────────────────────────────────────────────────────────────
  set musicVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if ((_musicVolume - clamped).abs() < 0.001) return;
    _musicVolume = clamped;
    AudioService().musicVolume = _musicVolume;
    notifyListeners();
    _scheduleSave();
  }

  set sfxVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if ((_sfxVolume - clamped).abs() < 0.001) return;
    _sfxVolume = clamped;
    AudioService().sfxVolume = _sfxVolume;
    notifyListeners();
    _scheduleSave();
  }

  set vibrationEnabled(bool v) {
    if (_vibrationEnabled == v) return;
    _vibrationEnabled = v;
    notifyListeners();
    _scheduleSave();
  }

  set colorBlindMode(bool v) {
    if (_colorBlindMode == v) return;
    _colorBlindMode = v;
    notifyListeners();
    _scheduleSave();
  }

  set reducedMotion(bool v) {
    if (_reducedMotion == v) return;
    _reducedMotion = v;
    notifyListeners();
    _scheduleSave();
  }

  set graphicsQuality(GraphicsQuality q) {
    if (_graphicsQuality == q) return;
    _graphicsQuality = q;
    notifyListeners();
    _scheduleSave();
  }

  set language(String lang) {
    if (_language == lang) return;
    _language = lang;
    _cachedStrings = AppStrings(_language);
    notifyListeners();
    _scheduleSave();
  }

  // ─── Cycle Helpers ────────────────────────────────────────────────────────
  void cycleGraphicsQuality() {
    switch (_graphicsQuality) {
      case GraphicsQuality.high:
        graphicsQuality = GraphicsQuality.medium;
      case GraphicsQuality.medium:
        graphicsQuality = GraphicsQuality.low;
      case GraphicsQuality.low:
        graphicsQuality = GraphicsQuality.high;
    }
  }

  void cycleLanguage() {
    language = (_language == 'English') ? 'Türkçe' : 'English';
  }

  // ─── Persistence ──────────────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _musicVolume = prefs.getDouble('setting_musicVolume') ?? 0.75;
      _sfxVolume = prefs.getDouble('setting_sfxVolume') ?? 0.90;
      AudioService().musicVolume = _musicVolume;
      AudioService().sfxVolume = _sfxVolume;
      _vibrationEnabled = prefs.getBool('setting_vibration') ?? true;
      _colorBlindMode = prefs.getBool('setting_colorBlind') ?? false;
      _reducedMotion = prefs.getBool('setting_reducedMotion') ?? false;
      final qIndex = prefs.getInt('setting_graphicsQuality');
      if (qIndex != null && qIndex >= 0 && qIndex < GraphicsQuality.values.length) {
        _graphicsQuality = GraphicsQuality.values[qIndex];
      }
      _language = prefs.getString('setting_language') ?? 'English';
      _cachedStrings = AppStrings(_language);
      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      // In tests or non-shared_preferences environments, keep defaults
    }
  }

  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _saveSettings();
    });
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await Future.wait([
        prefs.setDouble('setting_musicVolume', _musicVolume),
        prefs.setDouble('setting_sfxVolume', _sfxVolume),
        prefs.setBool('setting_vibration', _vibrationEnabled),
        prefs.setBool('setting_colorBlind', _colorBlindMode),
        prefs.setBool('setting_reducedMotion', _reducedMotion),
        prefs.setInt('setting_graphicsQuality', _graphicsQuality.index),
        prefs.setString('setting_language', _language),
      ]);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_saveDebounceTimer?.isActive ?? false) {
      _saveDebounceTimer!.cancel();
      _saveSettings();
    }
    super.dispose();
  }
}
