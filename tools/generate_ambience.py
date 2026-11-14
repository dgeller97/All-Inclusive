"""Original, deterministic seaside ambience. Python standard library only."""
from array import array
from pathlib import Path
import json
import math
import random
import sys
import wave

RATE = 44100
SECONDS = 16
FRAMES = RATE * SECONDS


def filtered_noise(seed):
    rng = random.Random(seed)
    source = array("f", (rng.uniform(-1, 1) for _ in range(FRAMES)))
    slow = fast = 0.0
    # Warm the circular filter with the end of the same noise period.
    for value in source[-4096:]:
        slow += 0.018 * (value - slow)
        fast += 0.14 * (value - fast)
    result = array("f")
    for i, value in enumerate(source):
        slow += 0.018 * (value - slow)
        fast += 0.14 * (value - fast)
        phase = 2 * math.pi * i / FRAMES
        swell = 0.33 + 0.67 * (0.5 + 0.5 * math.sin(2 * phase - 0.8)) ** 2
        result.append((0.7 * slow + 0.3 * fast) * swell)
    return result


def main():
    left, right = filtered_noise(20261112), filtered_noise(20261113)
    peak = max(max(abs(v) for v in left), max(abs(v) for v in right))
    gain = 0.38 / peak
    pcm = array("h")
    energy = 0.0
    for a, b in zip(left, right):
        l, r = gain * (0.8 * a + 0.2 * b), gain * (0.8 * b + 0.2 * a)
        energy += l * l + r * r
        pcm.extend((round(l * 32767), round(r * 32767)))
    if sys.byteorder != "little":
        pcm.byteswap()
    output = Path(__file__).resolve().parents[1] / "assets/audio/ambience_surf.wav"
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    rms = math.sqrt(energy / (2 * FRAMES))
    print(json.dumps({"file": str(output), "frames": FRAMES,
                      "seconds": SECONDS, "rms_dbfs": round(20 * math.log10(rms), 2),
                      "peak_sample": max(abs(v) for v in pcm)}))


if __name__ == "__main__":
    main()
