# Level plan (master sheet), v3: as built

Built from `docs/research/match3-level-design.md` and implemented in `scripts/core/Sites.gd`.
Every dig has one idea, at most 3 elements (at most 1 new), a place on its chapter's ramp
and a board shape that differs from its neighbours.

## Decisions

- **Building digs come right after their unlock.** Each chapter ends with a reward dig that
  unlocks a building; the next dig is that building's hand-made level. It needs the new tool
  but also uses matching, rock and energy. This moved the crystal lesson from chapter 2 into
  chapter 1 (dig 8), so the Power Station dig can end at a crystal.
- **Fixed shape, fresh ore.** Lessons and building digs have a fixed layout (`"ore"` rows plus
  a pinned seed) and a recorded solution that the tests replay. Every other dig keeps its
  shape, rock and goals, but gets new ore on each attempt.
- **Energy is not the main difficulty lever.** In the bot runs, digs on open ground end with
  the battery nearly full, because matches refund more than moving costs. Difficulty comes
  from the ore running out (shallow `:` and empty `_` ground), from rock to get through, and
  from goal size. A low starting `energy` only matters on boards that are short of ore.

- **A ramp, not a sawtooth.** v2 put a hard dig at X7 and a super-hard one at X9, with
  breathers in between. In play, X8 to X9 felt like a wall (dig 9 cleared about 1 in 5,
  dig 19 23 %, dig 29 10 %). v3 orders and tunes each chapter so it climbs step by step.
  The last dig before the reward is the hardest, but only a little harder than the one
  before it.

  | Place in chapter | Bot clear rate |
  |---|---|
  | X1-X4: lesson, building dig, early digs | 90-100 % (or hand-made) |
  | X5-X6 | about 85-90 % |
  | X7-X9 | stepping down to about 75-80 % |
  | X10: reward, unlocks a building | 100 % |

## Guidance budget (implemented)

- Mira's script plays **the first time** a dig is played, never on a retry. This covers both
  the lines you tap through and the instructions that stay up during play. 10 of the 31 digs
  have a script at all (tested: at most a third).
- **Hint arrow:** shows by itself only in digs 1–5, after 8 s without a move. After that it
  appears only when you tap Hint.
- **Colony:** Mira speaks only when something new happens or something is in the way:
  - the first visit;
  - a building to build;
  - a dig that needs a building you don't have;
  - an upgrade becoming affordable (once per building level);
  - every site charted (once).

  Otherwise she is quiet.
- **First-encounter notes:** a random line of 4 can leave a charge long before the charge
  lesson. The first time that happens, one short note explains it.

## Campaign

Bot clear rate = PLANNER bot over 30 seeds with the buildings a player has at that dig
(`tools/levels.gd`). Bots don't plan routes, so people should do better. The rate is a sanity
check, not a target. "Hand" = fixed layout with a recorded solution.

### Chapter 1: Landing Zone. New: swap and match, veins, rubble, crystal. Battery 20.

| # | id | Idea | Goal | Bot |
|---|---|---|---|---|
| 1 | first | One obvious swap lines up 3 Ferrite; the rest needs a little planning. 5×4 room. | 6 Ferrite | hand |
| 2 | drag | Plus-shaped room: chunks get dragged into lines. | 9 Cryo | 100% |
| 3 | vein | Deep middle vein, shallow edges. Mira explains the pips. | 15 ore | 100% |
| 4 | landing | Big open field. | 12 Lumen | 100% |
| 5 | rocks | A rubble band; matches under it crack it. | break 4 | 90% |
| 6 | glint | A glinting rock hides a crystal: crack it, drive onto it. | 1 crystal + 10 ore | 96% |
| 7 | ring | A rubble ring around a deep pocket, on shallow ground. Energy 18. | break 8 + 23 Ferrite | 90% |
| 8 | rooms | Two shallow rooms; open the wall before the first runs dry. | 17 Cryo | 76% |
| 9 | zigzag | Rubble zig-zag on scarce, shallow ground. Energy 16. | break 12 of 13 | 80% |
| 10 | lode | Mother lode, deep veins everywhere. **Unlocks the Power Station.** | 25 ore | 100% |

### Chapter 2: Glint Fields. New: Power Station, energy cell, blast charge. Battery 26.

| # | id | Idea | Goal | Bot |
|---|---|---|---|---|
| 11 | longhaul | **Power level.** A long bare tunnel to a crystal; only the bigger battery reaches it. | 1 crystal | hand |
| 12 | nearby | Crystals next to the start, deep veins around. | 2 crystals | 96% |
| 13 | battery | Start with 6 energy; the rock right above hides an energy cell. | 12 Ferrite | hand |
| 14 | charge | A line of 4 leaves a charge; step on it. | set off 2 blasts | hand |
| 15 | checker | Rock checkerboard with crystals and cells: which to open first? | 2 crystals | 90% |
| 16 | route | T-shaped dig, two crystal rocks at the top: plan the route. | 2 crystals | 86% |
| 17 | deep | Shallow field with deep pockets around a crystal. | 1 crystal + 25 Lumen | 80% |
| 18 | shallows | Shallow ground, crystals far apart, cells on the way. Energy 20. | 2 crystals | 83% |
| 19 | well | A crystal at the bottom of a rubble well; a straight shaft leads down past a cell. Energy 20. Was 23 %: the only way down was blocked. | 1 crystal | 76% |
| 20 | garden | Crystal garden. **Unlocks the Mining Workshop.** | 3 crystals | 100% |

### Chapter 3: Basalt Shelf. New: drill, stone and basalt. Battery 26 + drill.

| # | id | Idea | Goal | Bot |
|---|---|---|---|---|
| 21 | vaults | **Workshop level.** Crystals sealed in basalt vaults: drill in through the doorways. | 2 crystals | hand |
| 22 | stone | Four 2-layer stones scattered across open ground: crack twice, drill or blast. | break 4 | 100% |
| 23 | seam | Bands of deep, plain and shallow ground. | 32 ore | 100% |
| 24 | rubble | Soft rubble field full of energy cells. | break 17 | 96% |
| 25 | strata | Stone ring pattern around deep veins. Energy 17. | break 11 | 83% |
| 26 | pockets | Scattered crystal pockets with energy cells; one spare crystal. | 3 crystals | 88% |
| 27 | maze | Thinned rock maze, crystals in open corners, a cell and a spare. | 2 crystals | 100% |
| 28 | shale | Shallow ground, stone bands, cells under rock. | 12 Cryo + 1 crystal | 76% |
| 29 | core | Crystals in a 2-layer stone shell with a buried cell; power-station battery. Was 3 crystals in basalt at 10 %. | 2 crystals | 84% |
| 30 | openseam | Open seam ringed by rock. **Unlocks the Research Lab.** | 30 ore | 100% |
| 31 | readings | **Lab level.** Ten rocks, two crystals, small battery: use the scanner. Energy 14. | 2 crystals | hand |

## Tuning

- Re-run `godot --headless --path . -s res://tools/levels.gd -- 30` after editing a dig.
  Add `id:MOVES` to make the solver start with Mira's moves (e.g. `battery:L`).
- From the research: play each dig about 10 times and look at energy left on wins and goals
  left on losses. Two reshuffles (Pulse) in one attempt mean the dig needs a redesign.
- If players stall on a dig, loosen the goal or open a path through the rock first. Energy
  changes barely move the clear rate on boards with enough ore.
