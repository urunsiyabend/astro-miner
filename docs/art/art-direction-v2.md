# Astro Miner — Art Direction v2 (locked 2026-10-15)

Supersedes the lavender painterly look in `art-direction.md`. This is the target the whole
game moves to: a premium casual match style in the **Spyke / Dream Games** family, produced
through Layer AI the right way (see **Method**).

## Master reference (in repo)

- `docs/art/ref-v2/env-hero.png` — **THE master** (image "B1"): the full-screen look — alien
  purple planet environment, glossy chunky gems, warm earth board with recessed cell slots,
  the robot sitting flush on a cell, polished HUD + buttons. Its empty cells already read as
  darker recessed slots, so the color-depth language is already here — no separate depth
  reference is needed. (Layer file_id `31dfc3c2-3d09-49b6-96fc-da8390b3d952`.)

(Earlier explorations C3 "board-depth" and S1/C1 "robot-on-dug" were dropped: C3's depth ramp
was overdone and the dug-cell refs risked implying 3D depth. B1 covers everything.)

## The look

- **Glossy chunky rendered-2D.** Thick soft forms, specular highlights, smooth gradients,
  gentle drop shadows, rounded friendly shapes. Premium and cheerful, high contrast, readable.
- **Planet 1 (Corvo IV):** cosmic purple/violet sky with stars and a distant planet, a few
  glowing alien plants at the screen edges; warm brown earth board with recessed square slots.
- **Ore (board matching pieces), colour + shape for colour-blind readability:**
  - Ferrite — glossy faceted **orange square** gem
  - Cryo — glossy **cyan round** gem
  - Lumen — glossy **yellow triangle** gem
  - Crystal (the **Star** currency reward) — bright **violet** faceted gem
- **Rock** — grey block with glowing violet crystal veins, in crack states (intact → cracked →
  crumbling). 1/2/3 starting layers (boulder/stone/basalt).
- **Robot** — cute small white mining robot with a single antenna; it IS a tile, so it must sit
  flush and fully readable on ANY cell, undug or dug.

## Depth = COLOR ONLY (no 3D geometry) — key decision

Digging does **not** carve a 3D pit. A dug cell stays a **flat tile at the same height**;
depth is shown purely by a **darker earth tint**. This keeps the robot (a tile) sitting flush
on every cell and massively simplifies both the art and the engine (drop the old stepped-bench
/ merging-pit geometry).

- **~3 depth tiers**, subtle: undug (light warm) → dug-1 (medium brown) → dug-2 (darker brown).
  Derive them from B1's own empty-cell tone (B1 already shows the recessed darker slot); keep
  the steps gentle — 3 levels max, separated by thin crisp cell borders and at most a whisper
  of inner shadow. (A multi-tier ramp was tried and looked overdone — stay quiet.)
- Exhausted/bare floor = the darkest tier with a faint cracked texture.
- This replaces GDD v1 §3's geometry depth. Update `BoardView` to tint cells by dug level
  instead of drawing benches/walls.

## Method (what fixes the "AI slop")

The old tiles looked stiff because of the **method**, not the model:
- They used a **flat blockout as `init_image` at weight ~0.8** → the model repainted flat
  geometry → stiff. (Model was `gemini-3.1-flash-image`, which is fine; `muse-image` was only
  the *planned* model and is the weakest option anyway.)

Rules now:
1. **Never** feed a flat blockout as a high-weight `init_image`. Generate from **prompt +
   style reference_image**, or (better, for consistency) a **trained style LoRA**.
2. Use a strong model: **`gemini-3.1-flash-image`** worked well; `GPT Image 2.5 Sunburst/Flare`
   and `Nano Banana 2` are also strong. Avoid `muse-image`.
3. Lock the look on a hero, then keep every asset on-model via a LoRA / style reference.

## Pipeline from here

1. **Train a style LoRA** from the approved hero set (env-hero, board-depth-master,
   robot-on-dug, plus a few clean asset sheets) so every asset comes out in one language.
   `start_training` on a reference set; `list_reference_sets` to use it; forge with it attached.
2. **Generate per-asset sheets** on transparent/flat backgrounds, in the locked style:
   - ore gems ×3 + crystal (one family sheet)
   - rock: 3 forms × 3 crack states
   - board tiles: the ~3 depth tiers (flat, color ramp) + bare/exhausted
   - robot (idle, + facing/anim frames later)
   - energy cell, blast charge
   - UI: HUD plate, energy bar, goal chips, buttons (Hint/Recall/Pulse), Coin + Star icons
   - Mira portrait (character)
   - colony (top-down space colony — new direction, separate pass)
3. **Normalize** through `tools/art/build_assets.py` (palette, sizing, outline, alpha,
   anchors) and wire into `Art.gd`.
4. **Verify in engine** at native tile size (~130px) before approving.

## Model (2026-10-20, the user's call)

Generate with **`muse-image`** (0.2 CU per image), batch 1-2. The notes above against Muse were
about a method (a flat blockout as a heavy init image), not the model. This is prototype art;
production art will likely be made another way. Gemini (2 CU per image) only where Muse clearly
fails, batch 1.

## Budget

Layer workspace `e8720ad0-ad91-44c4-aced-56252dafc5dc` (Siyabend's Workspace). ~232 CU left
after art-direction exploration (30 CU spent). `gemini-3.1-flash-image` ≈ 2 CU/image. Asset
production is the big spend — estimate before each batch, keep jobs under 20 CU or ask.
