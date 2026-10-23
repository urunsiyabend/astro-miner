# Power-ups v2: chains, path combos, the scout drone (design, 2026-10-19)

Research: `docs/research/match3-powerups.md`. Our set was ~half the genre's strength and had
no chains or combos (Drill 4 cells vs a rocket's 9; the 5-match Prism 10 vs a colour clear's
~20).

## The set

| Shape | Power-up | Alone |
|---|---|---|
| 4 in a row | **Pulsar** | twin beams **both ways** along the axis it was pushed, through rock (a layer each); aimed like Candy Crush's striped candy, a rocket's reach |
| 2x2 square | **Scout drone** | hits the 4 neighbours, then flies to the most useful cell (below) and hits it; carrying a power-up (a combo), it hits the cell and sets that one off there (Homescapes' plane) |
| L / T | **Nova** | 5x5 |
| 5 in a row | **Black hole** | swallows every gem of the colour of the gem the path swapped just before it (Royal Match's Light Ball takes the colour it is swapped with); with none before it (first step, a chain, a pad), the most common colour. The gems it takes count as a match for their neighbours: rock beside one cracks, once (Candy Crush's colour bomb and frosting). The preview rings every gem it will take |

Names: a pulsar is a star that sweeps two opposite beams; the user wanted space names, not a
rocket under another name. Four merged: the **Big Bang**.

## Chains

A power-up that another's effect reaches goes off too, one link at a time (a short stagger, a
rising note, "CHAIN xN" from 3). How a chained one fires:
- Pulsar: **across the line that hit it** (hit by a beam along a row → fires down its column;
  hit by a blast → across the line from the blast's centre). Lily's Garden's rule: a chain
  never wastes a Pulsar on the line already cleared.
- Drone: takes off and picks a target like any drone (the cells already doomed this move are
  not candidates).
- Nova: blasts. Black hole: swallows the most common colour.
All in Board: an effect that reaches a CHARGE queues it; the queue drains in order.

**Waves** (2026-10-21): a long chain or combo (a Black hole turning a colour into Pulsars) goes
off in waves of `Powers.WAVE` (3). Between waves the board settles and refills
(`Board._gravity`, which returns where each piece fell), and the power-ups still queued are
found where they fell to. The next wave hits what fell in, so the board keeps flowing during
a big combo, as Candy Crush's wrapped candy waits for the drop before its second blast.
Research: `docs/research/match3-refill-during-combos.md`.

## Combos on a path

The robot's path is our swap: **a path that drags two or more power-ups merges them**: they
fly into the last one touched and go off there as one, in the way the path pushed it. The
outcome preview shows the merged combo before the finger lifts.

Two (Royal Match's table, in our pieces):

| | Pulsar | Nova | Drone | Black hole |
|---|---|---|---|---|
| **Pulsar** | row + column (CROSS) | 3 rows + 3 columns (FLARE) | drone carries the Pulsar (PAYLOAD) | its colour turns into Pulsars, axes alternating (COLLAPSE) |
| **Nova** | | 9x9 (SUPERNOVA) | carries the Nova | its colour turns into Novas |
| **Drone** | | | 3 drones | its colour turns into drones |
| **Black hole** | | | | the whole board, one layer off every obstacle (EVENT HORIZON) |

Three or four (a path of 4 can drag up to 4; nobody else has these, they are ours):
**every extra power-up raises the combo a tier**:
- 3 power-ups: the two strongest combine as above, **doubled** (row + column → 3 rows + 3
  columns; 3 + 3 → 5 rows + 5 columns; 9x9 → the whole board; 3 drones → 5 drones carrying
  the third; a core turns **two** colours);
- 4 power-ups: **Overload**: the whole board, one layer off every obstacle, everything on it
  collected (the core + core result), the rarest, biggest moment in the game.
Strength order (which two lead): Black hole > Nova > Pulsar > Drone.

## Scout drone targeting (not the nearest: the most useful)

Take-off hits first (own cell + 4 neighbours), then score every cell not already doomed this
move (lines, blasts, other drones' locks):
```
score = tier + finish + reach + noise
tier    1000  advances an unfinished goal: a rock over a crystal, a generator (once per
              generator), a cage, the cell holding up an energy core
         500  any other obstacle (more if it touches a goal)
         100  a gem whose removal makes a cascade
          10  anything else
finish  +300  this hit finishes the item (last layer, last charge); +200 more if it finishes
              a goal counter
reach   +0..150  cells the player can't easily reach (walled in, behind rock, far away)
noise   seeded, tie-breaks only (replays and tests stay exact)
```
Generators: prefer the one closest to done; two drones may share one that still needs hits.
Several drones: assign one at a time, claim, re-score. The target is shown with a lock-on
reticle at launch; if it is gone on arrival (a cascade took it), the drone re-scores from where
it is and curves to the new one (Candy Crush Fish 3.0, Royal Match Propeller).
Carrying (Drone + X): score each landing cell by the goal value of X's whole footprint.

## Built (2026-10-19)

All rules in `scripts/core/Powers.gd` (shape, effects, chain queue, combos, drone targeting);
the Board only calls `Powers.fire` / `Powers.combo` and every cell is hit through
`Board._strike`. A 2x2 square of one colour is now a match (`Board._square`), and openings
never start with one. Quake, Prism, Geode and their art retired.

Measured on an open 9x9 (gems taken, mean over every cell):

| | before | now |
|---|---|---|
| 4 in a row | Drill 4 | Pulsar 8 |
| L / T | Quake 11 | Nova 18 |
| 5 in a row | Prism 10 | Black hole 24 |
| 2x2 | – | Scout drone 5 (its worth is where it goes, not how much) |

View: per-kind effects (beams, the nova's wave, gems spiralling into the black hole, the drone's
arc with a lock-on reticle), the merge step (power-ups fly into the last one), "CHAIN xN"
from the third link and the combo's name as a callout, the combo's name over the path while
drawing. `tools/preview_check.gd` checks the preview's combo against the move.
Next: tune budgets again (everything got stronger), juice per combo, the drone retargeting
mid-flight (only matters once effects overlap in time).
