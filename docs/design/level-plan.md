# Level plan (master sheet), v2: as built

Built from `docs/research/match3-level-design.md` and implemented in `scripts/core/Sites.gd`.
Every dig has one idea, at most 3 elements (at most 1 new), a role in its chapter's sawtooth
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

| # | id | Role | Idea | Goal | Bot |
|---|---|---|---|---|---|
| 1 | first | learn | One obvious swap lines up 3 Ferrite; the rest needs a little planning. 5×4 room. | 6 Ferrite | hand |
| 2 | drag | learn | Plus-shaped room: chunks get dragged into lines. | 9 Cryo | 100% |
| 3 | vein | learn | Deep middle vein, shallow edges. Mira explains the pips. | 15 ore | 100% |
| 4 | landing | breather | Big open field. | 12 Lumen | 100% |
| 5 | rocks | learn | A rubble band; matches under it crack it. | break 4 | 86% |
| 6 | ring | vary | A rubble ring around a deep pocket, on shallow ground. | break 8 + 16 Ferrite | 100% |
| 7 | rooms | **hard** | Two shallow rooms; open the wall before the first runs dry. Energy 18. | 18 Cryo | 73% |
| 8 | glint | learn | A glinting rock hides a crystal: crack it, drive onto it. | 1 crystal + 10 ore | 96% |
| 9 | zigzag | **super-hard**, short | Rubble zig-zag on scarce, shallow ground. Energy 16. Eased after playtest: was 13 rocks / energy 15, which bots and the player cleared about 1 time in 5. | break 12 of 13 | 77% |
| 10 | lode | reward | Mother lode, deep veins everywhere. **Unlocks the Power Station.** | 25 ore | 100% |

### Chapter 2: Glint Fields. New: Power Station, energy cell, blast charge. Battery 26.

| # | id | Role | Idea | Goal | Bot |
|---|---|---|---|---|---|
| 11 | longhaul | **Power level** | A long bare tunnel to a crystal; only the bigger battery reaches it. | 1 crystal | hand |
| 12 | route | vary | T-shaped dig, two crystal rocks at the top: plan the route. | 2 crystals | 86% |
| 13 | nearby | breather | Crystals next to the start, deep veins around. | 2 crystals | 96% |
| 14 | battery | learn | Start with 6 energy; the rock right above hides an energy cell. | 12 Ferrite | hand |
| 15 | checker | vary | Rock checkerboard with crystals and cells: which to open first? | 2 crystals | 90% |
| 16 | shallows | **hard** | Shallow ground, crystals far apart, cells on the way. Energy 20. | 3 crystals | 50% |
| 17 | deep | breather | Deep veins and a crystal in the middle. | 1 crystal + 15 ore | 96% |
| 18 | charge | learn | A line of 4 leaves a charge; step on it. | set off 2 blasts | hand |
| 19 | well | **super-hard**, short | A crystal at the bottom of a rubble well. Energy 16. | 1 crystal | 23% |
| 20 | garden | reward | Crystal garden. **Unlocks the Mining Workshop.** | 3 crystals | 100% |

### Chapter 3: Basalt Shelf. New: drill, stone and basalt. Battery 26 + drill.

| # | id | Role | Idea | Goal | Bot |
|---|---|---|---|---|---|
| 21 | vaults | **Workshop level** | Crystals sealed in basalt vaults: drill in through the doorways. | 2 crystals | hand |
| 22 | stone | learn | Stone has 2 layers: crack twice, drill or blast. | break 4 | 90% |
| 23 | seam | breather | Bands of deep veins. | 25 ore | 100% |
| 24 | pockets | vary | Basalt pockets with crystals: drill or charge. Energy 20. | 3 crystals | 86% |
| 25 | maze | **hard** | Basalt maze, two crystals. Energy 20. | 2 crystals | 46% |
| 26 | rubble | breather | Soft rubble field full of energy cells. | break 12 | 100% |
| 27 | strata | vary | Stone ring pattern around deep veins. Energy 20. | break 10 | 93% |
| 28 | shale | **hard** | Shallow ground, stone bands, cells under rock. | 15 Cryo + 1 crystal | 66% |
| 29 | core | **super-hard** | Three crystals inside a basalt shell. Needs the drill. | 3 crystals | 10% |
| 30 | openseam | reward | Open seam ringed by rock. **Unlocks the Research Lab.** | 30 ore | 100% |
| 31 | readings | **Lab level** | Ten rocks, two crystals, small battery: use the scanner. Energy 14. | 2 crystals | hand |

## Tuning

- Re-run `godot --headless --path . -s res://tools/levels.gd -- 30` after editing a dig.
  Add `id:MOVES` to make the solver start with Mira's moves (e.g. `battery:L`).
- From the research: play each dig about 10 times and look at energy left on wins and goals
  left on losses. Two reshuffles (Pulse) in one attempt mean the dig needs a redesign.
- Super-hard digs (9, 19, 29) are short on purpose. If players stall there, loosen the energy
  first, then the goal.
