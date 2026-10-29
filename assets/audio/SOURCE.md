# Original gothic retro sound set

All six WAV files here are original procedural samples generated locally by
`tools/generate_gothic_audio.gd`, using Godot's PCM/WAV writer. No downloaded,
recorded, game-extracted, or third-party sound samples are included.

11,025 Hz mono, 16-bit PCM container with a deliberately coarse 8-bit amplitude
character. The bells combine inharmonic decaying partials and short echo taps;
impacts use a descending low tone and deterministic noise. `wind_low.wav` is a
quiet low drone intended for looping. These original project assets may be
modified and included with RIFTERMATH builds.

Regenerate with the installed Godot:

```text
godot --headless --path . --script res://tools/generate_gothic_audio.gd
```

`bell_old`: distant toll / ritual warning; `hit_stone`: contact;
`heavy_impact`: armor / triangle; `phase_chime`: phase/fold;
`quest_chime`: shrine / quest; `wind_low`: ambience.
