/// Audio service wrapping the `audioplayers` package.
///
/// Exposes simple fire-and-forget methods. Actual audio files are expected
/// at the paths below — the user will drop them in manually.
library;
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // ─── Players ──────────────────────────────────────────────────────────────
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxShoot = AudioPlayer();
  final AudioPlayer _sfxHit = AudioPlayer();
  final AudioPlayer _sfxGameOver = AudioPlayer();

  // ─── Asset paths ──────────────────────────────────────────────────────────
  static const String _bgmPath = 'audio/bgm.wav';
  static const String _shootPath = 'audio/shoot.wav';
  static const String _hitPath = 'audio/hit.wav';
  static const String _gameOverPath = 'audio/gameover.wav';

  // ─── Volume (0.0 – 1.0) ──────────────────────────────────────────────────
  double _musicVolume = 0.7;
  double _sfxVolume = 0.8;

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  double _lastHitPitch = 1.0;

  AudioService() {
    _sfxShoot.setPlayerMode(PlayerMode.lowLatency);
    _sfxHit.setPlayerMode(PlayerMode.lowLatency);
    _sfxShoot.setVolume(_sfxVolume);
    _sfxHit.setVolume(_sfxVolume);
    _sfxGameOver.setVolume(_sfxVolume);
  }

  set musicVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if ((_musicVolume - clamped).abs() < 0.001) return;
    _musicVolume = clamped;
    _bgmPlayer.setVolume(_musicVolume);
  }

  set sfxVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if ((_sfxVolume - clamped).abs() < 0.001) return;
    _sfxVolume = clamped;
    _sfxShoot.setVolume(_sfxVolume);
    _sfxHit.setVolume(_sfxVolume);
    _sfxGameOver.setVolume(_sfxVolume);
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  Future<void> playBGM() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_musicVolume);
      await _bgmPlayer.play(AssetSource(_bgmPath));
    } catch (_) {
      // Asset may not exist yet — silently ignore.
    }
  }

  Future<void> stopBGM() async {
    await _bgmPlayer.stop();
  }

  void playShootSound() {
    try {
      _sfxShoot.play(AssetSource(_shootPath));
    } catch (_) {}
  }

  /// Play the hit sound with an increasing pitch based on [combo] count.
  void playHitSound(int combo) {
    try {
      // Pitch rises from 1.0 to 2.0 over 10 combos.
      final pitch = 1.0 + (combo.clamp(0, 10) * 0.1);
      if ((_lastHitPitch - pitch).abs() > 0.01) {
        _lastHitPitch = pitch;
        _sfxHit.setPlaybackRate(pitch);
      }
      _sfxHit.play(AssetSource(_hitPath));
    } catch (_) {}
  }

  void playGameOverSound() {
    try {
      _sfxGameOver.play(AssetSource(_gameOverPath));
    } catch (_) {}
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sfxShoot.dispose();
    _sfxHit.dispose();
    _sfxGameOver.dispose();
  }
}
