"""
Neon Orbit — Procedural Audio Generator
Generates all game audio assets using pure math synthesis.
No external dependencies — uses only Python's built-in `wave` and `struct`.

Output:
  assets/audio/shoot.wav    — Rising pitch laser sweep
  assets/audio/hit.wav      — Positive chime with harmonics
  assets/audio/gameover.wav — Descending dramatic tones
  assets/audio/bgm.wav      — Loopable synthwave arpeggio BGM
"""

import wave
import struct
import math
import os
import random

SAMPLE_RATE = 44100
MAX_AMP = 32767  # 16-bit signed

def save_wav(filename: str, samples: list[float], sample_rate: int = SAMPLE_RATE):
    """Save a list of float samples [-1.0, 1.0] to a 16-bit mono WAV file."""
    path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', filename)
    os.makedirs(os.path.dirname(path), exist_ok=True)

    with wave.open(path, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)

        data = b''
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            packed = struct.pack('<h', int(clamped * MAX_AMP))
            data += packed

        wf.writeframes(data)

    print(f"  ✓ {filename} ({len(samples) / sample_rate:.2f}s, {os.path.getsize(path)} bytes)")


def sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def square(freq: float, t: float) -> float:
    return 1.0 if sine(freq, t) >= 0 else -1.0


def saw(freq: float, t: float) -> float:
    phase = (freq * t) % 1.0
    return 2.0 * phase - 1.0


def triangle(freq: float, t: float) -> float:
    phase = (freq * t) % 1.0
    return 4.0 * abs(phase - 0.5) - 1.0


def noise() -> float:
    return random.uniform(-1.0, 1.0)


def envelope_adsr(t: float, duration: float,
                  attack: float = 0.01, decay: float = 0.05,
                  sustain_level: float = 0.7, release: float = 0.1) -> float:
    """Standard ADSR envelope."""
    sustain_end = duration - release
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack
    if t < attack + decay:
        return 1.0 - (1.0 - sustain_level) * ((t - attack) / decay)
    if t < sustain_end:
        return sustain_level
    if t < duration:
        return sustain_level * (1.0 - (t - sustain_end) / release)
    return 0.0


def fade_out(samples: list[float], fade_samples: int) -> list[float]:
    """Apply a linear fade-out to the last `fade_samples` of the list."""
    result = list(samples)
    start = len(result) - fade_samples
    for i in range(fade_samples):
        ratio = 1.0 - (i / fade_samples)
        result[start + i] *= ratio
    return result


# ─────────────────────────────────────────────────────────────────────────────
# SHOOT SOUND — Rising pitch laser sweep with harmonic tail
# ─────────────────────────────────────────────────────────────────────────────
def generate_shoot():
    duration = 0.25
    n = int(SAMPLE_RATE * duration)
    samples = []

    for i in range(n):
        t = i / SAMPLE_RATE
        progress = t / duration

        # Frequency sweeps up from 300Hz to 2000Hz
        freq = 300 + 1700 * (progress ** 0.5)

        # Mix sine + slight square for edge
        val = sine(freq, t) * 0.7 + square(freq * 2, t) * 0.15 + noise() * 0.03

        # Fast decay envelope
        env = envelope_adsr(t, duration, attack=0.005, decay=0.03,
                            sustain_level=0.5, release=0.08)

        samples.append(val * env * 0.8)

    save_wav('shoot.wav', samples)


# ─────────────────────────────────────────────────────────────────────────────
# HIT SOUND — Bright positive chime (perfect fifth + octave harmonics)
# ─────────────────────────────────────────────────────────────────────────────
def generate_hit():
    duration = 0.35
    n = int(SAMPLE_RATE * duration)
    samples = []

    base_freq = 880.0  # A5

    for i in range(n):
        t = i / SAMPLE_RATE

        # Layered harmonics for a rich chime
        val = (
            sine(base_freq, t) * 0.4 +
            sine(base_freq * 1.5, t) * 0.25 +      # perfect fifth
            sine(base_freq * 2.0, t) * 0.15 +       # octave
            triangle(base_freq * 3.0, t) * 0.08 +   # high shimmer
            noise() * 0.02
        )

        env = envelope_adsr(t, duration, attack=0.003, decay=0.08,
                            sustain_level=0.3, release=0.15)

        samples.append(val * env * 0.85)

    save_wav('hit.wav', samples)


# ─────────────────────────────────────────────────────────────────────────────
# GAME OVER SOUND — Descending dramatic tones with rumble
# ─────────────────────────────────────────────────────────────────────────────
def generate_gameover():
    duration = 1.5
    n = int(SAMPLE_RATE * duration)
    samples = []

    for i in range(n):
        t = i / SAMPLE_RATE
        progress = t / duration

        # Three descending tones in sequence
        if t < 0.4:
            freq = 440.0  # A4
            local_t = t
            local_dur = 0.4
        elif t < 0.8:
            freq = 349.23  # F4
            local_t = t - 0.4
            local_dur = 0.4
        else:
            freq = 220.0  # A3 — ominous low
            local_t = t - 0.8
            local_dur = 0.7

        # Slight downward pitch bend within each note
        freq *= (1.0 - 0.02 * (local_t / local_dur))

        val = (
            sine(freq, t) * 0.35 +
            saw(freq, t) * 0.2 +
            square(freq * 0.5, t) * 0.15 +   # sub-octave rumble
            noise() * 0.04
        )

        env = envelope_adsr(local_t, local_dur, attack=0.01, decay=0.1,
                            sustain_level=0.6, release=0.2)

        # Global fade out
        global_fade = 1.0 - progress * 0.3

        samples.append(val * env * global_fade * 0.75)

    # Extra fade-out at the end
    samples = fade_out(samples, int(SAMPLE_RATE * 0.3))
    save_wav('gameover.wav', samples)


# ─────────────────────────────────────────────────────────────────────────────
# BGM — Loopable synthwave arpeggio (≈16 seconds loop)
# ─────────────────────────────────────────────────────────────────────────────
def generate_bgm():
    bpm = 128
    beat_duration = 60.0 / bpm  # seconds per beat
    bars = 8
    beats_per_bar = 4
    total_beats = bars * beats_per_bar
    duration = total_beats * beat_duration
    n = int(SAMPLE_RATE * duration)

    # Synthwave arpeggio pattern (minor scale, neon vibe)
    # Am - F - C - G progression, each bar = 1 chord
    chord_progression = [
        # Am (A3, C4, E4)
        [220.00, 261.63, 329.63],
        # F (F3, A3, C4)
        [174.61, 220.00, 261.63],
        # C (C3, E3, G3)
        [130.81, 164.81, 196.00],
        # G (G3, B3, D4)
        [196.00, 246.94, 293.66],
        # Am
        [220.00, 261.63, 329.63],
        # Dm (D3, F3, A3)
        [146.83, 174.61, 220.00],
        # F
        [174.61, 220.00, 261.63],
        # E (E3, G#3, B3) — tension before loop
        [164.81, 207.65, 246.94],
    ]

    samples = []

    for i in range(n):
        t = i / SAMPLE_RATE
        beat = t / beat_duration
        bar = int(beat / beats_per_bar) % bars
        beat_in_bar = beat % beats_per_bar

        chord = chord_progression[bar]

        # ── Layer 1: Arpeggio (16th notes cycling through chord tones) ──
        sixteenth = int(beat * 4) % len(chord)
        arp_freq = chord[sixteenth] * 2  # Octave up for brightness

        # Soft attack/release per arpeggio note
        note_phase = (beat * 4) % 1.0
        arp_env = 0.0
        if note_phase < 0.1:
            arp_env = note_phase / 0.1
        elif note_phase < 0.7:
            arp_env = 1.0 - 0.3 * ((note_phase - 0.1) / 0.6)
        else:
            arp_env = 0.7 * (1.0 - (note_phase - 0.7) / 0.3)

        arp = triangle(arp_freq, t) * 0.22 * arp_env

        # ── Layer 2: Bass (root note, sub-octave) ──
        bass_freq = chord[0] * 0.5
        bass_env_phase = beat_in_bar % 1.0
        bass_env = 1.0 if bass_env_phase < 0.5 else max(0.0, 1.0 - (bass_env_phase - 0.5) * 3)
        bass = (sine(bass_freq, t) * 0.6 + square(bass_freq, t) * 0.15) * 0.2 * bass_env

        # ── Layer 3: Pad (sustained chord, filtered) ──
        pad = 0.0
        for note_freq in chord:
            pad += sine(note_freq, t) * 0.06
            pad += sine(note_freq * 2, t) * 0.02  # light shimmer

        # Slow volume swell on pad
        pad_swell = 0.7 + 0.3 * sine(0.25, t)
        pad *= pad_swell

        # ── Layer 4: Hi-hat pattern (noise bursts on 8th notes) ──
        eighth_phase = (beat * 2) % 1.0
        hihat = 0.0
        if eighth_phase < 0.05:
            hihat = noise() * 0.06 * (1.0 - eighth_phase / 0.05)

        # ── Layer 5: Kick-like thump on beats 1 and 3 ──
        kick = 0.0
        beat_phase = beat % 1.0
        if (int(beat) % 2 == 0) and beat_phase < 0.08:
            kick_progress = beat_phase / 0.08
            kick_freq = 80 * (1.0 - kick_progress * 0.7)
            kick = sine(kick_freq, t) * 0.25 * (1.0 - kick_progress)

        # ── Mix ──
        val = arp + bass + pad + hihat + kick

        # Soft limiter
        val = max(-0.9, min(0.9, val))

        samples.append(val * 0.85)

    # Crossfade loop point (fade last 0.5s into first 0.5s for seamless loop)
    crossfade_samples = int(SAMPLE_RATE * 0.5)
    for i in range(crossfade_samples):
        ratio = i / crossfade_samples
        samples[i] = samples[i] * ratio + samples[-(crossfade_samples - i)] * (1.0 - ratio)

    # Trim the tail that was blended
    samples = samples[:n - crossfade_samples]

    save_wav('bgm.wav', samples)


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    random.seed(42)  # deterministic noise
    print("🎵 Generating Neon Orbit audio assets...\n")
    generate_shoot()
    generate_hit()
    generate_gameover()
    generate_bgm()
    print("\n✅ All audio assets generated successfully!")
