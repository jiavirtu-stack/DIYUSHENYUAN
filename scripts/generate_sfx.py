"""Create original, dependency-free prototype combat sounds as 16-bit WAV."""
import math
import random
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)


def write(name, duration, sample_fn):
    count = int(RATE * duration)
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        data = bytearray()
        for i in range(count):
            t = i / RATE
            value = max(-1.0, min(1.0, sample_fn(t, duration)))
            data += int(value * 32767).to_bytes(2, "little", signed=True)
        wav.writeframes(data)


def swing(t, duration):
    progress = t / duration
    envelope = math.sin(math.pi * progress) ** 1.5
    noise = random.Random(int(t * RATE)).uniform(-1.0, 1.0)
    return envelope * (0.30 * noise + 0.22 * math.sin(2 * math.pi * (900 - 520 * progress) * t))


def hit_light(t, duration):
    envelope = math.exp(-t * 28.0)
    return envelope * (0.54 * math.sin(2 * math.pi * (180 - 90 * t / duration) * t) + 0.22 * random.Random(int(t * RATE)).uniform(-1.0, 1.0))


def hit_heavy(t, duration):
    envelope = math.exp(-t * 13.0)
    return envelope * (0.65 * math.sin(2 * math.pi * (95 - 48 * t / duration) * t) + 0.30 * math.sin(2 * math.pi * 740 * t) * math.exp(-t * 40.0))


write("swing.wav", 0.28, swing)
write("hit_light.wav", 0.22, hit_light)
write("hit_heavy.wav", 0.38, hit_heavy)
