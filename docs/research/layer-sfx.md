# Generating SFX with Layer AI

Research brief, 2026-10-17 (read-only Layer calls, nothing generated; balance then 175 CU).

## Layer's sound-effect models

| model | price | duration | notes |
|---|---|---|---|
| `eleven-labs-sound-effects` (Layer's #1 SFX pick) | 0.3 CU/s (0.5 s = 0.1 CU) | 0.5–22 s | one output per run, MP3, loop, prompt strength, no seed |
| `mirelo-sfx-2` | 0.3 CU/s, batch works (4 × 0.5 s = 0.6 CU) | 0.1–600 s | negative prompt, seed, WAV |
| `mirelo-sfx` (1.6) | 0.3 CU/s | 0.1–60 s | seed, loop, init_audio |
| `sonilo-v1-1-text-to-sound-effects` | 0.05 CU/s | 0.5–180 s | WAV; "commercial-use-safe" (vendor claim) |
| `stable-audio-3-small-sfx` | 0.59 CU per run | 1–120 s | seed; poor value for blips |

Layer's own prompt guides: always set the duration (a UI sound came back 2 s long with >1 s of
silence); takes of one prompt vary a lot (13 dB apart), so reroll; end prompts with "dry,
close-mic'd, isolated, no room reverb, no ambience, no music"; state role → source/action →
attack/decay → space; tie synthetic sounds to a physical metaphor; one sound per prompt.

## What AI SFX do well and badly

Good: short impacts, UI blips, pickups, magic, whooshes. Bad: timing/tempo, melodic jingles,
exact pitch, consistent families. Usual workaround: 3–8 takes per slot, hand-pick, normalize per
category, randomize pitch/volume in the engine. Raw output often has leading silence and peaks
from −3 to −15 dB. Licensing: Layer says you own outputs, subject to the model's own licence.

## Plan

- Bake-off first: 3 prompts × 3 models (ElevenLabs, Mirelo 2, Sonilo) ≈ 2–3 CU.
- A full set (~20 sounds × 3 takes, with rerolls) ≈ 30 CU on ElevenLabs/Mirelo, ≈ 10 CU on Sonilo.
- Do not generate the cascade ladder: generate one clean tonal note and pitch it in-engine
  (`pitch_scale = 2^(semis/12)`); build the win stinger from the same note or a music model.
- Post-process: ffmpeg trim silence + 5 ms fade-in / 30 ms fade-out, mono 44.1 kHz, peak −1 dBFS;
  WAV for frequent short blips, Ogg for the rest; `sfx_<category>_<name>_<nn>`.

Example prompt (ElevenLabs, duration as a parameter): "Match-3 gem pop: a glossy jelly gem
bursting when matched, a soft wet plop with a bright glassy sparkle on top, instant attack,
silent within a quarter second. Cartoon mobile puzzle game, bright and friendly. Dry,
close-mic'd, isolated, no room reverb, no ambience, no music."

## What we shipped (2026-10-17, ~33 CU)

- SFX: Mirelo SFX 2, 27 sounds x 3 takes (batch 3, WAV), all kept as variants in
  `assets/sfx/<name>_<k>.wav`; trimmed, faded, RMS-matched to -18 dB (peak <= -1 dBFS), 44.1 kHz
  mono. `Sfx.gd` picks a random take with pitch/volume jitter and a per-sound repeat gap.
- Combo ladder: one marimba note from ElevenLabs ("single marimba note, middle register C5")
  came back at 528 Hz, retuned to C5 (`note.wav`). Mirelo's "bell note" takes were 4-5 kHz
  tinkles or noise: useless for pitching. ElevenLabs is the model for single tonal notes.
- Music: on Layer, MiniMax Music 3 with `instrumental: true` returns only 10-15 s whatever the
  duration (and one colony take still had vocals); ACE-Step / Stable Audio with a reference or
  init clip return the clip's own length (no extend). Text-only Stable Audio 3 Medium and
  ACE-Step give the full 120 s (~1 / 2.4 CU). Loops are cut by `loop.py` (scratch): skip the
  quiet intro, stop before the fade-out, choose the loop end by onset-envelope correlation,
  1 s equal-power crossfade, Ogg q4 (~1.8 MB each).
