#!/usr/bin/env python3
"""Writes the reminder tones in five loudness levels.

Each tone exists as <name>.wav (level 4, the default) plus <name>_p1, _p2, _p3
and _p5. Loudness is baked into the files, so the chosen power works the same
through the Android playback service, the Android fallback notification
channel and iPhone notification sounds, none of which share a volume control.
The old tones peaked at -16.5 dBFS on a 660 Hz sine, which small phone
speakers barely reproduce; these sit between 1 and 3 kHz.

Run from the repository root:  python3 tools/make_tones.py
"""
import math
import shutil
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "asset"
RAW = ROOT / "android/app/src/main/res/raw"
RATE = 22050
LEVELS = (1, 2, 3, 4, 5)
DEFAULT_LEVEL = 4
# peak amplitude and how many overtones each level carries
PEAK = {1: 0.11, 2: 0.26, 3: 0.52, 4: 0.89, 5: 0.97}
RICHNESS = {1: 0.0, 2: 0.35, 3: 0.7, 4: 1.0, 5: 1.0}

# name, seconds, notes as (start, length, hertz), decay per second
TONES = {
    "beep": (0.50, [(0.0, 0.42, 1046.5)], 0.0),
    "double_beep": (0.70, [(0.0, 0.24, 1046.5), (0.38, 0.24, 1046.5)], 0.0),
    "chime": (1.60, [(0.0, 1.5, 1046.5), (0.22, 1.3, 1568.0)], 2.6),
    "strong_beep": (1.10, [(0.0, 0.2, 2093.0), (0.3, 0.2, 2093.0), (0.6, 0.34, 2637.0)], 0.0),
}


def tone_name(name, level):
    return name if level == DEFAULT_LEVEL else f"{name}_p{level}"


def render(name, level):
    seconds, notes, decay = TONES[name]
    rich = RICHNESS[level]
    samples = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        value = 0.0
        for start, length, hertz in notes:
            local = t - start
            if 0 <= local < length:
                envelope = min(1.0, local / 0.008, (length - local) / 0.05)
                if decay:
                    envelope *= math.exp(-decay * local)
                phase = 2 * math.pi * hertz * local
                value += envelope * (math.sin(phase) + rich * (0.45 * math.sin(2 * phase) + 0.22 * math.sin(3 * phase)))
        samples.append(value)
    top = max(abs(v) for v in samples) or 1.0
    samples = [v / top for v in samples]
    if level == 5:  # gentle saturation: denser, so louder at the same peak
        drive = 2.4
        samples = [math.tanh(drive * v) / math.tanh(drive) for v in samples]
    return [v * PEAK[level] for v in samples]


def write(path, samples):
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples))


def main():
    for name in TONES:
        for level in LEVELS:
            target = ASSET / f"{tone_name(name, level)}.wav"
            samples = render(name, level)
            write(target, samples)
            shutil.copyfile(target, RAW / target.name)
            rms = math.sqrt(sum(v * v for v in samples) / len(samples))
            print(f"{target.name:22} peak {20 * math.log10(max(abs(v) for v in samples)):6.1f} dBFS  "
                  f"rms {20 * math.log10(rms):6.1f} dBFS  {len(samples) / RATE:.2f}s")


if __name__ == "__main__":
    main()
