"""Compose the game's original PCM WAV files with the Python standard library."""

import math
import random
import sys
import wave
from array import array
from pathlib import Path


RATE = 44_100
TAU = math.tau
BEAT = 2 / 3  # 90 BPM
OUTPUT = Path(__file__).resolve().parent


class Mix:
    def __init__(self, seconds, looping=False):
        self.frames = round(seconds * RATE)
        self.looping = looping
        self.left = array("d", [0]) * self.frames
        self.right = array("d", [0]) * self.frames
        self.random = random.Random(314159)

    def add(self, samples, start, gain, pan, space=0):
        first = round(start * RATE)
        angle = (pan + 1) * math.pi / 4
        taps = [(0, gain * math.cos(angle), gain * math.sin(angle))]
        if space:
            taps += [
                (round(delay * RATE), gain * space * left, gain * space * right)
                for delay, left, right in (
                    (0.041, 0.34, 0.10), (0.059, 0.07, 0.30),
                    (0.097, 0.19, 0.10), (0.127, 0.08, 0.18),
                    (0.179, 0.13, 0.05), (0.233, 0.04, 0.11),
                    (0.291, 0.05, 0.04),
                )
            ]
        for delay, left, right in taps:
            offset = first + delay
            if self.looping:
                for index, sample in enumerate(samples, offset):
                    frame = index % self.frames
                    self.left[frame] += sample * left
                    self.right[frame] += sample * right
            else:
                count = max(0, min(len(samples), self.frames - offset))
                for index in range(count):
                    sample = samples[index]
                    self.left[offset + index] += sample * left
                    self.right[offset + index] += sample * right

    def tone(self, name, note, start, length, gain, pan=0, space=0):
        self.add(voice(name, note, length), start, gain, pan, space)

    def percussion(self, name, start, gain, pan=0):
        self.add(drum(name, self.random), start, gain, pan, 0.18)

    def write(self, name, peak, stereo=True):
        if stereo:
            samples = array("d", [0]) * (self.frames * 2)
            samples[0::2] = self.left
            samples[1::2] = self.right
        else:
            samples = array("d", ((left + right) / math.sqrt(2)
                                  for left, right in zip(self.left, self.right)))
        scale = 32767 * peak / max(map(abs, samples))
        pcm = array("h", (round(value * scale) for value in samples))
        if sys.byteorder != "little":
            pcm.byteswap()
        with wave.open(str(OUTPUT / name), "wb") as output:
            output.setnchannels(2 if stereo else 1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())


def smoothstep(value):
    return value * value * (3 - 2 * value)


# Each voice has an attack, release, and partials with separate decay times.
VOICES = {
    "keys": (0.019, 0.20, ((1, 1, 1.38), (2, 0.21, 0.55), (3, 0.07, 0.24),
                            (4.004, 0.11, 0.23), (6.02, 0.035, 0.085))),
    "bass": (0.012, 0.13, ((1, 1, 0.52), (2, 0.32, 0.19), (3, 0.09, 0.10),
                            (4, 0.05, 0.06))),
    "nylon": (0.006, 0.065, ((1, 0.76, 0.30), (2, 0.37, 0.16), (3, 0.20, 0.095),
                             (4.004, 0.07, 0.06), (5.01, 0.09, 0.04))),
    "mallet": (0.008, 0.13, ((1, 1, 0.26), (2.002, 0.08, 0.085),
                             (3.985, 0.20, 0.054), (8.13, 0.055, 0.022))),
    "bell": (0.010, 0.15, ((1, 0.80, 0.43), (2.004, 0.20, 0.17),
                           (2.987, 0.13, 0.10), (5.37, 0.05, 0.068))),
}


def voice(name, note, length):
    frequency = 440 * 2 ** ((note - 69) / 12)
    attack, release, partials = VOICES[name]
    attack = min(attack, length / 4)
    release = min(release, length / 2)
    oscillators = [(TAU * frequency * ratio, gain, decay)
                   for ratio, gain, decay in partials if frequency * ratio < RATE / 2]
    samples = array("d")
    for frame in range(round(length * RATE)):
        time = frame / RATE
        envelope = smoothstep(min(1, time / attack, (length - time) / release))
        sample = sum(gain * math.exp(-time / decay) * math.sin(omega * time)
                     for omega, gain, decay in oscillators)
        samples.append(envelope * sample)
    return samples


def drum(name, random_source):
    durations = {"shaker": 0.110, "hand": 0.200, "rim": 0.094, "click": 0.083}
    length = durations[name]
    samples = array("d")
    slow_noise = 0
    fast_noise = 0
    for frame in range(round(length * RATE)):
        time = frame / RATE
        white = random_source.uniform(-1, 1)
        slow_noise += 0.084 * (white - slow_noise)
        fast_noise += 0.44 * (white - fast_noise)
        grain = fast_noise - slow_noise
        if name == "shaker":
            sample = grain * math.exp(-time / 0.035)
        elif name == "hand":
            phase = TAU * (92 * time + 1.3 * (1 - math.exp(-time / 0.020)))
            sample = math.sin(phase) * math.exp(-time / 0.045)
            sample += 0.20 * grain * math.exp(-time / 0.021)
        else:
            frequency = 445 if name == "click" else 350
            wood = math.sin(TAU * frequency * time) + 0.32 * math.sin(TAU * 1.68 * frequency * time)
            sample = 0.7 * wood * math.exp(-time / 0.013)
            sample += 0.37 * grain * math.exp(-time / 0.011)
        envelope = smoothstep(min(1, time / 0.005, (length - time) / 0.020))
        samples.append(sample * envelope)
    return samples


# Bass, fifth, and piano voicing. The dominant in bar 12 resolves across the loop.
CHORDS = (
    (38, 45, (54, 57, 61, 64)),  # Dmaj9
    (35, 42, (54, 57, 61, 62)),  # Bm9
    (43, 50, (55, 57, 59, 66)),  # Gmaj9
    (33, 40, (55, 59, 61, 66)),  # A13
    (42, 45, (57, 61, 62, 64)),  # Dmaj9/F#
    (43, 50, (55, 57, 59, 64)),  # G6/9
    (40, 47, (55, 59, 62, 66)),  # Em9
    (33, 40, (55, 59, 62, 66)),  # A13sus
    (35, 42, (54, 57, 61, 62)),  # Bm9
    (43, 50, (55, 57, 59, 66)),  # Gmaj9
    (40, 47, (55, 59, 62, 66)),  # Em9
    (33, 40, (55, 59, 61, 66)),  # A13
)

# Beat, MIDI pitch, and relative dynamics. Space between the phrases leaves room for cues.
MELODY = (
    ((0.76, 69, 0.78), (1.54, 73, 0.84), (2.55, 76, 0.98), (3.56, 73, 0.67)),
    ((0.54, 74, 0.87), (1.31, 73, 0.69), (2.57, 69, 0.84)),
    ((1.05, 71, 0.81), (2.33, 69, 0.66), (3.05, 66, 0.84)),
    ((1.56, 64, 0.66), (2.82, 66, 0.75)),
    ((0.76, 69, 0.72), (1.54, 73, 0.79), (2.55, 76, 0.95), (3.31, 78, 0.76)),
    ((0.55, 76, 0.90), (1.55, 71, 0.77), (2.81, 69, 0.75)),
    ((0.80, 67, 0.73), (1.55, 71, 0.80), (2.54, 74, 0.88)),
    ((1.08, 71, 0.74), (2.31, 66, 0.70)),
    ((0.77, 66, 0.66), (1.55, 69, 0.76), (2.55, 73, 0.92)),
    ((0.54, 74, 0.84), (1.81, 71, 0.77), (2.56, 69, 0.62)),
    ((0.79, 67, 0.77), (1.54, 66, 0.70), (2.82, 64, 0.70)),
    ((1.30, 66, 0.74), (2.57, 69, 0.79), (3.80, 64, 0.54)),
)


def music():
    mix = Mix(32, looping=True)
    for bar, (root, fifth, chord) in enumerate(CHORDS):
        start = bar * 4 * BEAT
        for voice_index, pitch in enumerate(chord):
            pan = (-0.40, 0.16, -0.16, 0.40)[voice_index]
            mix.tone("keys", pitch, start + 0.023 + 0.011 * voice_index,
                     2.74, 0.082, pan, 0.38)
            if bar % 4 != 3:
                mix.tone("keys", pitch, start + 2.55 * BEAT + 0.008 * voice_index,
                         0.97, 0.039, -pan, 0.34)

        approach = CHORDS[(bar + 1) % len(CHORDS)][0]
        bass_line = ((0.00, root, 0.80, 0.29), (1.56, fifth, 0.34, 0.16),
                     (2.04, root, 0.56, 0.23), (3.54, approach, 0.31, 0.13))
        for beat, pitch, length, gain in bass_line:
            mix.tone("bass", pitch, start + beat * BEAT, length, gain)

        for beat, gain in ((0.55, 0.079), (1.54, 0.052), (2.56, 0.078), (3.54, 0.055)):
            for voice_index, pitch in enumerate(chord[1:]):
                mix.tone("nylon", pitch, start + beat * BEAT + 0.014 * voice_index,
                         0.32, gain * (1 - 0.17 * voice_index), -0.49, 0.34)

        for beat, pitch, dynamics in MELODY[bar]:
            mix.tone("mallet", pitch, start + beat * BEAT,
                     0.62, 0.185 * dynamics, 0.27, 0.45)

        for beat, dynamics in ((0.02, 0.126), (1.60, 0.057), (2.04, 0.091), (3.57, 0.054)):
            mix.percussion("hand", start + beat * BEAT, dynamics, -0.10)
        for beat, dynamics in ((1.03, 0.072), (3.04, 0.065)):
            mix.percussion("rim", start + beat * BEAT, dynamics, 0.32)
        for beat, dynamics in ((0.07, 0.07), (0.57, 0.13), (1.09, 0.063), (1.59, 0.12),
                               (2.08, 0.076), (2.59, 0.15), (3.08, 0.065), (3.61, 0.12)):
            mix.percussion("shaker", start + beat * BEAT, dynamics, -0.32)

    mix.write("music_resort.wav", 0.60)


def cues():
    click = Mix(0.090)
    click.add(drum("click", click.random), 0, 0.85, 0)
    click.write("ui_click.wav", 0.25, stereo=False)

    checkin = Mix(0.48)
    checkin.tone("mallet", 69, 0, 0.20, 0.68)
    checkin.tone("mallet", 73, 0.105, 0.22, 0.60)
    checkin.tone("bell", 76, 0.207, 0.265, 0.50)
    checkin.write("guest_checkin.wav", 0.38, stereo=False)

    upgrade = Mix(1.38)
    for start, pitch, gain, pan in ((0, 62, 0.73, -0.23), (0.115, 69, 0.61, -0.05),
                                    (0.23, 73, 0.64, 0.09), (0.36, 78, 0.72, 0.21)):
        upgrade.tone("mallet", pitch, start, 0.50, gain, pan, 0.28)
    for pitch, pan in ((62, -0.35), (66, -0.11), (69, 0.11), (76, 0.35)):
        upgrade.tone("keys", pitch, 0.36, 0.72, 0.20, pan)
    upgrade.tone("bell", 81, 0.39, 0.68, 0.17, 0.30)
    upgrade.write("resort_upgrade.wav", 0.53)

    day_close = Mix(0.96)
    for start, pitch, gain in ((0, 76, 0.54), (0.13, 73, 0.49),
                               (0.27, 69, 0.47), (0.43, 66, 0.46)):
        day_close.tone("keys", pitch, start, 0.50, gain)
    day_close.tone("keys", 50, 0.43, 0.52, 0.30)
    day_close.write("day_close.wav", 0.44, stereo=False)

    review = Mix(0.38)
    review.tone("nylon", 71, 0, 0.21, 0.70)
    review.tone("bell", 74, 0.11, 0.265, 0.50)
    review.write("guest_review.wav", 0.33, stereo=False)


if __name__ == "__main__":
    music()
    cues()
