# Astro Miner — GDD v4: buildings make boosters, levels carry the challenge

> Status: **direction agreed 2026-10-17** (user). Changes the meta and difficulty model of
> `gdd-v3.md`; everything not mentioned here still holds. Supersedes v3 §2 (Lab +1 energy per
> match), §4 (Power Station "+N energy every dig"), the level-plan "ramp" targets, and the
> Workshop/Lab upgrade effects in `Economy.BUILDINGS`.
> Research: `docs/research/match3-meta-balance.md`.

## 0. Why v4

By dig ~20 the game plays itself: digs end with 30–35 moves left, pay ~50 Coin, some clear
in a few seconds, and 30 digs take 15–20 minutes. Measured with `tools/balance_probe.gd`
(bots buy every upgrade as soon as affordable, retry failures):

- Power Station is maxed by **dig 14** and adds **+10 moves to every dig** from then on.
- After dig 20, won digs leave **55–85% of the budget unused**; `core` (55 moves) clears in 5.
- A player earns ~850–975 Coin over the planet; all upgrades together cost 770.

The cause is not that upgrades come early. **Permanent board power removes the decisions**:
with a fat margin, a mistake costs nothing, so there is nothing to think about. It also feeds
itself: more power → more moves left → more Coin → more power.

The top casual match-3 games (Royal Match, Homescapes, Candy Crush, Toon Blast) never let the
meta make the board easier. Board help is **consumable**: boosters and extra moves that are
gone once used. Levels are tuned once, against a player whose power does not grow.

## 1. Buildings: a mechanic on unlock, boosters from upgrades

- **Unlocking a building opens a mechanic** (a new robot ability the levels are designed
  around). This is permanent but it is not free power: it adds a choice. The Drill costs
  energy per bump ("break through or walk around?"); the Scanner shows what rock hides.
- **A building produces one booster type.** Its level sets the production, never the board.
  Boosters were chosen from the problems a player meets, not from the buildings we had:
  1. the colour you need is scattered (the robot drags one chunk per step);
  2. the target is far away (walking costs moves);
  3. rock walls and gates block the route;
  4. "two moves short".
  Each booster has a different *shape* (area, point, line, whole board), so none makes another
  pointless; each asks the player *where*; each reads from its icon and is a show to use.
  All four are used **during** the dig from a bar under the board and cost 0 moves:

  | # | Booster | Shape | Answers | Effect | Made by | Unlocks |
  |---|---|---|---|---|---|---|
  | 1 | **Bomb** | area | rock clumps, rock goals | tap a cell: 3×3 blast, ore extracted, rock −2 layers | Power Station | Star 8 (~dig 8) |
  | 2 | **Warp** | point | far targets, one chunk in the wrong place | tap any ground cell: the robot warps there and swaps with what it holds (a long-range swap; it can make a line) | **Teleporter** (new building) | Star 14 (~dig 14) |
  | 3 | **Laser** | line | rock walls, gates | swipe a direction: a beam from the robot to the edge, ore extracted, rock −1 layer | Mining Workshop | Star 20 (~dig 20) |
  | 4 | **Magnet** | board | scattered colour, ore goals | tap a chunk: every chunk of that colour flies to the robot and is extracted | Research Lab | Star 30 (~dig 30) |

  - Warp and Laser exist only because the robot is a tile: the Laser fires *from the robot*,
    so position still matters while using a booster.
  - Magnet is the strongest (a colour bomb): last to unlock, slowest to produce.
  - **Rejected:** a +5-moves Battery (no decision, no show, and it would kill the Coin
    continue, which is where +5 moves lives); a colour Transmuter (a fiddly picker, weak
    show; Magnet answers the same problem); shuffle (the board pulses by itself when stuck);
    reveal (the Scanner already does it).
  - **Teleporter** is a new colony building (`assets/colony/teleporter.png`) on the Star 14
    milestone and on the Greenhouse's old plot; the Greenhouse is out of the colony for now.
    It is building index 3 (appended, so old saves keep their levels).
- **Locked boosters show in the bar** greyed with a padlock; a tap shakes it and pops
  "Locked". The bar always shows all four, so the player sees what is coming. A new booster
  arrives with Mira's lesson and one free.
- **Collecting:** a building with a booster ready shows a bubble with the booster icon over
  it; tap to collect (the icon flies to the inventory).
- **Production is per cleared dig, not a timer.** Power then grows with play, at a rate we
  set, so the level tuner knows what a player holds at dig N. No waiting exploit, no second
  timer next to lives (lives will own real time).

  | Level | Makes 1 every |
  |---|---|
  | 1 (free, Star milestone) | 5 clears |
  | 2 (Coin) | 4 clears |
  | 3 (Coin) | 3 clears |

  **Decided 2026-10-17:** a building holds **one** booster until it is collected and makes no
  other meanwhile, so a bubble always means "one is ready" (a count on the bubble confused).

  The inventory itself has no cap.

  A new building hands out its first booster at once, with Mira's lesson.
- **Removed** (permanent power): Power `+3/+6/+10` budget, Workshop drill 2 layers / cost 1 /
  matches crack 2, Lab richer veins (reserve 3) and `+1 energy per match`.
- **Planets:** the four Planet 1 boosters stay universal. Each new planet adds **one** booster
  that answers its own mechanic (Verdis: a vine cutter), made by that planet's building. One
  shared inventory. **Decided:** a planet's buildings stop producing once you move on (simpler;
  the new planet has its own).

## 2. Coin

- **Kept as is:** a clear pays the chapter reward (8/10/12) + 1 per move left. With tight
  budgets few moves are left (median 2–5), so this stays small and rewards playing well.
- **Sinks:** building upgrades (production); **continue +5 moves** when a dig runs out (the
  near-miss offer, `Board.continue_with`), price rising on each repeat within a dig; later,
  buying boosters. Prices are set after the levels are retuned.

## 2b. Star

- **Decided 2026-10-17: crystals no longer give Star.** Star = **+1 per dig first-clear**,
  nothing else (Royal Match's model). A crystal is a goal item only. Reasons: a crystal-rich
  dig sped the colony up for luck, not for play, and it made milestone timing unpredictable;
  now Star N means exactly N digs cleared, so milestones (4, 8, 14, 20, 30) land on known digs.

## 3. Levels: length and difficulty

- **Length:** a normal dig is **20–30 moves, 60–120 s**. Hard digs are **shorter, not
  longer** (King). Goals and boards grow to fill that; budgets come down to match.
- **Difficulty, first-attempt clear rate** (tuned **without boosters**, with the mechanics a
  player has at that dig; boosters and the continue are the player's own help):

  | Place in 10-dig chapter | Target |
  |---|---|
  | X1–X4 (and all of digs 1–10) | ~85–95% |
  | X5 hard | ~55% |
  | X6–X8 | ~75–80% |
  | X9 super-hard | ~35% |
  | X10 reward / unlock | ~100% |

  Won digs should end with **few moves left**. Measured (step 5): a hard dig at ~55% leaves a
  median of 6–8; a normal dig at ~82% can only leave as little as the spread of "moves needed"
  allows, because the budget has to cover its long tail. So the lever is the *spread*, not
  the budget:
  - a goal for **one specific colour** depends on which colours surface: wide spread (a
    normal dig left 19–25 moves);
  - **any-colour chunks**, crystals and rock depend on the route: narrow spread (6–11 left).
  Normal digs therefore lean on chunks/crystal/rock goals; one-colour goals are kept for
  short digs and lessons. Tuned with `tools/tune_v4.gd` (SLOPPY bot = the planner with 12%
  random moves, the human proxy).
- **Lesson from v2:** the old X9 at 10–23% felt like a wall. The new floor is ~35%, and the
  player now has boosters and a continue to get through, so a hard dig is a decision
  ("spend my Bomb here?"), not a wall. Hard digs are marked on the goal card.

## 3b. Ore colours

- Today: **3 ore colours** (Ferrite, Cryo, Lumen). Top match-3 use 4–6 (Royal Match ~4,
  Homescapes went 5 → 4 to get easier). Fewer colours = more free lines and cascades = easier.
- But here one step drags one chunk, so a line costs far more moves than a swap does in a
  swap game; 5–6 colours would make every match a long walk. **Decision:** add **one** 4th ore
  colour and use the colour count as a **per-dig difficulty lever** (`"colours": 3|4`): digs
  1–10 stay at 3, hard digs and later chapters use 4. Measure with the bots before the art.
  **Measured:** 4 colours cut the sloppy bot's clear rate on match goals hard (ring 66→8%,
  seam 79→12%, lode 91→41%) and barely touch crystal/rock goals (routing decides those). So
  it is a strong, targeted lever: used on nearby (Ruby's intro, low stakes), seam and the
  super-hard shale. The 4th ore is **Ruby** (red hexagon, `assets/ore/ruby.png`); the crystal
  moved to resource index 4.
- The 4th colour needs a distinct colour *and* shape (colour-blind rule) and must not read as
  the violet crystal.

## 4. Tools

- **Bot first.** The bots fail the drill digs (`longhaul`, `vaults`, `readings`) on their own
  weakness, so they cannot measure those digs. Teach them the drill before tuning anything.
- `tools/tune_moves.gd` gets the §3 targets and plays with the mechanics only (no budget
  bonus). `tools/balance_probe.gd` is the acceptance check: moves left, attempts, Coin, bought
  levels per dig.
- Later: time to clear per dig (moves × move animation) as a column in the probe.

## 5. Build order

1. Bot uses the drill; probe passes the drill digs.
2. `Economy`: strip the permanent bonuses; buildings describe their booster and production.
3. `Game`: booster inventory + per-clear production (saved); colony card shows rate/stock.
4. Dig: the booster bar (4 slots, locked ones greyed); colony: production bubbles.
5. Levels: goals sized for 20–30 moves; retune budgets to §3; hard/super-hard placement.
6. Continue for Coin (near-miss).
7. Upgrade costs and continue price from the probe.
8. Lives (only once failure is real).

## 6. Open

1. Can boosters also be bought with Coin, and at what price?
2. Production rates vs the difficulty targets: tune once boosters exist (the targets are
   measured without boosters, so the real clear rate will be higher).
