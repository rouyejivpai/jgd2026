#!/usr/bin/env python3
"""Create deterministic 44.1 kHz / 16-bit placeholder sound effects with numpy."""
from __future__ import annotations

import argparse
import math
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "sfx"

SOUND_IDS = [
    "ui_click", "ui_hover", "ui_toggle", "ui_error", "ui_drag_pick", "ui_drag_drop",
    "deploy_place", "deploy_remove", "battle_start",
    "attack_striker", "attack_bulwark", "attack_swift", "attack_lancer",
    "enemy_bite", "enemy_brute", "spitter_charge", "core_pulse", "priest_whisper",
    "blast_warn_tick", "blast_detonate", "hit_flesh", "hit_bone",
    "death_ally", "death_enemy", "death_priest", "death_core",
    "structure_hit", "structure_destroyed", "timer_tick", "hint_open",
    "dialogue_advance", "amb_wind", "amb_greenhouse",
]
# Kenney-sourced IDs are generated/copied by the asset pipeline separately.
SYNTH_IDS = [
    "deploy_remove", "attack_striker", "attack_swift", "attack_lancer", "enemy_bite",
    "spitter_charge", "core_pulse", "priest_whisper", "blast_detonate", "death_ally",
    "death_enemy", "death_priest", "death_core", "structure_destroyed", "amb_wind",
    "amb_greenhouse",
]
RATE = 44100
TARGET_PEAK = 0.45  # -6.94 dBFS, leaving headroom for quantization.


def env(n: int, attack: float = 0.004, release: float = 0.08) -> np.ndarray:
    x = np.ones(n, dtype=np.float32)
    a = min(n, max(1, int(attack * RATE)))
    r = min(n, max(1, int(release * RATE)))
    x[:a] = np.linspace(0.0, 1.0, a, dtype=np.float32)
    x[-r:] *= np.linspace(1.0, 0.0, r, dtype=np.float32)
    return x


def tone(freq: float | np.ndarray, n: int, decay: float = 7.0, phase: float = 0.0) -> np.ndarray:
    t = np.arange(n, dtype=np.float32) / RATE
    f = np.full(n, freq, dtype=np.float32) if np.isscalar(freq) else np.asarray(freq, dtype=np.float32)
    return (np.sin(phase + 2 * np.pi * np.cumsum(f) / RATE) * np.exp(-decay * t)).astype(np.float32)


def shaped_noise(n: int, rng: np.random.Generator, cutoff: float = 1600.0) -> np.ndarray:
    raw = rng.standard_normal(n).astype(np.float32)
    spec = np.fft.rfft(raw)
    hz = np.fft.rfftfreq(n, 1.0 / RATE)
    spec *= (1.0 / np.sqrt(1.0 + (hz / cutoff) ** 4)).astype(np.float32)
    filtered = np.fft.irfft(spec, n).astype(np.float32)
    peak = float(np.max(np.abs(filtered))) or 1.0
    return filtered / peak


def join(parts: list[np.ndarray], gap: float = 0.025) -> np.ndarray:
    silence = np.zeros(int(gap * RATE), dtype=np.float32)
    return np.concatenate([piece for i, part in enumerate(parts) for piece in (([silence] if i else []) + [part])])


def synth(sound_id: str) -> np.ndarray:
    seeds = {name: i + 410 for i, name in enumerate(SOUND_IDS)}
    rng = np.random.default_rng(seeds[sound_id])

    if sound_id in {"amb_wind", "amb_greenhouse"}:
        seconds = 25 if sound_id == "amb_wind" else 30
        n = seconds * RATE
        noise = shaped_noise(n, rng, 520 if sound_id == "amb_wind" else 1100)
        t = np.arange(n, dtype=np.float32) / RATE
        slow = 0.62 + 0.18 * np.sin(2 * np.pi * t / (12.5 if sound_id == "amb_wind" else 8.7))
        signal = noise * slow
        if sound_id == "amb_wind":
            signal += 0.18 * tone(72.0, n, decay=0.0) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 17.0))
        else:
            for center, freq in ((5.4, 490), (14.2, 620), (22.7, 530)):
                idx = int(center * RATE)
                length = int(0.42 * RATE)
                signal[idx:idx + length] += 0.14 * tone(np.linspace(freq * 1.18, freq, length), length, decay=5.5)
        # Join the tail and head once, then remove the overlapped samples. The
        # crossfade stays at full ambience level, so playback never fades up
        # from silence each time the loop restarts.
        edge = int(0.12 * RATE)
        phase = np.linspace(0, np.pi / 2, edge, endpoint=True, dtype=np.float32)
        seam = signal[-edge:] * np.cos(phase) + signal[:edge] * np.sin(phase)
        signal = np.concatenate((seam, signal[edge:-edge]))
        return signal.astype(np.float32)

    durations = {
        "ui_hover": .18, "ui_error": .28, "ui_drag_pick": .25, "ui_drag_drop": .24,
        "deploy_remove": .52, "attack_striker": .28, "attack_swift": .22,
        "attack_lancer": .36, "enemy_bite": .34, "spitter_charge": .58,
        "core_pulse": .72, "priest_whisper": .95, "blast_detonate": .68,
        "death_ally": .7, "death_enemy": .8, "death_priest": 1.2,
        "death_core": 1.5, "structure_destroyed": 1.0,
    }
    n = int(durations.get(sound_id, .22) * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    e = env(n, release=min(.35, n / RATE * .7))
    noise = shaped_noise(n, rng, 1800 if "whisper" in sound_id or "priest" in sound_id else 1200)

    if sound_id == "ui_hover":
        y = noise * env(n, .01, .13) * .23
    elif sound_id == "ui_error":
        y = .38 * tone(np.linspace(410, 260, n), n, 4.2) + .12 * tone(np.linspace(318, 205, n), n, 4.8)
    elif sound_id == "ui_drag_pick":
        y = .2 * noise * e + .28 * tone(np.linspace(240, 520, n), n, 10)
    elif sound_id == "ui_drag_drop":
        y = .42 * tone(np.linspace(180, 95, n), n, 14) + .17 * noise * e
    elif sound_id == "deploy_remove":
        ramp = np.sin(np.linspace(0, np.pi / 2, n, dtype=np.float32)) ** 2
        y = .25 * noise * ramp + .12 * tone(np.linspace(100, 165, n), n, 1.7) * ramp
    elif sound_id == "attack_striker":
        sweep = tone(np.linspace(780, 240, n), n, 10)
        y = .32 * noise * np.exp(-13 * t) + .38 * sweep * np.exp(-12 * t)
    elif sound_id == "attack_swift":
        y = .46 * noise * env(n, .002, .08) * np.linspace(1, .08, n, dtype=np.float32)
    elif sound_id == "attack_lancer":
        y = .28 * noise * np.exp(-8 * t) + .28 * tone(np.linspace(960, 310, n), n, 7)
    elif sound_id == "enemy_bite":
        bursts = np.zeros(n, dtype=np.float32)
        for pos, amp in ((.035, .34), (.12, .24), (.21, .14)):
            start = int(pos * RATE)
            end = min(n, start + int(.045 * RATE))
            bursts[start:end] += amp * noise[:end-start] * np.exp(-45 * np.arange(end-start) / RATE)
        y = bursts + .32 * tone(np.linspace(90, 48, n), n, 8) + .1 * noise * e
    elif sound_id == "spitter_charge":
        swell = np.sin(np.linspace(0, np.pi / 2, n, dtype=np.float32)) ** 2
        y = .26 * noise * swell + .12 * tone(np.linspace(55, 100, n), n, 1.2) * swell
    elif sound_id == "core_pulse":
        pulse1 = tone(np.linspace(75, 43, n), n, 5)
        pulse2 = np.roll(tone(np.linspace(68, 39, n), n, 5), int(.24 * RATE))
        y = .42 * pulse1 + .19 * pulse2 + .05 * noise * e
    elif sound_id == "priest_whisper":
        slow = .5 + .5 * np.sin(2 * np.pi * 5.7 * t)
        y = .22 * noise * slow * e + .06 * tone(164, n, 0.4) * e
    elif sound_id == "blast_detonate":
        y = .5 * tone(np.linspace(84, 34, n), n, 5) + .42 * noise * np.exp(-6.5 * t) + .16 * tone(390, n, 18)
    elif sound_id == "death_ally":
        y = .26 * noise * np.exp(-6 * t) + .25 * tone(np.linspace(410, 155, n), n, 6)
    elif sound_id == "death_enemy":
        y = .32 * tone(np.linspace(130, 53, n), n, 3.5) + .22 * noise * e
    elif sound_id == "death_priest":
        y = .22 * noise * np.sin(np.linspace(0, np.pi, n, dtype=np.float32)) + .14 * tone(np.linspace(480, 110, n), n, 1.6)
    elif sound_id == "death_core":
        y = .42 * tone(np.linspace(130, 32, n), n, 3) + .22 * noise * np.exp(-2.6 * t)
    elif sound_id == "structure_destroyed":
        y = .42 * tone(np.linspace(145, 48, n), n, 3.2) + .22 * noise * np.exp(-4.0 * t)
        for pos in (.18, .47, .7):
            idx = int(pos * RATE)
            burst_n = min(int(.08 * RATE), n - idx)
            y[idx:idx + burst_n] += .22 * noise[:burst_n]
    else:
        # Short clicks, ticks and little bone-like knocks.
        y = .32 * tone(np.linspace(620, 190, n), n, 16) + .18 * noise * np.exp(-22 * t)
    return np.asarray(y, dtype=np.float32)


def write_wav(sound_id: str, signal: np.ndarray) -> tuple[Path, float]:
    OUT.mkdir(parents=True, exist_ok=True)
    peak = float(np.max(np.abs(signal))) if signal.size else 0.0
    if peak > TARGET_PEAK:
        signal = signal * (TARGET_PEAK / peak)
    pcm = np.clip(signal, -1.0, 1.0)
    pcm16 = np.round(pcm * 32767).astype("<i2")
    path = OUT / f"{sound_id}.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm16.tobytes())
    actual_peak = float(np.max(np.abs(pcm16))) / 32768 if pcm16.size else 0.0
    return path, actual_peak


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ids", nargs="*", choices=SOUND_IDS, help="only synthesize these IDs; default: unsourced IDs")
    args = parser.parse_args()
    ids = args.ids or SYNTH_IDS
    for sound_id in ids:
        signal = synth(sound_id)
        path, peak = write_wav(sound_id, signal)
        dbfs = 20 * math.log10(max(peak, 1e-12))
        print(f"{path.relative_to(ROOT).as_posix()} samples={len(signal)} peak={peak:.4f} ({dbfs:.2f} dBFS)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
