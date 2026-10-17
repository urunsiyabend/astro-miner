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
