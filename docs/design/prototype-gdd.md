# Astro Miner — Prototype GDD (v0.1)

One-line pitch: *steer a mining robot through a 7×8 dig site; every step drags one ore
chunk; line up three to extract it, dig the ground deeper and crack the rock around it.
Spend the haul at your colony on upgrades that change how the next dig plays.*

Name: **Astro Miner** (kept from the brief; the repository and package use it). It is a
working title — store-name uniqueness was not checked because this is not a store release.

## 1. Design pillars (from research)

1. **Position is the skill** (Six Match). The robot is a tile. Moving swaps it with the ore
   in front of it, so each step displaces exactly one chunk by one cell.
2. **Matches change the place** (Sliding Seas). An extraction never just disappears: the
   cell digs one layer deeper, nearby rock cracks, buried things are uncovered, and veins
   eventually run dry.
3. **Meta with mechanical teeth.** Each colony building changes a rule you feel on the next
   dig.
4. **Trustworthy, soft failure.** Seeded deterministic refill, haul always kept, Recall at
   any time.

### Rejected/deferred ideas (and why)

- **Sliding Seas' merge ladder** (match → one higher-tier tile). Combined with robot movement,
  each tier would cost many multi-step matches; goals become slow and the board reads as
  abstract colour shades. Its *spirit* — persistent change — is kept through excavation.
- **Six Match's hard 6-counter.** Binary and not smoothly upgradeable. Replaced by a battery
  with partial refunds (the counter-reset feeling survives: a match "buys back" energy).
- **Gravity refill.** With fixed rock and walls, gravity needs segment/diagonal rules that
  are hard to read. Top-down, "new ore rises from the layer below" is both simpler and
  more physical.
- Bolted line-pushers, timed hazards, multiple planets, idle timers: out of scope.

## 2. Controls

- **Swipe anywhere** on the board area → robot moves one cell in that direction.
- **Tap an orthogonally adjacent cell** → same move (more precise for beginners).
- Desktop: arrow keys / WASD, mouse emulates touch.
- Buttons: **Hint** (highlights the first step toward the nearest reachable match),
  **Recall** (end the dig now, keep the haul).
- Input during animations is buffered (one move) so the game never feels unresponsive.

## 3. The board

7 columns × 8 rows. Each cell has a **terrain** and, if open, an optional **token**.

Terrain:
- **Ground** with a *vein reserve* (0-5) and a *dug depth*. Depth is drawn as geometry, not
  only shade: each dug layer adds a stepped bench (shadowed north wall, lit south wall),
  walls appear only toward shallower neighbours so adjacent pits merge, and tokens and the
  robot shrink slightly with depth. Reserve is a row of warm pips; an exhausted vein shows a
  bare cracked floor.
- **Rock** with 1-3 layers (rubble, stone, basalt) hiding buried content: an ore pocket
  (default), an energy cell, a crystal, or nothing. Robot cannot enter rock.
- **Bedrock**: permanent wall that shapes the site.

Tokens (on ground only): **Ferrite** (orange square), **Cryo** (cyan circle),
**Lumen** (yellow triangle) — colour *and* shape, for colour-blind readability;
**Crystal** (violet gem); **Energy cell** (green battery); **Blast charge** (red ring).

The robot occupies one ground cell (no token there).

## 4. Turn rules (exact resolution order)

A move in direction *d* from robot cell *A* toward cell *B*:

1. *B* outside board or bedrock → rejected, no cost.
2. *B* is rock → if **Drill** is unlocked, the robot drills: pay drill cost, rock loses drill
   power layers, robot stays. Otherwise rejected (bump feedback + hint about the Workshop).
3. *B* is ground → pay 1 energy and the robot moves to *B*:
   - ore on *B* → the ore moves to *A* (the swap);
   - crystal / energy cell on *B* → collected;
   - blast charge on *B* → detonates around *B*.
4. **Resolve loop** (repeat until stable, max 30 passes):
   1. Find every horizontal/vertical line of ≥3 same-type ore. Lines of the same type that
      share a cell are unioned into one *group* (L/T shapes).
   2. Each group: +1 resource per chunk (+ Workshop bonus), +energy refund
      (`2` for a group of 3, `+1` per extra chunk, `+1` Lab bonus at Lv3).
   3. Each extracted cell digs: if reserve > 0 → reserve −1 and a new ore of a seeded
      random type **surfaces** there (a type that would instantly re-form a line is re-rolled
      once, so chains happen ~10-25 % of the time instead of dominating); else the cell
      becomes empty exhausted ground.
   4. A group of ≥4 leaves a **blast charge** on its pivot cell (the cell the robot just moved
      ore into, if part of the group; else the group's first cell) instead of surfacing ore.
   5. Every rock orthogonally adjacent to a group loses crack power layers (1, Workshop Lv3:
      2), once per group. Rock at 0 is **revealed**: becomes ground showing its content.
   6. Surfaced ore can form new lines → cascade ("vein chain").
5. **Detonation** (charge): every cell in the 3×3 around the robot:
   ore extracted (counts as resource, digs the cell), crystals/cells collected, rock −2.
   No energy refund for blast extraction, then the resolve loop runs.
6. If energy is 0 after resolution, the dig ends.

Determinism: the whole board, including every surfaced ore type, is driven by one seeded RNG
per dig. Same seed + same moves = same result (tested).

## 5. Energy

- Battery capacity (start): 20 (Power Station: 26 / 32 / 40). Starts full.
- 1 energy per step; drilling costs 2 (Workshop Lv3: 1).
- Match refund: 2 for 3 chunks, +1 per extra chunk; cascades refund too.
- Energy cells (buried under rock): +6, capped at battery capacity.
- Values are initial and are tuned by the simulation in `tools/simulate.gd`
  (see `docs/evaluation/core-loop-evaluation.md`).

## 6. Campaign, objectives and onboarding

Digs come one after another; there is no site list and no site names on screen. Progress is
felt in the colony: what gets built there is the point, digs are how you pay for it.

**Mira** (the colony chief, a drawn portrait) does all the explaining:
- *Lines that wait for a tap* (modal, screen dimmed) explain something.
- *Lines that wait for an action* stay under the board while you play and move on when the
  event happens (`match`, `charge`, `blast`, `reveal`, `crystal`, `cell`, `drill`); the cells
  she talks about pulse on the board, and on lesson digs the hint arrow appears after 2 s.
- Tap lines play only the first time a dig is played; action lines every time.
- Buying a building: she explains the new tool right away (`Story.BUILT`) and once more at the
  start of the next dig (`Story.REMIND`). Drill, scanner and bigger blasts are never hidden.
- In the colony she always says what to do next (`Story.advice()`): dig, build, or why the
  next dig needs a building.

**Goals are shown as icons**: a goal card (big icons and counts) opens every dig, and the goal
icons with counters sit right above the board; mined chunks that count fly into them.

| # | Dig | What Mira teaches | Goal |
|---|-----|-------------------|------|
| 1 | first (lesson) | robot swaps with the ore it steps into, lines of 3, digging and veins, energy | Extract 15 ore |
| 2 | landing → unlocks **Power Station** | routes on a full site | Extract 12 Ferrite |
| 3 | longhaul (building level) | crack the tunnel rock, fill the 26-energy battery, then walk 21 bare steps to the crystal: impossible with the old 20 | Recover 1 crystal |
| 4 | rocks (lesson) | matches crack rock, rock hides things, picking up crystals | Break 4 rock + 1 crystal |
| 5 | rubble | rock fields | Break 8 rock |
| 6 | glint | buried crystals | Recover 2 crystals |
| 7 | power (lesson) | low battery, match 4 for a charge, blasts break basalt, energy cells | Recover 1 crystal (start with 2 energy) |
| 8 | shale → unlocks **Mining Workshop** | shallow veins, energy cells | Extract 15 Cryo + 1 crystal |
| 9 | vaults (building level) | crystals in 3-layer basalt vaults behind doorways; drill them, refill with matches and energy cells | Recover 2 crystals |
| 10 | vein | deep veins, charges | Extract 15 Lumen + 2 crystals |
| 11 | core → unlocks **Research Lab** | basalt shell: drill and charges | Recover 3 crystals |
| 12 | readings (building level) | 10 rocks, 2 crystals, 14 energy: the scanner shows which rocks to open | Recover 2 crystals |

**Buildings are unlocked by the campaign, one at a time** (the usual mobile "feature unlock"
flow: teaser, unlock moment, guided first use, a level built around it). The colony lists only
the buildings you have plus a teaser for the next one. Clearing a dig with `unlock`: Mira
announces the building, a spotlight dims the screen around its Build button with an arrow
(only that button works; level 1 costs nothing), she explains the tool, then the spotlight
moves to DIG. The DIG button reads "Build first" until it is built. The dig right after is a
**building level** (`building_level`): full-size and hand-made, it mixes the new tool with
matching, rock and energy, and the tests check it cannot be finished without the building
(the scanner, which only shows information, excepted). On lesson digs the Hint button never
offers Pulse; with nothing else in reach it points at the cell Mira is talking about.

Lesson digs place every token by hand and pin the seed; the test suite replays each one's
intended solution with the buildings the campaign provides by then. After the last dig the DIG
button starts a **supply run**: a cleared open site with a fresh random layout. Every dig opens
with a goal card that cannot be dismissed for the first 1.5 s.

- Completing an objective ends the dig with a bonus (remaining energy → bonus ore, plus a
  first-clear crystal reward).
- Running out of energy or recalling ends the dig; **the haul is always kept**.

## 7. Resources and colony

Resources: Ferrite, Cryo, Lumen (common, from matches), Crystal (rare, from buried
deposits and first clears; gates level 2-3 upgrades).

Three buildings, three levels each; every level changes a rule:

| Building | Lv1 | Lv2 | Lv3 |
|---|---|---|---|
| Power Station | Battery 26 | Battery 32 | Battery 40 |
| Mining Workshop | **Drill**: bump rock to remove 1 layer (2 energy) | Drill removes 2 layers | Drill costs 1; matches crack 2 layers |
| Research Lab | **Deep Scanner**: see what is buried under rock | Broken rock opens 3-layer veins (was 5×5 blasts: removed, it trivialised boards) | +1 energy per match |

Costs are listed in `scripts/core/Economy.gd`. Level 1 of every building is free (the campaign
unlocks it and asks you to build it); levels 2 and 3 cost ore and crystals.

The colony screen shows the three buildings growing (more modules/lights per level), the
resource bank, each building's next effect and cost, and the site list.

## 8. Board generation and robustness

- Templates fix terrain/rock/contents; only ore types are random (seeded).
- Initial fill rejects any immediate line; the generator retries seeds until a match is
  reachable within 2 robot steps (breadth-first search over robot moves).
- **Hint** uses the same search (depth 4).
- **No unwinnable trap without an exit:** if no match is reachable within 5 steps the Hint
  button becomes **Pulse** (3 energy): the ore already on the board is reshuffled (same
  counts) until a match is reachable within 2 steps — the Six Match bomb, adapted. Recall is
  always available and the haul is never lost.
- Simulation bots (random, greedy, lookahead) play thousands of digs headless to measure
  completion rate per site, moves per match, cascade rate, energy exhaustion and starvation.

## 9. Session flow

Title → Colony (bank, buildings, sites) → Dig → Results (haul, objective, bonus) → Colony.
Save: `user://save.json` (resources, building levels, unlocked sites, best results, stats),
written after every dig and every purchase.

## 10. What makes it different from a conventional match-3

- You do not swap freely; you *are* a piece. Every step is a route decision.
- Matches dig a persistent pit and crack the surrounding rock: the board is a map of your
  excavation, with veins that run dry and force you outward.
- Hidden buried content turns rock-cracking into exploration.
- Upgrades change rules (drill, scanner, blast size, battery), not just numbers on a score.

## 11. Major assumptions to validate with humans

- Robot movement is understood within the first 3 moves without reading text.
- Three ore types are enough variety with the robot constraint (simulation says matches are
  neither trivial nor rare — see evaluation).
- Depletion feels like "the mine is exhausted, go further", not "the game starved me".
- Upgrades are noticed in the next dig (drill and scanner are visible verbs; battery is
  shown as a longer bar).
