import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

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
  bool _isLoaded = false;

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
  AppStrings get strings => AppStrings(_language);
  bool get isTurkish => _language == 'Türkçe';

  // ─── Setters ──────────────────────────────────────────────────────────────
  set musicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    notifyListeners();
    _saveSettings();
  }

  set sfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
    notifyListeners();
    _saveSettings();
  }

  set vibrationEnabled(bool v) {
    _vibrationEnabled = v;
    notifyListeners();
    _saveSettings();
  }

  set colorBlindMode(bool v) {
    _colorBlindMode = v;
    notifyListeners();
    _saveSettings();
  }

  set reducedMotion(bool v) {
    _reducedMotion = v;
    notifyListeners();
    _saveSettings();
  }

  set graphicsQuality(GraphicsQuality q) {
    _graphicsQuality = q;
    notifyListeners();
    _saveSettings();
  }

  set language(String lang) {
    _language = lang;
    notifyListeners();
    _saveSettings();
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
      _musicVolume = prefs.getDouble('setting_musicVolume') ?? 0.75;
      _sfxVolume = prefs.getDouble('setting_sfxVolume') ?? 0.90;
      _vibrationEnabled = prefs.getBool('setting_vibration') ?? true;
      _colorBlindMode = prefs.getBool('setting_colorBlind') ?? false;
      _reducedMotion = prefs.getBool('setting_reducedMotion') ?? false;
      final qIndex = prefs.getInt('setting_graphicsQuality');
      if (qIndex != null && qIndex >= 0 && qIndex < GraphicsQuality.values.length) {
        _graphicsQuality = GraphicsQuality.values[qIndex];
      }
      _language = prefs.getString('setting_language') ?? 'English';
      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      // In tests or non-shared_preferences environments, keep defaults
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('setting_musicVolume', _musicVolume);
      await prefs.setDouble('setting_sfxVolume', _sfxVolume);
      await prefs.setBool('setting_vibration', _vibrationEnabled);
      await prefs.setBool('setting_colorBlind', _colorBlindMode);
      await prefs.setBool('setting_reducedMotion', _reducedMotion);
      await prefs.setInt('setting_graphicsQuality', _graphicsQuality.index);
      await prefs.setString('setting_language', _language);
    } catch (_) {}
  }
}
