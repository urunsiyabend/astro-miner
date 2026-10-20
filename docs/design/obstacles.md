# Obstacles and level goals

2026-10-19. Why: next to Royal Match and Gardenscapes, our levels only ask "collect N / break N
rock". Modern match-3 levels give every level a problem to solve. Research:
`docs/research/match3-goals-obstacles.md`.

## Goal types

| Goal | Player's problem | Real games | Astro Miner | Status |
|---|---|---|---|---|
| Collect | get N of a piece | every game (Candy Order, colour targets) | `ore`, `chunks`, `crystal` | live |
| Excavate | uncover what is hidden | Gardenscapes gnomes, Soda frosting bears, RM Rock | crystal / chest under rock (`buried`) | live |
| Deliver | bring an item down to an exit | CC ingredients, RM Bird/Frog/Royal Bot | energy **core** onto a **dock** (`core`) | prototype 8 |
| Activate | charge machines | RM Drill, Bush (it is "fill an element until done") | **generator** 2x2 (`generator`) | prototype 7 |
| Rescue | free something trapped | Soda honey bears, RM Polar Bear | not yet (a robot buddy in a cage of rock) | idea |
| Connect | open a path between two points | CC Rainbow Rapids (rare now) | not yet: the robot genre owns paths, a gap worth taking | idea |
| Sequence | A, then B | RM Royal Bot (crate, then drop), Furnace | inside one element, not across the level | idea |

## One rule table (`scripts/core/Obstacles.gd`)

Every obstacle is a row in `Obstacles.KINDS`. The Board never checks "is this a cage?"; it asks
`obs.locked(i)` / `Terrain.BLOCK` and reports every hit through **`Board._strike`**, the single
way anything damages a cell (a match on it, a match next to it, a power-up, a blast, a booster).

How a cell is hit:

| Hit | When | Dedupe |
|---|---|---|
| `ON` | a gem on the cell is in a match | per group |
| `NEXT` | a match next to the cell | once per group per obstacle |
| `POWER` | power-up, blast, booster | once per power-up per obstacle |

Where an obstacle sits:

| Layer | Meaning | Board effect |
|---|---|---|
| `PIECE` | takes the cells instead of gems, may span cells | `Terrain.BLOCK`: solid for gravity, robot, paths; rays (Drill) stop at it |
| `COVER` | over a gem, locks it | gem can't be swapped or fall, holds up the column; gem stays when it breaks |
| `FLOOR` | on the cell, under whatever is there (Royal Match's grass) | blocks nothing; a hit clears a layer and goes on to the gem (`Board._strike` hits the floor first, then the rest) |

Current table:

| Kind | Layer | Hit by | Need | Size | On finish |
|---|---|---|---|---|---|
| rock (terrain) | piece | NEXT, POWER | 1–3 layers | 1x1 | opens, reveals what it hid |
| generator | piece | NEXT, POWER | 6 | 2x2 | switches on, stays (solid) |
| cage | cover | ON, POWER | 1 | 1x1 | breaks, the gem stays |
| web | floor | ON, POWER | 1 (a site may set 2: thick) | 1x1 | clears; the hit goes on to the gem |

Non-obstacle item: **energy core** (`Token.CORE`): falls like a gem, never matches, never
destroyed by power-ups; the robot pushes it (a swap), pads throw it, belts carry it, teleporters
swap it. Delivered when it comes to rest on a dock (`cfg.docks`).

### Adding an obstacle

1. A row in `KINDS` (layer, hit_by, need, size, stays, goal).
2. Art in `assets/obstacles/`, a branch in `BoardView._draw_obstacles` and `_obstacle_fx`.
3. A goal icon in `Widgets.draw_goal_icon` and text in `Sites.goal_text`.
Nothing in matching, gravity, power-ups or paths changes. Rules that are not "hits to finish"
(a spreader, a generator that spawns pieces) will need a per-turn hook; add it to Obstacles,
called from `Board._finish_turn`, not into the resolve loop.

The view holds no rules either: where a drawn path may go (`Board.path_cells`), what it will
do (`Board.preview_path`), what a pad throws (`Board.pad_throws`) all come from the Board, so a
new obstacle is right in the preview the moment it is right in the move.
`tools/preview_check.gd` guards that.

Rock still keeps its own arrays (hp, buried); it goes through `_strike` like the rest. Moving it
into `KINDS` (hide contents, per-layer art) is the next clean-up, once a second "hides
something" obstacle exists.

## How it looks on our board

Tiles are square in layout (`Art.BAND_VISIBLE` 0, `pitch == cell`); each is a rounded soil block
with a small margin. That suits obstacles:
- 1x1 covers (cage) draw over the gem, in the tile's square;
- multi-cell pieces (generator 2x2) draw one sprite over the block of cells, covering the gaps
  between tiles (soil tiles still draw under it);
- a dock is under the gem it holds, so it also gets a mark on the board's edge below it (Candy
  Crush's exit arrows).
Rock layer counters (white pips) and the old vein pips were removed: rock shows the layers it
has left by its shade (darker = thicker, `BoardView.ROCK_TINT`, as Royal Match's boxes peel a
layer per match) and how worn it is by its crack state (`Art.rock`). The three rock "forms"
share one painted rock today; separate art per layer count is a todo. Gems are 15% bigger (ORE_SIZE 0.80 → 0.94).

## Prototypes (Settings > Prototypes)

7. **Power grid** (Activate): three 2x2 generators, 6 charges each from matches next to them or
   power-ups. Path bot: 75% at 20 moves, 93% at 30. Budget 26.
8. **Core run** (Deliver): two cores at the top, two docks at the bottom, a row of cages that
   holds up the columns. Path bot: 93% at 20 moves. Budget 22.

## Pacing (Royal Match)

Grass at level 4, Cupboard at 11, Mailbox at 21: roughly one new element every ~10 levels,
alternating with boosters; a level teaches it alone, later levels mix it with older ones (1–2
types early, 3–5 later).
