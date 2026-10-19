# Movement prototypes: drawn paths and board elements

2026-10-17. Why: with one step per move, 68–71% of moves made no match (SLOPPY bot, first 16
digs), so most taps paid nothing and levels felt bland next to Royal Match. Research:
`docs/research/royal-match-level-design.md`; the robot genre ("tactical match-3": Six Match,
Swap Sword, Mr. Driller) has no free-to-play level-based hit to copy, so depth comes from
movement.

## Drawn paths (Settings > Path: Off / 3 / 4 / 5, default 4)

- Hold the robot and draw up to `path_max` steps; the robot swaps with every gem on the way.
  Back onto the previous cell undoes a step. Lifting the finger is **one move**; matches,
  dragged specials and pads resolve once, at the end (`Board.try_path`). A short swipe is
  still one step (and can still drill).
- **Steady drag** (2026-10-18; on a phone the robot was twitchy and a path went wrong easily).
  The drag works from anywhere; the finger's travel is mapped onto the robot (`BoardView.drag_to`):
  - a step is 1.1 cells of finger travel (`DRAG_STEP`). 0.10.3 used 1.25 with a 0.65 threshold,
    which felt like paths could not be drawn at all (the first step needed 0.8 cell);
  - the next step comes only when the aim is 0.6 of a step past the last cell (`STEP_AT`), so a
    finger resting near the halfway mark can't step and undo over and over;
  - on a diagonal the robot waits until one axis leads by 0.25 (`STEP_LEAD`);
  - each step takes back 80% of the sideways drift (`RAIL_PULL`), so a slanted thumb swipe
    stays on its row;
  - walls are solid: pushing into rock, the edge or a full path doesn't pile up travel, so
    turning away from them works at once;
  - travel is measured on the screen, not on the board, so the board leaning in (scale 1.025)
    while drawing doesn't drift the aim;
  - **flick** (0.10.5): a touch lifted within 0.22 s (`FLICK_MS`) that moved at least 0.3 cell
    (`FLICK_MIN`) is one step that way, for players who move one step at a time;
  - the held robot holds still (0.10.4): it used to lean up to 0.32 cell toward the raw finger,
    so every tremor shook it, and right after a step (the aim then sits behind the new cell)
    it was pulled back, which felt like the hand slipping; it also swayed at ~3 Hz and jittered
    on a teleporter. Now it leans toward its next step only (at most 0.2 cell, smoothed; before
    the first step from the first millimetres, after a step once the aim is past where the
    step left it). Simulated tremor: shake while the finger rests 3.05 → 0.12 cells of motion
    per drag, pull-back after steps 1.01 → 0 cells.
  Simulated thumb (slanted swipes, tremor, a slip on lift; 8 paths × 150 tries × 3 tremor
  levels): the right path 70.6% → 90.6% of the time (heavy tremor: 58% → 78%).
- Bot measurement (`tools/path_probe.gd`, same digs and budgets):

| path | dry moves | matches/move | specials/move | moves to clear |
|---|---|---|---|---|
| 1 (old) | 68% | 0.68 | 0.04 | 15.4 |
| 3 | 17% | 1.98 | 0.15 | 7.9 |
| 4 | 10% | 2.66 | 0.21 | 7.1 |
| 5 | 6% | 3.24 | 0.25 | 5.9 |

- The path bot weighs every path (~160 at 4 steps) and plays like an expert; budgets add a 40%
  human margin (`tools/tune_proto.gd`) until real plays calibrate it.
- Feel (BoardView): the robot lifts, leans toward its next step, casts a shadow; swapped gems hop
  into place; the trail flows and warms cyan → gold → pink as steps run out; pips over the
  robot; a rising pentatonic marimba note per step, falling on undo; sparks and a haptic tick;
  the board dims, leans in 2.5% and the music ducks. **Outcome preview**: lines that would
  match glow in their colour with +N, a special that would form shows where it will appear,
  two or more lines call "xN COMBO!". Release: a ring and a small shake, then the cascade.
- Input that starts while the board animates is dropped, never queued.
- **The preview is the Board's** (2026-10-19): `Board.preview_path` plays the path with the same
  walk code as the move (`_walk`, shared by `try_move` and `try_path`) on a clone, and returns
  the board after the swaps, the lines that will match, where specials form, where each
  dragged special goes off. BoardView only draws it; it holds no rules (it used to rebuild the
  swaps itself and had already drifted: it ignored a site's pinned special and pads throwing
  cores). `tools/preview_check.gd` plays bot games and fails if preview and move disagree.

## Board elements

- **Launch pad** (`pads`): a special, crystal or energy cell that comes to rest on the pad
  (pushed by the robot, dropped by gravity, carried by a belt, or made there by a match) flies
  along the dotted arc to the target; a special goes off there (a Drill bores on in the flight
  direction). Plain gems and the robot stay put (a robot thrown into a sealed room could never
  leave). A special pushed onto a pad by a path flies instead of going off.
- **Conveyor belt** (`belts`): after every move it runs one step, plus one step per gem matched
  on it that move (at most 6; a ▶N badge at its start shows the count, and grows while a drawn
  path would push it further), each step followed by the board resolving; the robot rides.
  **Every belt is a cycle**: what leaves the last cell comes back on the first (a line's two
  ends are a pair of gates; a belt whose ends touch just turns round). The belt is still
  between moves and only runs, bright and fast, while it moves. A belt whose ends don't touch
  is a **shelf**: nothing on it falls through, gaps on it fill from above (so power-ups can be
  dropped onto it). A pad on a belt cell throws a special that rides onto it.
  (Tried and dropped: gaps closing by sliding along the belt, which stopped drops from above;
  a line whose end swallowed things or poured them into the column below, which nobody could
  follow.)
- **Teleporter pair** (`teleports`): a move or path that **ends** on a teleporter puts the robot
  on its twin (the twin's gem drops into the first one); passing over one mid-path does
  nothing. A special pushed or dropped onto one appears on the twin and goes off there, still
  heading the way it was pushed. A fall never teleports the robot (no bouncing). While drawing,
  a path that comes to rest on one arms it: charge-up sound, flash, buzz, a beam to the twin
  and a ghost robot where it will come out. (Edge tunnels were tried and dropped: they needed
  a single drag off the board's edge and nobody could tell what they did.)
- Boards are any size per dig (`Board.W/H` from its rows); prototypes are 9 wide.

## Prototypes (Settings > Prototypes)

1. **Launch bay**: a sealed vault; drop the waiting Quake onto the pad to blow it open.
2. **Conveyor ring**: a belt around a rock core; leave lines for the belt to finish.
3. **Teleporters**: a wall splits the board; two teleporter pairs cross it, and a Drill next to
   one shows that power-ups teleport too.
4. **Express belt**: a one-way belt runs into a pad; anything special on it is thrown into the
   vault. One Quake is already riding.
5. **Shelf belt**: a belt across the middle into a pad; drop the Quake onto it and speed it to
   the pad with matches on the belt.
6. **Big dig**: Royal Match size board, no tricks, strata down to three crystals.

## Next (user idea, 2026-10-17)

- **Power-up combos on a path**: a path that touches two or more specials merges them into a
  stronger one that fires (Royal Match combos: rocket+rocket = cross, TNT+TNT = big blast,
  light ball + X). Fits drawn paths: the player plans a route through the specials, and the
  outcome preview shows the combo before release.
