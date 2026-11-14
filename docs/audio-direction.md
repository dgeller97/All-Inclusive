# Audio direction

The soundtrack uses a 12-bar, 90 BPM lounge arrangement in D major. A wooden mallet melody sits over electric piano, syncopated nylon plucks, rounded bass, hand drum and shaker. Short cues borrow the same instruments. The upgrade adds a rising figure and a wider stereo tail, and the end-of-day cue settles through a descending piano phrase.

| File under `res://assets/audio/` | Use | Duration | Channels | Peak dBFS |
| --- | --- | ---: | ---: | ---: |
| `music_resort.wav` | Background music | 32.00 s | 2 | −4.4 |
| `ui_click.wav` | Accepted control press | 0.09 s | 1 | −12.0 |
| `guest_checkin.wav` | Guest arrival and check-in | 0.48 s | 1 | −8.4 |
| `resort_upgrade.wav` | Pool upgrade purchase | 1.38 s | 2 | −5.5 |
| `day_close.wav` | Day-end summary | 0.96 s | 1 | −7.1 |
| `guest_review.wav` | Review received | 0.38 s | 1 | −9.6 |

All six WAV files use 44.1 kHz, 16-bit PCM. In Godot, play the music with `AudioStreamWAV.LOOP_FORWARD` from frame `0` to `1411200`. The rendered tails wrap across the boundary and the final chord resolves into the first bar. Play each cue once. Start the music player at −13 dB and the cue player at −5 dB. If several guests check in on the same update, play one check-in cue for that update. The audio toggle should mute both players.

Run `python assets/audio/generate_audio.py` from the project root to regenerate all six files. The score and synthesizer are in that script and use only the Python standard library.
