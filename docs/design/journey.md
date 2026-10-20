# The journey: level design roadmap

2026-10-19. The campaign is rebuilt as a journey for someone who has never played: every
mechanic is met on its own easy level, practised, then mixed with what came before. We build
it a few levels at a time, playtest, and go on. **This file is the plan; `Sites.LIST` is what is
built.** Levels not yet rebuilt keep their old design (marked *old*).

Sources: `docs/research/match3-mechanic-pacing.md` (when the big games add elements, how they
teach), `docs/research/match3-goals-obstacles.md` (goal types, obstacle families),
`docs/design/obstacles.md` (our rule table).

## Rules of the road

0. **Levels are about the board, not about power-ups.** A level is a puzzle made of the
   elements met so far (obstacles, goal types, board elements); the progression is the
   elements, one new one every ~10 levels (Royal Match). Power-ups are never a level's topic:
   they are learned in play, by Mira's one-line note the first time one is made and by a tip
   on a goal card now and then (`"tip": [power-up ids..., text]`, e.g. Pulsar + Nova "draw
   through both: they merge"). 15 power-ups would never get 15 levels.
1. **One new element per level at most, on an easy level.** A new element never debuts on a hard level
   (Royal Match, Homescapes). The level right after pairs it with something known; a harder
   level 3–5 later tests it (Homescapes: Apples 51/52/54).
2. **Show, don't tell.** A new verb is taught by a guided first move: a hand draws it, the
   board around it dims, and only that move is accepted (Royal Match's first levels). Mira
   says one short line, never a paragraph. After the guided move the level is free play.
3. **Front-load, then space out.** ~8–9 new elements in the first 100 levels, one every ~10
   early on (Royal Match: Grass 4, Cupboard 11, Mailbox 21); in chapter 1 a new *verb* every
   1–2 levels, because the verbs are the game.
4. **Every level has a problem, not just a count.** Each level's goal says what to solve
   (deliver, activate, free, connect) once those exist; Collect alone only in the first
   chapter.
5. **Sawtooth.** Tension rises for ~4 levels and drops; no hard level before ~39 (Royal Match's
   first), no super-hard before ~59. Early levels are short (Candy Crush: the longest level
   is the least fun) and nearly unlosable (1.0–1.1 attempts).
6. **Small boards first.** Level 1 is 7 wide, Royal Match size (9) from level 2.
   Few colours first: 3 colours in level 1 (cascades, delight), 4 after.
8. **The first move is the game's move, and the first level has an obstacle.** Drawing a path
   is the core verb, so level 1 teaches it (a one-step swipe is just a short path; it needs
   no lesson). Royal Match meets its first obstacle, the Box, on level 1 (its wiki: "first
   appearance: Level 1"), so a level is about something from the start; Candy Crush's level 1
   is a plain colour order and its first blocker (frosting) comes on level 2.
7. **A chapter is a place.** 10 levels, ending in a reward level and a colony building.

## The elements, in the order they are met (power-ups: tips, see rule 0)

| # | Thing | Kind | Rule in one line |
|---|---|---|---|
| 1 | Draw a path | verb | hold and draw up to 4 steps: the robot swaps all the way, one move |
| 2 | Rock | obstacle | a match next to it cracks it (1–3 layers) |
| – | power-ups | tips | Pulsar, Scout drone, Nova, Black hole, combos: a tip on a goal card, Mira's note the first time |
| 4 | Thick rock | variant | two or three layers: a match per layer |
| 4b | Cave web | obstacle (floor) | under the gems; a match on top of it clears it (level 6) |
| 5 | Falling robot | verb | clear under the robot and it drops down for free |
| 6 | Nova | power-up | an L or T; push it, a 5x5 blast |
| 7 | Crystal in rock | goal (Excavate) | break the rock to reveal it, then pick it up |
| 8 | Energy core + dock | goal (Deliver) | bring the core down onto the dock; the robot can push it |
| 9 | Black hole | power-up | 5 in a row; swallows the most common colour |
| 10 | Cage | obstacle (cover) | locks a gem; match that gem or hit it with a power-up |
| 11 | Generator | goal (Activate) | 2x2; matches next to it charge it |
| 12 | Teleporter | board element | end a move on one, come out of its twin; power-ups teleport too |
| 13 | Launch pad | board element | a power-up resting on it is thrown to the target |
| 14 | Belt | board element | moves a step each turn, more for matches on it |
| 15 | Connect | goal (new) | open a passage between two stations (the path genre's own goal) |
| 16 | Rescue | goal (new) | free a trapped scout bot, then bring it home (Sequence) |

## Chapter plan

### Chapter 1 · Landing (levels 1–10): rock

The chapter's element is rock, then the cave web at 6 (a floor layer cleared by a match on
top of it: Royal Match meets grass on level 4). Thick rock is a variant; crystals in rock are
a goal twist on rock, not a new mechanic. Every level is free play except level 1 (the path lesson).

| L | Board | Goal | Element | Tip on the goal card |
|---|---|---|---|---|
| 1 | 7x8, rock rows top and bottom, 3 colours | 14 rock | **path + rock** (guided) | – |
| 2 | arches: two rock bands | 11 rock | | Pulsar |
| 3 | a rock band with a thick middle | 9 rock | **thick rock** (Mira points at it) | – |
| 4 | spine: a wall splits two quarries | 10 rock | | Scout drone |
| 5 | strata: a full band up top, thick rock below | 14 rock | | Nova |
| 6 | a band of webs across the middle | 16 webs | **cave web** (floor layer; Mira, one line) | – |
| 7 | **silk corners**: webs in the four corners behind rock shields, an open middle | 16 webs | web + rock (the pair level) | – |
| 8 | **crystal vaults**: an octagon, crystals in two corner pockets and a thick-rock vault | 3 crystals | (a goal twist on rock) | combo (Pulsar + Nova) |
| 9 | **hourglass**: webs up top beyond a narrow waist, a rock band below; the small peak | 18 webs + 6 rock | two goals | drone + Pulsar |
| 10 | **starfall**: a show level: thick webs flood the board, power-ups waiting | 50 webs | reward | Black hole |

Levels are designed with the checklist in `docs/research/royal-match-level-design.md` §6: one
idea in one sentence, a new silhouette each level, goals at the edges or in pockets, an open
"workshop" in the middle for power-ups, obstacles in lines and shapes (never scatter), an order
of play (shield, then goal), and the last goals in the hardest spot.

### Chapter 2 · The Shaft (11–20): Deliver
11 **energy core** (one core, one dock, open board) · 12 core + rock · 13 **Black hole**; path combos ·
14 two-layer rock · 15 **cage** · 16 cores held up by cages (prototype Core run) ·
17 practice · 18 normal+ · 19 mix · 20 reward + building.

### Chapter 3 · The Power Plant (21–30): Activate
21 **generator** (one, open board) · 22 two generators + rock · 23 generators + cages ·
25 **teleporter** · 26 teleporter + core · 27–29 mixes (prototype Power grid) · 30 reward.

### Chapter 4 · The Launch Bay (31–40): moving things
31 **launch pad** · 33 pad + generator · 35 **belt** · 37 belt + core · **39 first hard** ·
40 reward.

### Chapter 5 · The Relay (41–50): Connect
41 **Connect** · 45 hard · 49 super-hard? (Royal Match's first super-hard is 59) · 50 reward.

### Chapter 6 (51–60): Rescue
51 **Rescue** · then mixes. From here one new element per ~10 levels, then ~20.

## How we build a level

The loop, three levels at a time: build, measure, play on a phone, then the next three.

1. **Write its row here first**: what it teaches (one new thing at most), the goal (a problem,
   not just a count, once the goal types exist), the board size and colours.
2. **A guided level** (it teaches something new): hand-place the opening (`"ore"` rows, codes
   F C L R) around the move the hand shows (`"guide"` in Mira's line: the cells from the
   robot on; only that move is accepted, the rest of the board dims). Design the move so it
   shows the new thing at its best: two lines at once, a line under the obstacle, a power-up
   firing down a whole column.
3. **Pick the seed** (what falls in) so the guided move ends in a cascade and makes no
   power-up before its time:
   `godot --headless --path . -s res://tools/lesson_design.gd -- scan <id> <moves> [specials=N] [rocks=N]`.
   An opening never holds a ready-made line or 2x2 square (the tests check it).
4. **Check it move by move**: `tools/lesson_probe.gd -- <id> <moves...>` prints the board.
5. **Measure**: `lesson_design.gd -- rate <id> <moves>`: 40 games of the SLOPPY path bot.
   It plays paths like an expert (it weighs ~160 paths a move), so people need more moves:
   targets for its **median**: level 1 about 4–5 moves, early levels about 7, never lost (40/40
   with the budget at least 2x its worst game). Free-play levels (no guide) use fresh boards
   each attempt; tier "intro" ≈ 92% first-try clears for people.
6. **Record the solution** (`lesson_design.gd -- solve <id> <moves>`) in `tests/run_tests.gd`
   (TUTORIAL_SOLUTIONS, one path per entry); the tests replay it and check that the hand's
   moves are the solution's first moves.
7. **Play it on a phone**: Settings > Dev mode on, then Dig lists every level (and the
   prototypes); lessons replay Mira every time in dev mode.

## Decisions so far (2026-10-19, with the user)

- **Paths are the game.** No swipe lesson: a one-step drag is just a short path. Level 1
  teaches drawing a path.
- **The first obstacle on level 1** (Royal Match's Box is on its level 1): rock, cracked by a
  match next to it. Level 3 brings its variant, thick rock; layers read by shade (darker =
  thicker), never by counters or dots on the board.
- **Guided moves are Royal Match's**: a hand draws the move in a loop, the board dims around
  it, only that move works. One short Mira line, never a paragraph.
- **Goal types beyond Collect** (`docs/design/obstacles.md`): Excavate, Deliver (energy core
  onto a dock), Activate (generators), and later Connect (our genre's own, rare elsewhere)
  and Rescue. Prototypes 7 Power grid and 8 Core run were the reference ("very much liked").
- **Crystals in rock are not a new mechanic** (the user caught it): breaking rock is known; a
  new element must bring a new interaction. The cave web (a floor layer, grass's role) is the
  chapter's second element; it grows into a family: thick web, then a spider nest that
  re-spins webs (a spreader, Royal Match's bush / Soda's chocolate).
- **No level teaches a power-up** (the user, firmly): power-ups come through tips and Mira's
  first-time note; levels are built around the board's elements.
- **Power-ups** (`docs/design/powerups.md`): Pulsar (4 in a row, twin beams), Nova (L/T,
  5x5), Black hole (5 in a row, the most common colour), Scout drone (2x2, flies to the most
  useful cell, not the nearest, gliding so the player sees where it goes). Power-ups chain;
  a path that drags two or more merges them (pair table; three doubled; four = Big Bang).
  Chains rattle off ~0.12 s apart: a long chain must not drag.
- **Animation polish comes in its own pass later**; rules first. The view never holds rules
  (`Board.preview_path`), so polishing it can't break the game.

## Built so far

- 2026-10-19 (second pass, after the first playtest discussion): the swipe lesson is gone (paths
  are the game; a swipe is a short path), level 1 teaches the path and meets rock, level 2 is
  the Drill, level 3 practises thick rock. Old table below is the first pass.
- 2026-10-19: levels 1–3. Tutorial tools: a guided move with a hand and a spotlight (`"guide"`
  in a script line: only that move is accepted, a drawn path stays on its rail), paths locked
  per level (`"path_max"`), the `path` event for Mira's lines, `"explains"` so a special taught
  by a lesson gets no second note. All three are hand-placed with pinned seeds, chosen by
  scanning seeds so the guided move ends in a cascade and makes no special before its time.

| L | id | Guided move | What it shows | Goal | Moves | SLOPPY path bot (40 games) |
|---|---|---|---|---|---|---|
| 1 | first | swipe up (1 step) | a line, then 5 cascades: 6 Ferrite from one swipe | 20 Ferrite | 20 | 40/40, median 7, max 15 |
| 2 | path | up, right, right | two lines from one path, then cascades | 30 Cryo + 30 Ruby | 20 | 40/40, median 7, max 12 |
| 3 | drill | up, right (4 in a row), then a 4-step path onto the Drill from above | the Drill bores up the column, 5 lines cascade | 30 Lumen | 20 | 40/40, median 7, max 11 |

  The bot plays paths like an expert (it weighs ~160 paths a move); people will take more
  moves, so the budgets sit well above its worst game. Play them, then tune.
- 2026-10-19 (power-ups v2, `docs/design/powerups.md`): the Drill is now the Pulsar (twin
  beams), 2x2 squares match. Level 1 got a second rock row (14 rocks; the guided path still
  cracks 4 with 6 lines); seeds re-picked for the new rules: level 1 seed 256 (bot median 4),
  level 2 seed 108 (6 cascades after the Pulsar fires, median 7), level 3 median 7.
