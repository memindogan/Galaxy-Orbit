/// Audio service wrapping the `audioplayers` package.
///
/// Features:
///  - Explicit per-player AudioContext with AndroidAudioFocus.none so SFX never interrupts BGM.
///  - Pre-runApp global context configuration so native Kotlin initializes with audioFocus=NONE.
///  - Player pools for rapid shoot and hit SFX without stream locks.
///  - Active watchdog on BGM state to auto-resume if any platform event pauses it unexpectedly.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  // ─── Shared AudioContext ──────────────────────────────────────────────────
  static final AudioContext gameAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
  );

  static bool _globalConfigured = false;

  /// Call once at app startup before runApp.
  static Future<void> configureGlobalContext() async {
    if (_globalConfigured) return;
    _globalConfigured = true;
    try {
      await AudioPlayer.global.setAudioContext(gameAudioContext);
    } catch (_) {}
  }

  // ─── Players ──────────────────────────────────────────────────────────────
  late final AudioPlayer _bgmPlayer;
  late final List<AudioPlayer> _shootPool;
  late final List<AudioPlayer> _hitPool;
  late final List<AudioPlayer> _gameOverPool;

  int _shootIndex = 0;
  int _hitIndex = 0;
  int _gameOverIndex = 0;
  bool _bgmShouldPlay = false;
  bool _isPaused = false;
  bool _isTransitioningBgm = false;
  bool _isDisposed = false;

  // ─── Asset paths & Pre-cached Sources ─────────────────────────────────────
  static const String _bgmPath = 'audio/bgm.wav';
  static const String _shootPath = 'audio/shoot.wav';
  static const String _hitPath = 'audio/hit.wav';
  static const String _gameOverPath = 'audio/gameover.wav';

  static final Source _bgmSource = AssetSource(_bgmPath);
  static final Source _shootSource = AssetSource(_shootPath);
  static final Source _hitSource = AssetSource(_hitPath);
  static final Source _gameOverSource = AssetSource(_gameOverPath);

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  // ─── Volume (0.0 – 1.0) ──────────────────────────────────────────────────
  double _musicVolume = 0.7;
  double _sfxVolume = 0.8;

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  static AudioService? _instance;
  factory AudioService() => _instance ??= AudioService._internal();

  AudioService._internal() {
    configureGlobalContext();

    _bgmPlayer = AudioPlayer(playerId: 'bgm_player');
    _shootPool = [
      AudioPlayer(playerId: 'shoot_0'),
      AudioPlayer(playerId: 'shoot_1'),
      AudioPlayer(playerId: 'shoot_2'),
    ];
    _hitPool = [
      AudioPlayer(playerId: 'hit_0'),
      AudioPlayer(playerId: 'hit_1'),
      AudioPlayer(playerId: 'hit_2'),
    ];
    _gameOverPool = [
      AudioPlayer(playerId: 'game_over_0'),
      AudioPlayer(playerId: 'game_over_1'),
    ];

    _initPlayers();
    _listenBgm();
  }

  void _initPlayers() {
    // Explicitly configure each player with AndroidAudioFocus.none so SFX never interrupts BGM
    _bgmPlayer.setAudioContext(gameAudioContext);
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _bgmPlayer.setVolume(_musicVolume);

    for (final p in _shootPool) {
      p.setAudioContext(gameAudioContext);
      p.setPlayerMode(PlayerMode.mediaPlayer);
      p.setVolume(_sfxVolume);
    }
    for (final p in _hitPool) {
      p.setAudioContext(gameAudioContext);
      p.setPlayerMode(PlayerMode.mediaPlayer);
      p.setVolume(_sfxVolume);
    }
    for (final p in _gameOverPool) {
      p.setAudioContext(gameAudioContext);
      p.setPlayerMode(PlayerMode.mediaPlayer);
      p.setVolume(_sfxVolume);
    }
  }

  void _listenBgm() {
    _stateSub?.cancel();
    _completeSub?.cancel();

    // Active auto-resume watchdog: if native Android or an SFX ever pauses BGM, resume immediately.
    _stateSub = _bgmPlayer.onPlayerStateChanged.listen((state) {
      if (_isDisposed || _isTransitioningBgm) return;
      if (_bgmShouldPlay && !_isPaused && _musicVolume > 0.001 &&
          (state == PlayerState.paused || state == PlayerState.stopped)) {
        _bgmPlayer.resume().catchError((_) {});
      }
    });

    // Loop fail-safe: if loop mode doesn't cycle on a specific device, replay on complete.
    _completeSub = _bgmPlayer.onPlayerComplete.listen((_) {
      if (_isDisposed || _isTransitioningBgm) return;
      if (_bgmShouldPlay && !_isPaused) {
        _bgmPlayer.play(_bgmSource).catchError((_) {});
      }
    });
  }

  set musicVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if ((_musicVolume - clamped).abs() < 0.001) return;
    _musicVolume = clamped;
    _bgmPlayer.setVolume(_musicVolume);
    if (_musicVolume > 0.001) {
      if (_bgmShouldPlay && !_isPaused && _bgmPlayer.state != PlayerState.playing) {
        _bgmPlayer.resume().catchError((_) => playBGM());
      }
    }
  }

  set sfxVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if ((_sfxVolume - clamped).abs() < 0.001) return;
    _sfxVolume = clamped;
    for (final p in _shootPool) {
      p.setVolume(_sfxVolume);
    }
    for (final p in _hitPool) {
      p.setVolume(_sfxVolume);
    }
    for (final p in _gameOverPool) {
      p.setVolume(_sfxVolume);
    }
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  Future<void> playBGM() async {
    if (_isDisposed) return;
    _bgmShouldPlay = true;
    _isPaused = false;
    if (_musicVolume <= 0.001) {
      _bgmPlayer.setVolume(0.0);
      return;
    }
    if (_isTransitioningBgm) return;
    _isTransitioningBgm = true;
    try {
      if (_bgmPlayer.state == PlayerState.playing) return;
      await _bgmPlayer.setAudioContext(gameAudioContext);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_musicVolume);
      await _bgmPlayer.play(_bgmSource);
    } catch (_) {
      // Asset may not exist yet — silently ignore.
    } finally {
      _isTransitioningBgm = false;
    }
  }

  Future<void> pauseBGM() async {
    if (_isDisposed) return;
    _isPaused = true;
    try {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
    } catch (_) {}
  }

  Future<void> resumeBGM() async {
    if (_isDisposed || !_bgmShouldPlay) return;
    _isPaused = false;
    if (_musicVolume <= 0.001) return;
    try {
      if (_bgmPlayer.state == PlayerState.paused) {
        await _bgmPlayer.resume();
      } else if (_bgmPlayer.state != PlayerState.playing) {
        await playBGM();
      }
    } catch (_) {}
  }

  Future<void> stopBGM() async {
    if (_isDisposed) return;
    _bgmShouldPlay = false;
    _isPaused = false;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  void playShootSound() {
    if (_isDisposed || _sfxVolume <= 0.001) return;
    try {
      final player = _shootPool[_shootIndex];
      _shootIndex = (_shootIndex + 1) % _shootPool.length;
      player.play(
        _shootSource,
        volume: _sfxVolume,
        mode: PlayerMode.mediaPlayer,
      ).catchError((_) {});
    } catch (_) {}
  }

  /// Play the hit sound on orbit capture using the round-robin hit pool with dynamic combo pitch.
  void playHitSound([int combo = 0]) {
    if (_isDisposed || _sfxVolume <= 0.001) return;
    try {
      final player = _hitPool[_hitIndex];
      _hitIndex = (_hitIndex + 1) % _hitPool.length;
      final pitch = (1.0 + (combo.clamp(0, 10) * 0.05)).clamp(1.0, 1.5);
      player.setPlaybackRate(pitch).catchError((_) {});
      player.play(
        _hitSource,
        volume: _sfxVolume,
        mode: PlayerMode.mediaPlayer,
      ).catchError((_) {});
    } catch (_) {}
  }

  void playGameOverSound() {
    if (_isDisposed || _sfxVolume <= 0.001) return;
    try {
      final player = _gameOverPool[_gameOverIndex];
      _gameOverIndex = (_gameOverIndex + 1) % _gameOverPool.length;
      player.play(
        _gameOverSource,
        volume: _sfxVolume,
        mode: PlayerMode.mediaPlayer,
      ).catchError((_) {});
    } catch (e) {
      debugPrint('Error playing game over sound: $e');
    }
  }

  void dispose() {
    _isDisposed = true;
    _bgmShouldPlay = false;
    _stateSub?.cancel();
    _completeSub?.cancel();
    _bgmPlayer.dispose();
    for (final p in _shootPool) {
      p.dispose();
    }
    for (final p in _hitPool) {
      p.dispose();
    }
    for (final p in _gameOverPool) {
      p.dispose();
    }
    _instance = null;
  }
}
