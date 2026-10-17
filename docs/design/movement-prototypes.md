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
- Bot measurement (`tools/path_probe.gd`, same digs and budgets):

| path | dry moves | matches/move | specials/move | moves to clear |
|---|---|---|---|---|
| 1 (old) | 68% | 0.68 | 0.04 | 15.4 |
| 3 | 17% | 1.98 | 0.15 | 7.9 |
| 4 | 10% | 2.66 | 0.21 | 7.1 |
| 5 | 6% | 3.24 | 0.25 | 5.9 |

- The path bot weighs every path (~160 at 4 steps) and plays like an expert; budgets add a 40%
  human margin (`tools/tune_proto.gd`) until real plays calibrate it.
- Feel (BoardView): the robot lifts, leans to the finger, casts a shadow; swapped gems hop
  into place; the trail flows and warms cyan → gold → pink as steps run out; pips over the
  robot; a rising pentatonic marimba note per step, falling on undo; sparks and a haptic tick;
  the board dims, leans in 2.5% and the music ducks. **Outcome preview**: lines that would
  match glow in their colour with +N, a special that would form shows where it will appear,
  two or more lines call "xN COMBO!". Release: a ring and a small shake, then the cascade.
- Input that starts while the board animates is dropped, never queued.

## Board elements

- **Launch pad** (`pads`): a special, crystal or energy cell that comes to rest on the pad
  (pushed by the robot, dropped by gravity, carried by a belt, or made there by a match) flies
  along the dotted arc to the target; a special goes off there (a Drill bores on in the flight
  direction). Plain gems and the robot stay put (a robot thrown into a sealed room could never
  leave). A special pushed onto a pad by a path flies instead of going off.
- **Conveyor belt** (`belts`): a loop; after every move everything on it moves one cell (the
  robot rides), then the board resolves again.
- **Edge tunnel** (`tunnels`): walking (or drawing) off the board at one mouth comes out at the
  other.
- Boards are any size per dig (`Board.W/H` from its rows); prototypes are 9 wide.

## Prototypes (Settings > Prototypes)

1. **Launch bay**: a sealed vault; drop the waiting Quake onto the pad to blow it open.
2. **Conveyor ring**: a belt around a rock core; leave lines for the belt to finish.
3. **Wraparound**: left and right edges linked by two tunnels; four crystals far apart.
4. **Express belt**: the bottom belt runs into a pad; anything special on it is thrown into
   the vault. One Quake is already riding.
5. **Big dig**: Royal Match size board, no tricks, strata down to three crystals.

## Next (user idea, 2026-10-17)

- **Power-up combos on a path**: a path that touches two or more specials merges them into a
  stronger one that fires (Royal Match combos: rocket+rocket = cross, TNT+TNT = big blast,
  light ball + X). Fits drawn paths: the player plans a route through the specials, and the
  outcome preview shows the combo before release.
