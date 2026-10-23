# Fluid falls and diagonal fill

2026-10-21. Why: our gems fell "like logs" (one rigid drop per column, a pass at a time) and
holes under rock never filled. Question: how do modern match-3 games make falls feel liquid,
and which ones slide gems diagonally?

## Best source: Unity's "Gem Hunter Match" sample

Unity's official match-3 sample ships its fall code and tuned curves
(https://unity.com/blog/engine-platform/2d-puzzle-match-3-sample-gem-hunter-match; code read
from a mirror, `Board.cs`, `Gem.cs`, `GameManager.prefab`). Units are world units, about one
cell.

- **Speed**: 10 cells/s times an acceleration curve over fall time (0.39 at 0 s, 0.53 at
  0.225 s, 1.0 at 0.5 s): a gem starts at ~4 cells/s and reaches 10 after half a second. The
  clock is **not reset** at each cell: the gem keeps speeding up through the whole drop
  (1 cell ~0.22 s, 3 cells ~0.5 s, 8 cells ~1 s).
- **Landing bounce** (vertical offset): 0 → 0.32 at 0.04 s → 0.24 at 0.13 s → 0.01 at 0.15 s →
  0.07 at 0.18 s → 0.005 at 0.20 s → 0.06 at 0.22 s → 0 at 0.25 s: one hop, two small rebounds.
- **Squish** (scale y): 1.0 → 0.745 at 0.048 s → 1.0 at 0.095 s.
- **Every gem moves on its own**: no lock-step tick; a gem starts falling the moment the cell
  under it frees, new gems stream in one cell apart above the top cell.
- **Diagonal steps** run at √2 speed, so they take as long as a straight step.
- Matches are checked per gem as its bounce ends, while others still fall.

## What makes a fall stiff

- One cell per fixed step, waiting between steps (daltonbr/Match3, `fillTime`): constant speed,
  a tick at a time.
- Slides played one at a time (Defold emthree: 0.2 s per collapse, 0.2 s linear slides). A user
  reported a blocker-heavy board taking 5.5 s to settle vs ~1 s without blockers
  (forum.defold.com/t/emthree-functionality/47608).
- Hobby kits: 0.30 s per cell, constant speed.

No published tuning exists for Royal Match, Candy Crush, Toon Blast or Homescapes.

## Who slides diagonally

- **Candy Crush Saga: confirmed.** Wiki "Level": "Candies may slide diagonally when there are
  intervening blockers or gaps." Level 802 (candies "slip out to the corners"), 828 ("slide to
  the next column"); a teleporter pair once looped candies diagonally forever (a softlock).
- **Homescapes**, Indy Cat: named by a gamedev.net poster.
- Royal Match, Gardenscapes, Lily's Garden: yes from play, no written source.
- Bejeweled: no (no blockers, straight refill).

## The rules (as the open implementations do it)

1. Straight first: a hole whose cell above holds a piece, or is an empty playable cell, fills
   (or waits) straight. It never steals diagonally while it has a straight source.
2. Only a hole whose cell above is rock, void or an immovable piece takes a piece from
   above-left / above-right, and only one that can't fall straight itself.
3. Side priority alternates (daltonbr flips per step, emthree by column parity), so neither
   side drifts.
4. New pieces spawn only from spawners (the sky). A hole with no straight and no diagonal
   source stays a pocket until a neighbour clears.
5. Every move goes down, so it always ends. Mind teleporter pairs.

## What we do (Board `_gravity`, BoardView "fall")

- **One settle per step**: `_fall_straight` and `_slide_diagonal` repeat until nothing moves;
  every piece keeps its route (`paths`: grid points from its start, new gems from above the
  run's top). The view plays all routes at once, not a pass at a time.
- Gems spawn only where a run opens to the sky (top row or bedrock above); under rock a hole
  fills diagonally or waits.
- Fall: from 4 cells/s, +16 cells/s², at most 11 cells/s (`FALL_V0`, `FALL_A`, `FALL_VMAX`);
  diagonal steps at the same pace. Pieces start bottom first, 0.025 s apart up the column they
  start in, plus a faint ripple across columns.
- Stretch while falling (x 0.96, y 1.06 at top speed); on landing Gem Hunter's squash (y 0.75,
  x 1.12) and its hop at half height, both softer for a short drop (`_land_k`).

Not done: matching per piece while others still fall (our steps resolve in order; input is
dropped during animations anyway), corner rounding on diagonal steps.
